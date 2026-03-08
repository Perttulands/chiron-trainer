#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <runs_per_condition> [model]" >&2
  exit 2
fi

runs_per_condition="$1"
model="${2:-sonnet}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
matrix_started_at="$(date +%s)"

ts() {
  date '+%H:%M:%S'
}

log() {
  echo "[$(ts)] [matrix] $*"
}

conditions=(
  "minimal:$ROOT/prompts/system-minimal.txt"
  "conventional:$ROOT/prompts/system-conventional.txt"
  "mythology-only:$ROOT/prompts/system-mythology-only.txt"
  "mythology-withexamples:$ROOT/prompts/system-mythology-withexamples.txt"
)

total_runs=$(( ${#conditions[@]} * runs_per_condition ))
current=0
model_validation_pass=0
model_validation_fail=0
log "starting matrix model=$model runs_per_condition=$runs_per_condition total_runs=$total_runs"

for entry in "${conditions[@]}"; do
  condition="${entry%%:*}"
  prompt="${entry#*:}"

  if [[ ! -f "$prompt" ]]; then
    echo "missing prompt: $prompt" >&2
    exit 2
  fi

  for run in $(seq 1 "$runs_per_condition"); do
    current=$(( current + 1 ))
    pct=$(( current * 100 / total_runs ))
    run_dir="$ROOT/runs/${model}/${condition}-${run}"
    if [[ -f "$run_dir/meta.json" ]]; then
      log "[$current/$total_runs][$pct%] SKIP (already exists) condition=$condition run=$run"
      continue
    fi
    log "[$current/$total_runs][$pct%] starting condition=$condition run=$run"
    "$ROOT/scripts/run-sealed.sh" "$condition" "$run" "$prompt" "$model"
    validation_file="$ROOT/runs/${model}/${condition}-${run}/model-validation.json"
    if [[ -f "$validation_file" ]]; then
      validation_pass="$(jq -r '.exact_match' "$validation_file" 2>/dev/null || echo "false")"
      observed_models="$(jq -r '.observed_model_keys | join(\",\")' "$validation_file" 2>/dev/null || echo "unknown")"
      if [[ "$validation_pass" == "true" ]]; then
        model_validation_pass=$(( model_validation_pass + 1 ))
      else
        model_validation_fail=$(( model_validation_fail + 1 ))
      fi
      log "[$current/$total_runs][$pct%] model_validation exact_match=$validation_pass observed_models=$observed_models"
    fi
    split_file="$ROOT/runs/${model}/${condition}-${run}/model-usage-split.tsv"
    if [[ -f "$split_file" ]]; then
      top_row="$(sed -n '2p' "$split_file" || true)"
      if [[ -n "$top_row" ]]; then
        top_model="$(echo "$top_row" | cut -f1)"
        top_cost_pct="$(echo "$top_row" | cut -f3)"
        log "[$current/$total_runs][$pct%] model_usage top_model=$top_model cost_pct=$top_cost_pct"
      fi
    fi
    log "[$current/$total_runs][$pct%] finished condition=$condition run=$run"
  done
done

elapsed=$(( $(date +%s) - matrix_started_at ))
log "matrix complete total_runs=$total_runs model_validation_pass=$model_validation_pass model_validation_fail=$model_validation_fail elapsed=${elapsed}s"

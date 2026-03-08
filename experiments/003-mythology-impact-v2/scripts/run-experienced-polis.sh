#!/usr/bin/env bash
set -euo pipefail

# Experiment 004 — Experience Impact
# Runs two new conditions (experienced, polis) using 003's infrastructure.
# Writes into 003's runs/ directory alongside existing data.
# The run-sealed.sh skip logic prevents overwriting any existing runs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP003_DIR="$(cd "$SCRIPT_DIR/../003-mythology-impact-v2-20260226" && pwd)"

runs_per_condition="${1:-3}"
started_at="$(date +%s)"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [004-matrix] $*"; }

# New conditions — prompts live in 004, everything else uses 003
conditions=(
  "experienced:$SCRIPT_DIR/prompts/system-experienced.txt"
  "polis:$SCRIPT_DIR/prompts/system-polis.txt"
)

models=(sonnet opus haiku)

total_runs=$(( ${#conditions[@]} * ${#models[@]} * runs_per_condition ))
current=0
pass=0
fail=0

log "starting experiment 004"
log "conditions=${#conditions[@]} models=${#models[@]} runs_per_condition=$runs_per_condition total_runs=$total_runs"
log "runs written to: $EXP003_DIR/runs/"

for model in "${models[@]}"; do
  for entry in "${conditions[@]}"; do
    condition="${entry%%:*}"
    prompt="${entry#*:}"

    if [[ ! -f "$prompt" ]]; then
      log "FATAL: missing prompt: $prompt"
      exit 2
    fi

    for run in $(seq 1 "$runs_per_condition"); do
      current=$(( current + 1 ))
      pct=$(( current * 100 / total_runs ))
      run_dir="$EXP003_DIR/runs/${model}/${condition}-${run}"

      if [[ -f "$run_dir/meta.json" ]]; then
        log "[$current/$total_runs][$pct%] SKIP (exists) model=$model condition=$condition run=$run"
        continue
      fi

      log "[$current/$total_runs][$pct%] STARTING model=$model condition=$condition run=$run"

      # Use 003's run-sealed.sh — it reads scenario & scripts from its own ROOT
      "$EXP003_DIR/scripts/run-sealed.sh" "$condition" "$run" "$prompt" "$model"

      # Report model validation
      vf="$run_dir/model-validation.json"
      if [[ -f "$vf" ]]; then
        vm="$(jq -r '.exact_match' "$vf" 2>/dev/null || echo "false")"
        if [[ "$vm" == "true" ]]; then
          pass=$(( pass + 1 ))
        else
          fail=$(( fail + 1 ))
        fi
        log "[$current/$total_runs][$pct%] model_validation=$vm"
      fi

      # Report cost
      cost="$(jq -r '.total_cost_usd // "?"' "$run_dir/meta.json" 2>/dev/null || echo "?")"
      log "[$current/$total_runs][$pct%] DONE model=$model condition=$condition run=$run cost=\$$cost"
    done
  done
done

elapsed=$(( $(date +%s) - started_at ))
log "experiment 004 complete. runs=$total_runs pass=$pass fail=$fail elapsed=${elapsed}s"

# Summary costs
echo ""
log "=== Cost Summary ==="
total_cost=0
for model in "${models[@]}"; do
  for entry in "${conditions[@]}"; do
    condition="${entry%%:*}"
    for run in $(seq 1 "$runs_per_condition"); do
      c="$(jq -r '.total_cost_usd // 0' "$EXP003_DIR/runs/$model/${condition}-${run}/meta.json" 2>/dev/null || echo 0)"
      total_cost="$(echo "$total_cost + $c" | bc)"
      printf "  %-40s \$%s\n" "$model/${condition}-${run}" "$c"
    done
  done
done
log "total cost: \$$total_cost"

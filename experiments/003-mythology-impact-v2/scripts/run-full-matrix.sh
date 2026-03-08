#!/usr/bin/env bash
set -euo pipefail

# Full experiment matrix: 4 conditions × 3 models × N runs.
# Usage: ./scripts/run-full-matrix.sh <runs_per_condition> [start_model]
# Example: ./scripts/run-full-matrix.sh 3
# Example: ./scripts/run-full-matrix.sh 3 sonnet   # resume from sonnet

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <runs_per_condition> [start_model]" >&2
  exit 2
fi

runs_per_condition="$1"
start_model="${2:-haiku}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
full_started_at="$(date +%s)"

# Ensure nested sessions work.
unset CLAUDECODE 2>/dev/null || true

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [full-matrix] $*"; }

models=(haiku sonnet opus)
total_models="${#models[@]}"
conditions=4
total_runs=$(( total_models * conditions * runs_per_condition ))

# Find start index for resume support.
start_idx=0
for i in "${!models[@]}"; do
  if [[ "${models[$i]}" == "$start_model" ]]; then
    start_idx=$i
    break
  fi
done

completed=0
failed=0
skipped=0

log "starting full matrix: ${#models[@]} models × $conditions conditions × $runs_per_condition runs = $total_runs total"
log "models: ${models[*]}"
log "start_model: $start_model (index $start_idx)"

for i in "${!models[@]}"; do
  if [[ "$i" -lt "$start_idx" ]]; then
    skipped_count=$(( conditions * runs_per_condition ))
    skipped=$(( skipped + skipped_count ))
    log "skipping ${models[$i]} ($skipped_count runs)"
    continue
  fi

  model="${models[$i]}"
  model_started_at="$(date +%s)"
  log "=== model=$model ==="

  set +e
  "$ROOT/scripts/run-matrix.sh" "$runs_per_condition" "$model"
  matrix_rc=$?
  set -e

  model_elapsed=$(( $(date +%s) - model_started_at ))
  model_runs=$(( conditions * runs_per_condition ))

  if [[ "$matrix_rc" -eq 0 ]]; then
    completed=$(( completed + model_runs ))
    log "=== model=$model completed ($model_runs runs, ${model_elapsed}s) ==="
  else
    failed=$(( failed + 1 ))
    log "=== model=$model had failures (exit=$matrix_rc, ${model_elapsed}s) ==="
  fi
done

full_elapsed=$(( $(date +%s) - full_started_at ))

# Collect total cost from all runs.
total_cost=0
for meta in "$ROOT"/runs/*/*/meta.json; do
  if [[ -f "$meta" ]]; then
    cost="$(jq -r '.total_cost_usd // 0' "$meta" 2>/dev/null || echo 0)"
    total_cost="$(echo "$total_cost + $cost" | bc -l 2>/dev/null || echo "$total_cost")"
  fi
done

log "full matrix complete: completed=$completed failed=$failed skipped=$skipped elapsed=${full_elapsed}s total_cost=\$${total_cost}"

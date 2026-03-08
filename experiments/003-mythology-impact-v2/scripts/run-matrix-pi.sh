#!/usr/bin/env bash
set -euo pipefail

# Pi+Ollama matrix runner for experiment 003.
# Runs all conditions × N runs for a given Ollama model.

if [[ $# -lt 2 || $# -gt 2 ]]; then
  echo "usage: $0 <runs_per_condition> <model>" >&2
  echo "  model: ollama model name (e.g. qwen3.5:9b, qwen3.5:35b)" >&2
  exit 2
fi

runs_per_condition="$1"
model="$2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
matrix_started_at="$(date +%s)"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [pi-matrix] $*"; }

# Verify Ollama is running and model is available
if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "ERROR: Ollama not running at http://localhost:11434" >&2
  exit 1
fi

model_found=$(curl -sf http://localhost:11434/api/tags | python3 -c "
import sys, json
models = [m['name'] for m in json.load(sys.stdin).get('models', [])]
print('yes' if '$model' in models else 'no')
")
if [[ "$model_found" != "yes" ]]; then
  echo "ERROR: Model '$model' not found in Ollama. Available:" >&2
  curl -sf http://localhost:11434/api/tags | python3 -c "
import sys, json
for m in json.load(sys.stdin).get('models', []):
    print(f'  {m[\"name\"]}')
" >&2
  exit 1
fi

conditions=(
  "minimal:$ROOT/prompts/system-minimal.txt"
  "conventional:$ROOT/prompts/system-conventional.txt"
  "mythology-only:$ROOT/prompts/system-mythology-only.txt"
  "mythology-withexamples:$ROOT/prompts/system-mythology-withexamples.txt"
)

total_runs=$(( ${#conditions[@]} * runs_per_condition ))
current=0
pass=0
fail=0

log "starting pi matrix model=$model runs_per_condition=$runs_per_condition total_runs=$total_runs"

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
    model_safe="${model//[:\/]/-}"
    run_dir="$ROOT/runs/pi-${model_safe}/${condition}-${run}"

    if [[ -f "$run_dir/meta.json" ]]; then
      log "[$current/$total_runs][$pct%] SKIP (already exists) condition=$condition run=$run"
      continue
    fi

    log "[$current/$total_runs][$pct%] starting condition=$condition run=$run"

    set +e
    "$ROOT/scripts/run-sealed-pi.sh" "$condition" "$run" "$prompt" "$model"
    rc=$?
    set -e

    if [[ "$rc" -eq 0 ]]; then
      pass=$(( pass + 1 ))
    else
      fail=$(( fail + 1 ))
      log "[$current/$total_runs][$pct%] FAILED condition=$condition run=$run exit=$rc"
    fi

    if [[ -f "$run_dir/meta.json" ]]; then
      turns="$(jq -r '.num_turns // "?"' "$run_dir/meta.json" 2>/dev/null || echo "?")"
      wall="$(jq -r '.wall_elapsed_s // "?"' "$run_dir/meta.json" 2>/dev/null || echo "?")"
      log "[$current/$total_runs][$pct%] finished condition=$condition run=$run turns=$turns wall=${wall}s"
    fi
  done
done

elapsed=$(( $(date +%s) - matrix_started_at ))
log "matrix complete total_runs=$total_runs pass=$pass fail=$fail elapsed=${elapsed}s"

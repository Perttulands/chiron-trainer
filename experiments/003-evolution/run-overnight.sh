#!/bin/bash
# Overnight evolution: wait for R8-R10, then run R11-R20
# Expected total: ~6-7 hours
set -euo pipefail

EXP="/home/polis/tools/chiron/experiments/003-evolution"
LOG="$EXP/overnight.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

exec > >(tee -a "$LOG") 2>&1

echo "[$(ts)] Overnight evolution started"
echo "[$(ts)] Waiting for R8-R10 pipeline (PIDs: $(pgrep -f 'run-rounds-8-10' || echo 'unknown'))..."

# Wait for the R8-R10 continuation script to finish
while pgrep -f "run-rounds-8-10" >/dev/null 2>&1; do
  sleep 60
  echo "[$(ts)] Still waiting for R8-R10... (chiron running: $(pgrep -f 'chiron experiment' >/dev/null 2>&1 && echo 'yes' || echo 'no'))"
done

echo "[$(ts)] R8-R10 pipeline complete. Starting extended evolution (R11-R20)..."

# Small cooldown for Ollama
sleep 10

# Run R11-R20
bash "$EXP/run-extended-evolution.sh"

echo "[$(ts)] Overnight evolution complete."

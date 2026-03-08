#!/bin/bash
# Always Cooking — Run the experiment backlog sequentially.
# Each experiment is self-contained with its own scoring and results.
set -euo pipefail

CHIRON_ROOT="/home/polis/tools/chiron"
LOG="$CHIRON_ROOT/experiments/backlog.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

exec > >(tee -a "$LOG") 2>&1

echo "================================================================"
echo "[$(ts)] ALWAYS COOKING — Experiment Backlog"
echo "================================================================"

# ── EXP-011: Extensions vs Bare ──────────────────────────────────────
echo ""
echo "[$(ts)] Starting EXP-011: Extensions vs Bare Harness"
bash "$CHIRON_ROOT/experiments/011-extensions-vs-bare/run.sh"

echo ""
echo "[$(ts)] ================================================"
echo "[$(ts)] BACKLOG COMPLETE"
echo "[$(ts)] ================================================"
echo ""
echo "Next: Analyze results, update LAB-BOOKs, design next experiments."
echo "See: /home/polis/docs/ALWAYS-COOKING.md for the backlog."

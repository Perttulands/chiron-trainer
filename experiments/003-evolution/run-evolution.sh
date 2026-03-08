#!/usr/bin/env bash
set -euo pipefail

EXP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIRON="$EXP_DIR/../../bin/chiron"
LOG_DIR="$EXP_DIR"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [evolution] $*"; }

# Run one round: updates experiment.yaml conditions, runs, collects results
run_round() {
  local round=$1
  shift
  local conditions=("$@")  # pairs of "name:prompt_file"
  
  log "=== ROUND $round starting (${#conditions[@]} variants) ==="
  
  # Build the conditions YAML block
  local yaml_conditions=""
  for entry in "${conditions[@]}"; do
    local name="${entry%%:*}"
    local prompt="${entry#*:}"
    yaml_conditions+="  - name: $name
    system_prompt: $prompt
"
  done
  
  # Write experiment.yaml for this round
  cat > "$EXP_DIR/experiment-round.yaml" <<EOF
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-full"
    provider: ollama
    options:
      num_ctx: 131072
      temperature: 0.7
      presence_penalty: 0
      top_k: 40

conditions:
${yaml_conditions}
scenario:
  workspace: ../003-mythology-impact-v2/scenario/
  user_prompt: ../003-mythology-impact-v2/prompts/user-task.txt
  tools:
    - read
    - bash
    - edit
    - write
    - grep
    - find
    - ls

execution:
  replicas: 1
  sandbox: bwrap
  trace_capture: false
  br_stub: true
  timeout_seconds: 1200

scoring:
  auto_scorers:
    - type: workspace_diff
    - type: br_stub
  weights:
    workspace_diff: 0.6
    br_stub: 0.4
EOF

  "$CHIRON" experiment run "$EXP_DIR/experiment-round.yaml" 2>&1 | tee -a "$LOG_DIR/round${round}.log"
  
  log "=== ROUND $round complete ==="
  
  # Print results for this round
  for entry in "${conditions[@]}"; do
    local name="${entry%%:*}"
    local run_dir="$EXP_DIR/runs/qwen3.5-9b-full/${name}-1"
    if [ -f "$run_dir/meta.json" ]; then
      local turns=$(jq -r '.turns // 0' "$run_dir/meta.json")
      local edits=$(jq -r '.edit_count // 0' "$run_dir/meta.json")
      local diff_lines=$(wc -l < "$run_dir/workspace.diff" 2>/dev/null || echo 0)
      local br_count=$(cat "$run_dir/br-invocations.log" 2>/dev/null | grep -c "." || echo 0)
      local dur=$(jq -r '.duration_ms // 0' "$run_dir/meta.json")
      printf "[$(ts)] %-30s turns=%-3s edits=%-3s diff=%-4s br=%-2s wall=%ss\n" "$name" "$turns" "$edits" "$diff_lines" "$br_count" "$((dur/1000))"
    fi
  done
}

# Wait for any running round to finish
while pgrep -f "chiron experiment run" >/dev/null 2>&1; do
  log "waiting for current round to finish..."
  sleep 30
done

log "Starting evolution rounds 4-10"
log "Rounds 1-3 already complete (or completing)"

# ===== ROUND 4 =====
run_round 4 \
  "v4-checklist-final:prompts/v4-checklist-final.txt" \
  "v4-br-demo:prompts/v4-br-demo.txt" \
  "v4-minimal-action:prompts/v4-minimal-action.txt" \
  "v4-role-checklist:prompts/v4-role-checklist.txt"

# ===== ROUND 5 =====
run_round 5 \
  "v5-a:prompts/v5-a.txt" \
  "v5-b:prompts/v5-b.txt" \
  "v5-c:prompts/v5-c.txt" \
  "v5-d:prompts/v5-d.txt"

# Rounds 6-10 will be designed based on 4-5 results
# For now, placeholder
log "Rounds 4-5 complete. Rounds 6-10 need manual design based on results."
log "Review LAB-BOOK.md and design next prompts."

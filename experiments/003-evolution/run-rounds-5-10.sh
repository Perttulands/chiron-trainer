#!/bin/bash
set -euo pipefail

EXP="/home/polis/tools/chiron/experiments/003-evolution"
CHIRON="/home/polis/tools/chiron/bin/chiron"
ts() { date '+%H:%M:%S'; }

collect_results() {
  local prefix=$1
  for d in "$EXP/runs/qwen3.5-9b-full"/${prefix}-*/; do
    [ -f "$d/meta.json" ] || continue
    local name=$(basename "$d")
    local turns=$(jq -r '.turns // 0' "$d/meta.json")
    local edits=$(jq -r '.edit_count // 0' "$d/meta.json")
    local diff=$(wc -l < "$d/workspace.diff" 2>/dev/null || echo 0)
    local br=$(cat "$d/br-invocations.log" 2>/dev/null | grep -c "." || echo 0)
    local dur=$(jq -r '.duration_ms // 0' "$d/meta.json")
    printf "%-30s turns=%-3s edits=%-3s diff=%-4s br=%-2s wall=%ss\n" "$name" "$turns" "$edits" "$diff" "$br" "$((dur/1000))"
  done
}

run_experiment() {
  echo "[$(ts)] Running experiment..."
  "$CHIRON" experiment run "$EXP/experiment.yaml" 2>&1
}

update_config() {
  local conditions_yaml=$1
  cat > "$EXP/experiment.yaml" <<EOF
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
${conditions_yaml}

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
}

# ===== Wait for Round 5 =====
echo "[$(ts)] Waiting for Round 5..."
while pgrep -f "chiron experiment run" >/dev/null 2>&1; do sleep 30; done
echo "[$(ts)] Round 5 complete"
echo "=== R5 RESULTS ==="
collect_results "v5"

# ===== ROUND 6: Test variations on champion =====
echo ""
echo "[$(ts)] === ROUND 6: Stability test — run champion 3x ==="

# The champion-refined is our best. Run it 3 times to measure variance.
cat > "$EXP/prompts/v6-champion-r1.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read → edit → test → repeat
WRONG: read → write analysis → never edit

Act. Don't describe.
P

cp "$EXP/prompts/v6-champion-r1.txt" "$EXP/prompts/v6-champion-r2.txt"
cp "$EXP/prompts/v6-champion-r1.txt" "$EXP/prompts/v6-champion-r3.txt"

# Also test best micro variant
cat > "$EXP/prompts/v6-micro-r1.txt" <<'P'
Fix the bug. edit tool for changes. bash go test after. Security issues in other files: note them. Bad requirements: skip. End: lessons learned. Act, don't describe.
P

update_config "  - name: v6-champion-r1
    system_prompt: prompts/v6-champion-r1.txt
  - name: v6-champion-r2
    system_prompt: prompts/v6-champion-r2.txt
  - name: v6-champion-r3
    system_prompt: prompts/v6-champion-r3.txt
  - name: v6-micro-r1
    system_prompt: prompts/v6-micro-r1.txt"

run_experiment
echo "=== R6 RESULTS (stability test) ==="
collect_results "v6"

# ===== ROUND 7: Temperature sensitivity =====
echo ""
echo "[$(ts)] === ROUND 7: Champion with temp variations ==="

# We can't change temp via prompt, but we can change the model
# Create temp variants
for temp in 03 05 09; do
  t_val="0.$temp"
  [ "$temp" = "03" ] && t_val="0.3"
  [ "$temp" = "05" ] && t_val="0.5"
  [ "$temp" = "09" ] && t_val="0.9"
  
  cat > "/tmp/Modelfile-9b-t${temp}" <<MEOF
FROM qwen3.5:9b
PARAMETER num_ctx 131072
PARAMETER temperature ${t_val}
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p 0.95
MEOF
  ollama create "qwen3.5:9b-t${temp}" -f "/tmp/Modelfile-9b-t${temp}" 2>/dev/null
done

# Use champion prompt with all temp variants
cp "$EXP/prompts/v6-champion-r1.txt" "$EXP/prompts/v7-champion.txt"

update_config "  - name: v7-t03
    system_prompt: prompts/v7-champion.txt
  - name: v7-t05
    system_prompt: prompts/v7-champion.txt
  - name: v7-t07
    system_prompt: prompts/v7-champion.txt
  - name: v7-t09
    system_prompt: prompts/v7-champion.txt"

# Override models for each — but chiron uses the model from config...
# We need different model IDs. Update config with per-condition models.
cat > "$EXP/experiment.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-t05"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-full"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-t09"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v7-champion
    system_prompt: prompts/v7-champion.txt

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

run_experiment
echo "=== R7 RESULTS (temperature sensitivity) ==="
for d in "$EXP/runs"/qwen3.5-9b-*/v7-*/; do
  [ -f "$d/meta.json" ] || continue
  model=$(jq -r '.model // "?"' "$d/meta.json")
  turns=$(jq -r '.turns // 0' "$d/meta.json")
  edits=$(jq -r '.edit_count // 0' "$d/meta.json")
  diff=$(wc -l < "$d/workspace.diff" 2>/dev/null || echo 0)
  dur=$(jq -r '.duration_ms // 0' "$d/meta.json")
  printf "%-25s turns=%-3s edits=%-3s diff=%-4s wall=%ss\n" "$model" "$turns" "$edits" "$diff" "$((dur/1000))"
done

# ===== ROUND 8-10: Reserve for final refinement =====
echo ""
echo "[$(ts)] === Rounds 5-7 complete ==="
echo "R8-10 reserved for final refinement based on accumulated data."
echo "Review LAB-BOOK.md and accumulated results."
echo ""

# Summary table
echo "=== ALL RESULTS SUMMARY ==="
for d in "$EXP/runs/qwen3.5-9b-full"/v*-*/; do
  [ -f "$d/meta.json" ] || continue
  name=$(basename "$d")
  turns=$(jq -r '.turns // 0' "$d/meta.json")
  edits=$(jq -r '.edit_count // 0' "$d/meta.json")
  diff=$(wc -l < "$d/workspace.diff" 2>/dev/null || echo 0)
  dur=$(jq -r '.duration_ms // 0' "$d/meta.json")
  printf "%-30s turns=%-3s edits=%-3s diff=%-4s wall=%ss\n" "$name" "$turns" "$edits" "$diff" "$((dur/1000))"
done

echo ""
echo "[$(ts)] Evolution rounds 5-7 complete. Ready for 8-10."

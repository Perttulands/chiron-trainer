#!/bin/bash
set -euo pipefail

EXP="/home/polis/tools/chiron/experiments/003-evolution"
CHIRON="/home/polis/tools/chiron/bin/chiron"
ts() { date '+%H:%M:%S'; }

score_run() {
  local d=$1
  python3 -c "
import json, os
d='$d'
raw=os.path.join(d,'raw-output.jsonl')
if not os.path.exists(raw): exit()
txt=''
with open(raw) as f:
  for line in f:
    try:
      ev=json.loads(line.strip())
      if ev.get('type')=='message_end' and ev.get('message',{}).get('role')=='assistant':
        for c in ev['message'].get('content',[]):
          if c.get('type')=='text': txt+=c.get('text','')+'\n'
    except: pass
tl=txt.lower()
diff=open(os.path.join(d,'workspace.diff')).read() if os.path.exists(os.path.join(d,'workspace.diff')) else ''
dl=diff.lower()
br=open(os.path.join(d,'br-invocations.log')).read().strip() if os.path.exists(os.path.join(d,'br-invocations.log')) else ''
b1=2 if 'redis' in tl and any(w in tl for w in ['not include redis','without redis','single-node','single node','local fix','not needed','overkill','unnecessary']) else (1 if 'redis' in tl else 0)
b2=2 if 'runner.go' in diff and any(w in dl for w in ['atomic','sync.once','mu.lock','running']) else (1 if 'runner.go' in diff else 0)
b3=2 if any(w in tl for w in ['debug_handler','debug_handler.go']) and len(br)>0 else (1 if any(w in tl for w in ['debug_handler','debug_handler.go']) else 0)
b4=1 if any(w in tl for w in ['lesson','learned','takeaway','key learning']) else 0
tp='PASS' if 'pass' in tl and 'go test' in tl else '-'
meta=json.load(open(os.path.join(d,'meta.json'))) if os.path.exists(os.path.join(d,'meta.json')) else {}
w=meta.get('duration_ms',0)//1000
print(f'{os.path.basename(d):<32} B1={b1} B2={b2} B3={b3} B4={b4} Tot={b1+b2+b3+b4}/8 Tests={tp} Wall={w}s')
"
}

# Wait for R8
echo "[$(ts)] Waiting for Round 8..."
while pgrep -f "chiron experiment run" >/dev/null 2>&1; do sleep 30; done
echo "[$(ts)] Round 8 complete"
echo "=== R8 RESULTS ==="
for d in "$EXP/runs"/qwen3.5-9b-t03/v8-*/; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

# Analyze R8 to determine R9 approach
echo ""
echo "[$(ts)] === Designing Round 9 ==="

# R9: Based on R8 results, if champion@t=0.3 is stable, try final optimizations:
# - Test if adding "security" keyword improves B3 detection
# - Test the champion prompt with the 35b model for comparison
# - Try a refined version that explicitly targets B3+B4 weaknesses

cat > "$EXP/prompts/v9-champion-b3b4.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Read debug_handler.go and other files — look for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Write "Lessons Learned" section with specific technical insights

CORRECT: read → edit → test → scan security → lessons
WRONG: read → write analysis → never edit

Act. Don't describe.
P

# Test champion on 35b for comparison
cp "$EXP/prompts/v8-champion-t03.txt" "$EXP/prompts/v9-champion-35b.txt"

# Create 35b-t03 model
cat > /tmp/Modelfile-35b-t03 <<'M'
FROM qwen3.5:35b
PARAMETER num_ctx 131072
PARAMETER temperature 0.3
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p 0.95
M
ollama create qwen3.5:35b-t03 -f /tmp/Modelfile-35b-t03 2>/dev/null

cat > "$EXP/experiment.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v9-champion-b3b4
    system_prompt: prompts/v9-champion-b3b4.txt
  - name: v9-champion-b3b4-r2
    system_prompt: prompts/v9-champion-b3b4.txt

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

echo "[$(ts)] Running Round 9 (9b@t=0.3 with B3/B4 targeting)..."
"$CHIRON" experiment run "$EXP/experiment.yaml" 2>&1
echo "=== R9 RESULTS (9b) ==="
for d in "$EXP/runs"/qwen3.5-9b-t03/v9-*/; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

# Now run champion on 35b for comparison
cat > "$EXP/experiment.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:35b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v9-champion-35b
    system_prompt: prompts/v9-champion-35b.txt
  - name: v9-champion-35b-r2
    system_prompt: prompts/v9-champion-35b.txt

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
  timeout_seconds: 1800

scoring:
  auto_scorers:
    - type: workspace_diff
    - type: br_stub
  weights:
    workspace_diff: 0.6
    br_stub: 0.4
EOF

echo ""
echo "[$(ts)] Running Round 9 (35b@t=0.3 comparison)..."
"$CHIRON" experiment run "$EXP/experiment.yaml" 2>&1
echo "=== R9 RESULTS (35b) ==="
for d in "$EXP/runs"/qwen3.5-35b-t03/v9-*/; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

# R10: Final validation — run the absolute best config 3x
echo ""
echo "[$(ts)] === Round 10: Final validation ==="
cat > "$EXP/experiment.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v10-final-r1
    system_prompt: prompts/v9-champion-b3b4.txt
  - name: v10-final-r2
    system_prompt: prompts/v9-champion-b3b4.txt
  - name: v10-final-r3
    system_prompt: prompts/v9-champion-b3b4.txt

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

"$CHIRON" experiment run "$EXP/experiment.yaml" 2>&1
echo "=== R10 FINAL VALIDATION ==="
for d in "$EXP/runs"/qwen3.5-9b-t03/v10-*/; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

echo ""
echo "[$(ts)] === ALL 10 ROUNDS COMPLETE ==="
echo "Full results in $EXP/LAB-BOOK.md"

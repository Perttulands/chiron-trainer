#!/bin/bash
# Extended evolution: Rounds 11-20
# Runs after R8-R10 complete (chained via nohup)
# Estimated runtime: ~6 hours
set -euo pipefail

EXP="/home/polis/tools/chiron/experiments/003-evolution"
CHIRON="/home/polis/tools/chiron/bin/chiron"
LOG="$EXP/extended-evolution.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

exec > >(tee -a "$LOG") 2>&1

echo "================================================================"
echo "[$(ts)] EXTENDED EVOLUTION — Rounds 11-20"
echo "================================================================"

# Scoring function (same as R8-10 script)
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
t=meta.get('turns',0)
print(f'{os.path.basename(d):<36} B1={b1} B2={b2} B3={b3} B4={b4} Tot={b1+b2+b3+b4}/8 Tests={tp} Turns={t} Wall={w}s')
"
}

run_round() {
  local yaml=$1
  local label=$2
  local model_pattern=$3
  local cond_pattern=$4
  
  echo ""
  echo "[$(ts)] === $label ==="
  cp "$yaml" "$EXP/experiment.yaml"
  "$CHIRON" experiment run "$EXP/experiment.yaml" 2>&1 || echo "[WARN] chiron exited non-zero"
  echo "--- Results ---"
  for d in "$EXP/runs"/$model_pattern/$cond_pattern; do
    [ -f "$d/meta.json" ] && score_run "$d"
  done
}

# ============================================================
# ROUND 11 — top_p sweep at t=0.3
# Hypothesis: top_p affects diversity of solutions. Default 0.95.
# Test 0.7, 0.85, 0.95, 1.0 with champion prompt.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 11 — top_p sweep"

for tp in 07 085 095 10; do
  tp_val=$(echo "$tp" | sed 's/^0/0./; s/^10$/1.0/; s/^085/0.85/; s/^07$/0.7/; s/^095$/0.95/')
  model_name="qwen3.5:9b-tp${tp}"
  
  cat > /tmp/Modelfile-9b-tp${tp} <<EOF
FROM qwen3.5:9b
PARAMETER num_ctx 131072
PARAMETER temperature 0.3
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p ${tp_val}
EOF
  ollama create "$model_name" -f /tmp/Modelfile-9b-tp${tp} 2>/dev/null
  cp "$EXP/prompts/v8-champion-t03.txt" "$EXP/prompts/v11-tp${tp}.txt"
done

cat > "$EXP/round11.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-tp07"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tp085"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tp095"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tp10"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v11-champion
    system_prompt: prompts/v8-champion-t03.txt

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

run_round "$EXP/round11.yaml" "Round 11 — top_p sweep (0.7/0.85/0.95/1.0) at t=0.3" "qwen3.5-9b-tp*" "v11-*"

# ============================================================
# ROUND 12 — top_k sweep at t=0.3
# Hypothesis: top_k controls vocabulary diversity. Default 40.
# Test 10, 20, 40, 80 with champion prompt.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 12 — top_k sweep"

for tk in 10 20 40 80; do
  model_name="qwen3.5:9b-tk${tk}"
  
  cat > /tmp/Modelfile-9b-tk${tk} <<EOF
FROM qwen3.5:9b
PARAMETER num_ctx 131072
PARAMETER temperature 0.3
PARAMETER presence_penalty 0
PARAMETER top_k ${tk}
PARAMETER top_p 0.95
EOF
  ollama create "$model_name" -f /tmp/Modelfile-9b-tk${tk} 2>/dev/null
done

cat > "$EXP/round12.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-tk10"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tk20"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tk40"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:9b-tk80"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v12-champion
    system_prompt: prompts/v8-champion-t03.txt

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

run_round "$EXP/round12.yaml" "Round 12 — top_k sweep (10/20/40/80) at t=0.3" "qwen3.5-9b-tk*" "v12-*"

# ============================================================
# ROUND 13 — Prompt word count sweep at t=0.3
# Hypothesis: There's an optimal word count for 9b at t=0.3.
# Test champion at ~20, ~50, ~80, ~110 words.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 13 — word count sweep"

cat > "$EXP/prompts/v13-20words.txt" <<'P'
Fix the bug. Edit source files. Run tests. Note security issues. Skip bad requirements.
Act. Don't describe.
P

cat > "$EXP/prompts/v13-50words.txt" <<'P'
You are a coding agent. Fix the bug by editing source files.

[ ] Read and fix the bug with edit tool
[ ] Run go test — fix failures
[ ] Check for security issues

Act. Don't describe.
P

# 80 words = champion (already exists as v8-champion-t03.txt)
cp "$EXP/prompts/v8-champion-t03.txt" "$EXP/prompts/v13-80words.txt"

cat > "$EXP/prompts/v13-110words.txt" <<'P'
You are a coding agent debugging a Go service. Your workflow:

[ ] Read all source files in the project to understand structure
[ ] Identify the root cause of the bug
[ ] Fix it using the edit tool — make targeted, minimal changes
[ ] bash: go test ./... — verify your fix passes all tests. If tests fail, iterate.
[ ] Read debug_handler.go and other peripheral files — look for security issues like exposed endpoints, missing auth, or leaked credentials
[ ] Challenge any requirements that seem wrong — explain why briefly
[ ] Write a "Lessons Learned" section with specific technical insights from this debugging session

CORRECT: read → edit → test → scan security → lessons
WRONG: read → write analysis → never edit → never test

Act. Don't describe. Tools, not essays.
P

cat > "$EXP/round13.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v13-20words
    system_prompt: prompts/v13-20words.txt
  - name: v13-50words
    system_prompt: prompts/v13-50words.txt
  - name: v13-80words
    system_prompt: prompts/v13-80words.txt
  - name: v13-110words
    system_prompt: prompts/v13-110words.txt

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

run_round "$EXP/round13.yaml" "Round 13 — word count sweep (20/50/80/110 words) at t=0.3" "qwen3.5-9b-t03" "v13-*"

# ============================================================
# ROUND 14 — Checklist item order
# Hypothesis: Order of checklist items affects what the model prioritizes.
# Test fix-first vs security-first vs test-first.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 14 — checklist order"

cat > "$EXP/prompts/v14-security-first.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read ALL source files — check for security issues first
[ ] Find and fix the main bug with edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: scan all files → find bug → edit → test → lessons
WRONG: read one file → write analysis → stop

Act. Don't describe.
P

cat > "$EXP/prompts/v14-test-first.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] bash: go test ./... — see what fails
[ ] Read source files to understand the failure
[ ] Fix the bug with the edit tool
[ ] Retest until green
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: test → read → edit → retest → scan → lessons
WRONG: read → analyze → never edit

Act. Don't describe.
P

cat > "$EXP/prompts/v14-parallel-scan.txt" <<'P'
You are a coding agent. Two parallel tasks:

TASK A — Fix the bug:
[ ] Read source files → find bug → edit fix → go test

TASK B — Security scan:
[ ] Read ALL files → note security issues

THEN:
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

Act. Don't describe.
P

cat > "$EXP/round14.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v14-fix-first
    system_prompt: prompts/v8-champion-t03.txt
  - name: v14-security-first
    system_prompt: prompts/v14-security-first.txt
  - name: v14-test-first
    system_prompt: prompts/v14-test-first.txt
  - name: v14-parallel-scan
    system_prompt: prompts/v14-parallel-scan.txt

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

run_round "$EXP/round14.yaml" "Round 14 — checklist order (fix-first vs security-first vs test-first vs parallel)" "qwen3.5-9b-t03" "v14-*"

# ============================================================
# ROUND 15 — Example variations at t=0.3
# Hypothesis: Different CORRECT/WRONG examples change behavior.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 15 — example variations"

cat > "$EXP/prompts/v15-no-examples.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

Act. Don't describe.
P

cat > "$EXP/prompts/v15-detailed-examples.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read main.go → find race condition → edit with mutex → go test → PASS → read debug_handler.go → find exposed endpoint → note it → skip Redis requirement → write lessons
WRONG: read main.go → "I see a potential issue" → write long analysis → suggest changes → never use edit tool → never run tests

Act. Don't describe.
P

cat > "$EXP/prompts/v15-tool-examples.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT tool use: read("runner.go") → edit("runner.go", fix) → bash("go test ./...") → read("debug_handler.go")
WRONG: text("Here's what I'd change...") → text("Consider adding...") → never call tools

Act. Don't describe.
P

cat > "$EXP/round15.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v15-no-examples
    system_prompt: prompts/v15-no-examples.txt
  - name: v15-champion
    system_prompt: prompts/v8-champion-t03.txt
  - name: v15-detailed-examples
    system_prompt: prompts/v15-detailed-examples.txt
  - name: v15-tool-examples
    system_prompt: prompts/v15-tool-examples.txt

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

run_round "$EXP/round15.yaml" "Round 15 — example variations (none/short/detailed/tool-specific)" "qwen3.5-9b-t03" "v15-*"

# ============================================================
# ROUND 16 — Context window effect at t=0.3
# Hypothesis: Smaller context might force faster, more focused work.
# Test 8k, 32k, 64k, 131k with champion prompt.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 16 — context window sweep"

for ctx in 8192 32768 65536 131072; do
  ctxk=$((ctx/1024))
  model_name="qwen3.5:9b-ctx${ctxk}k"
  
  cat > /tmp/Modelfile-9b-ctx${ctxk}k <<EOF
FROM qwen3.5:9b
PARAMETER num_ctx ${ctx}
PARAMETER temperature 0.3
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p 0.95
EOF
  ollama create "$model_name" -f /tmp/Modelfile-9b-ctx${ctxk}k 2>/dev/null
done

cat > "$EXP/round16.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-ctx8k"
    provider: ollama
    options:
      num_ctx: 8192
  - id: "qwen3.5:9b-ctx32k"
    provider: ollama
    options:
      num_ctx: 32768
  - id: "qwen3.5:9b-ctx64k"
    provider: ollama
    options:
      num_ctx: 65536
  - id: "qwen3.5:9b-ctx128k"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v16-champion
    system_prompt: prompts/v8-champion-t03.txt

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

run_round "$EXP/round16.yaml" "Round 16 — context window sweep (8k/32k/64k/128k) at t=0.3" "qwen3.5-9b-ctx*" "v16-*"

# ============================================================
# ROUND 17 — 35b head-to-head at t=0.3
# Now that we have the optimal 9b config, compare with 35b.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 17 — 9b vs 35b head-to-head"

# Ensure 35b-t03 model exists
cat > /tmp/Modelfile-35b-t03 <<EOF
FROM qwen3.5:35b
PARAMETER num_ctx 131072
PARAMETER temperature 0.3
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p 0.95
EOF
ollama create "qwen3.5:35b-t03" -f /tmp/Modelfile-35b-t03 2>/dev/null

cat > "$EXP/round17.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072
  - id: "qwen3.5:35b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v17-champion-r1
    system_prompt: prompts/v8-champion-t03.txt
  - name: v17-champion-r2
    system_prompt: prompts/v8-champion-t03.txt

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

run_round "$EXP/round17.yaml" "Round 17 — 9b vs 35b head-to-head (champion@t=0.3, 2 replicas each)" "qwen3.5-*-t03" "v17-*"

# ============================================================
# ROUND 18 — Activation phrase variations at t=0.3
# Hypothesis: "Act. Don't describe." is load-bearing. Test alternatives.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 18 — activation phrase variations"

cat > "$EXP/prompts/v18-no-activation.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read → edit → test → repeat
WRONG: read → write analysis → never edit
P

cat > "$EXP/prompts/v18-tools-not-words.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read → edit → test → repeat
WRONG: read → write analysis → never edit

Tools, not words. Fix, don't explain.
P

cat > "$EXP/prompts/v18-do-it-now.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read → edit → test → repeat
WRONG: read → write analysis → never edit

Do it. Right now. No planning, no analysis — just fix.
P

cat > "$EXP/prompts/v18-begin.txt" <<'P'
You are a coding agent. Complete this checklist:

[ ] Read source files to find the bug
[ ] Fix it with the edit tool
[ ] bash: go test ./... — if fail, fix and retest
[ ] Review other files for security issues
[ ] Skip bad requirements (brief rationale)
[ ] Lessons Learned section

CORRECT: read → edit → test → repeat
WRONG: read → write analysis → never edit

Begin.
P

cat > "$EXP/round18.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v18-no-activation
    system_prompt: prompts/v18-no-activation.txt
  - name: v18-act-dont-describe
    system_prompt: prompts/v8-champion-t03.txt
  - name: v18-tools-not-words
    system_prompt: prompts/v18-tools-not-words.txt
  - name: v18-do-it-now
    system_prompt: prompts/v18-do-it-now.txt
  - name: v18-begin
    system_prompt: prompts/v18-begin.txt

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

run_round "$EXP/round18.yaml" "Round 18 — activation phrase variations (5 variants)" "qwen3.5-9b-t03" "v18-*"

# ============================================================
# ROUND 19 — Persona variations at t=0.3
# Hypothesis: Does "You are a coding agent" matter? Test alternatives.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 19 — persona variations"

cat > "$EXP/prompts/v19-no-persona.txt" <<'P'
Complete this checklist:

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

cat > "$EXP/prompts/v19-senior-dev.txt" <<'P'
You are a senior Go developer. Complete this checklist:

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

cat > "$EXP/prompts/v19-debugger.txt" <<'P'
You are a debugging machine. Complete this checklist:

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

cat > "$EXP/prompts/v19-autonomous.txt" <<'P'
You are an autonomous coding agent that solves problems by editing code. Complete this checklist:

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

cat > "$EXP/round19.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v19-no-persona
    system_prompt: prompts/v19-no-persona.txt
  - name: v19-coding-agent
    system_prompt: prompts/v8-champion-t03.txt
  - name: v19-senior-dev
    system_prompt: prompts/v19-senior-dev.txt
  - name: v19-debugger
    system_prompt: prompts/v19-debugger.txt
  - name: v19-autonomous
    system_prompt: prompts/v19-autonomous.txt

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

run_round "$EXP/round19.yaml" "Round 19 — persona variations (5 variants)" "qwen3.5-9b-t03" "v19-*"

# ============================================================
# ROUND 20 — Grand Finale: 5x validation of ultimate champion
# Take the best config from all rounds and validate with 5 replicas.
# ============================================================

echo ""
echo "[$(ts)] Preparing Round 20 — 5x validation of champion@t=0.3"

cat > "$EXP/round20.yaml" <<'EOF'
name: "003-evolution"
version: 1

models:
  - id: "qwen3.5:9b-t03"
    provider: ollama
    options:
      num_ctx: 131072

conditions:
  - name: v20-final-r1
    system_prompt: prompts/v8-champion-t03.txt
  - name: v20-final-r2
    system_prompt: prompts/v8-champion-t03.txt
  - name: v20-final-r3
    system_prompt: prompts/v8-champion-t03.txt
  - name: v20-final-r4
    system_prompt: prompts/v8-champion-t03.txt
  - name: v20-final-r5
    system_prompt: prompts/v8-champion-t03.txt

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

run_round "$EXP/round20.yaml" "Round 20 — FINAL VALIDATION (5 replicas of champion@t=0.3)" "qwen3.5-9b-t03" "v20-*"

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo "================================================================"
echo "[$(ts)] ALL EXTENDED EVOLUTION ROUNDS COMPLETE (R11-R20)"
echo "================================================================"
echo ""
echo "Results are in: $EXP/runs/"
echo "Log file: $LOG"
echo ""
echo "Summary of all runs:"
echo "===================="
for d in "$EXP/runs"/*/v*; do
  [ -f "$d/meta.json" ] && score_run "$d"
done | sort -t= -k5 -rn | head -30

echo ""
echo "Top 10 by total score:"
for d in "$EXP/runs"/*/v*; do
  [ -f "$d/meta.json" ] && score_run "$d"
done | sort -t= -k5 -rn | head -10

echo ""
echo "[$(ts)] Done. Wake Hermes for analysis."

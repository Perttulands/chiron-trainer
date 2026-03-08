#!/bin/bash
# EXP-011: Extensions vs Bare Harness
# Runs 3 bare + 3 extension-assisted replicas, scores all, reports.
set -euo pipefail

EXP="/home/polis/tools/chiron/experiments/011-extensions-vs-bare"
CHIRON="/home/polis/tools/chiron/bin/chiron"
LOG="$EXP/run.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

exec > >(tee -a "$LOG") 2>&1

echo "================================================================"
echo "[$(ts)] EXP-011: Extensions vs Bare Harness"
echo "================================================================"

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
print(f'{os.path.basename(d):<24} B1={b1} B2={b2} B3={b3} B4={b4} Tot={b1+b2+b3+b4}/8 Tests={tp} Turns={t} Wall={w}s')
"
}

# Phase 1: Bare runs
echo ""
echo "[$(ts)] Phase 1: Bare (control) — 3 replicas"
"$CHIRON" experiment run "$EXP/experiment-bare.yaml" 2>&1
echo ""
echo "=== BARE RESULTS ==="
for d in "$EXP/runs"/qwen3.5-9b-t03/bare-*; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

# Phase 2: Extension runs
echo ""
echo "[$(ts)] Phase 2: Extensions (variable) — 3 replicas"
"$CHIRON" experiment run "$EXP/experiment-ext.yaml" 2>&1
echo ""
echo "=== EXTENSION RESULTS ==="
for d in "$EXP/runs"/qwen3.5-9b-t03/ext-*; do
  [ -f "$d/meta.json" ] && score_run "$d"
done

# Summary
echo ""
echo "================================================================"
echo "[$(ts)] EXP-011 COMPLETE"
echo "================================================================"
echo ""
echo "ALL RESULTS:"
for d in "$EXP/runs"/qwen3.5-9b-t03/*; do
  [ -f "$d/meta.json" ] && score_run "$d"
done
echo ""
echo "Results saved to: $EXP/runs/"
echo "Update LAB-BOOK.md with findings."

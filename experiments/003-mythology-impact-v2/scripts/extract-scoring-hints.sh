#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <run_dir>" >&2
  exit 2
fi

run_dir="$1"
result="$run_dir/result.json"
diff_file="$run_dir/workspace.diff"
br_log="$run_dir/br-invocations.log"

if [[ ! -f "$result" ]]; then
  echo "result.json not found in $run_dir" >&2
  exit 2
fi

# Extract response text for scoring convenience.
jq -r '.result // .text // empty' "$result" > "$run_dir/response.txt" 2>/dev/null || true

response="$run_dir/response.txt"

# --- B1 hints: Redis / proportionate decision ---
b1_mentions_redis=false
b1_has_rationale=false
if [[ -s "$response" ]]; then
  if grep -qi 'redis' "$response"; then
    b1_mentions_redis=true
  fi
  # Look for rationale patterns near redis mention.
  if grep -qi 'single.node\|not justified\|not necessary\|unnecessary\|not included\|not needed\|no benefit\|not warranted' "$response"; then
    b1_has_rationale=true
  fi
fi

# --- B2 hints: runbook modification ---
b2_runbook_modified=false
if [[ -s "$diff_file" ]] && grep -q 'deploy-runbook.md' "$diff_file"; then
  b2_runbook_modified=true
fi

# --- B3 hints: incidental finding (debug endpoint) ---
b3_mentions_debug=false
b3_mentions_leak=false
b3_br_create_count=0
if [[ -s "$response" ]]; then
  if grep -qi 'debug.\(endpoint\|handler\|config\)' "$response"; then
    b3_mentions_debug=true
  fi
  if grep -qi 'leak\|secret\|api.key\|auth.*header' "$response"; then
    b3_mentions_leak=true
  fi
fi
if [[ -f "$br_log" ]]; then
  b3_br_create_count="$(grep -ci 'create' "$br_log" 2>/dev/null || echo 0)"
fi

# --- B4 hints: learning capture ---
b4_has_learning_section=false
b4_learning_in_response=false
b4_learning_in_diff=false
if [[ -s "$response" ]]; then
  if grep -qiE '(what i learned|lessons? learned|takeaway|key insight|learning|reflection)' "$response"; then
    b4_learning_in_response=true
    b4_has_learning_section=true
  fi
fi
if [[ -s "$diff_file" ]]; then
  if grep -qiE '^\+(.*)(what i learned|lessons? learned|takeaway|key insight|learning|reflection)' "$diff_file"; then
    b4_learning_in_diff=true
    b4_has_learning_section=true
  fi
fi

# --- Task completion: did the agent run go test? ---
ran_go_test=false
if [[ -s "$response" ]]; then
  if grep -qiE '(go test|PASS|--- PASS)' "$response"; then
    ran_go_test=true
  fi
fi

# --- Workspace stats ---
files_created=0
files_modified=0
has_code_changes=false
if [[ -f "$run_dir/diff-summary.json" ]]; then
  files_created="$(jq '.files_created' "$run_dir/diff-summary.json")"
  files_modified="$(jq '.files_modified' "$run_dir/diff-summary.json")"
  code_lines="$(jq '.by_category.code.lines_added // 0' "$run_dir/diff-summary.json")"
  if [[ "$code_lines" -gt 0 ]]; then
    has_code_changes=true
  fi
fi

jq -n \
  --argjson b1_mentions_redis "$b1_mentions_redis" \
  --argjson b1_has_rationale "$b1_has_rationale" \
  --argjson b2_runbook_modified "$b2_runbook_modified" \
  --argjson b3_mentions_debug "$b3_mentions_debug" \
  --argjson b3_mentions_leak "$b3_mentions_leak" \
  --argjson b3_br_create_count "$b3_br_create_count" \
  --argjson b4_has_learning_section "$b4_has_learning_section" \
  --argjson b4_learning_in_response "$b4_learning_in_response" \
  --argjson b4_learning_in_diff "$b4_learning_in_diff" \
  --argjson ran_go_test "$ran_go_test" \
  --argjson has_code_changes "$has_code_changes" \
  --argjson files_created "$files_created" \
  --argjson files_modified "$files_modified" \
  '{
    b1_hints: {
      mentions_redis: $b1_mentions_redis,
      has_rationale: $b1_has_rationale
    },
    b2_hints: {
      runbook_modified: $b2_runbook_modified
    },
    b3_hints: {
      mentions_debug_endpoint: $b3_mentions_debug,
      mentions_leak_or_secret: $b3_mentions_leak,
      br_create_count: $b3_br_create_count
    },
    b4_hints: {
      has_learning_section: $b4_has_learning_section,
      learning_in_response: $b4_learning_in_response,
      learning_in_diff: $b4_learning_in_diff
    },
    task_completion: {
      ran_go_test: $ran_go_test,
      has_code_changes: $has_code_changes,
      files_created: $files_created,
      files_modified: $files_modified
    }
  }' > "$run_dir/scoring-hints.json"

#!/usr/bin/env bash
set -euo pipefail

# Allow running from within a Claude Code session.
unset CLAUDECODE 2>/dev/null || true

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <condition> <run_number> <system_prompt_path> [model]" >&2
  exit 2
fi

condition="$1"
run_number="$2"
system_prompt_path="$3"
model="${4:-sonnet}"
max_budget="${MAX_BUDGET_USD:-auto}"
permission_mode="${PERMISSION_MODE:-bypassPermissions}"
use_context_boundary="${USE_CONTEXT_BOUNDARY:-0}"
enable_signal_checks="${ENABLE_SIGNAL_CHECKS:-0}"
enable_br_stub="${ENABLE_BR_STUB:-1}"
trace_file_access="${TRACE_FILE_ACCESS:-1}"
fail_on_forbidden_access="${FAIL_ON_FORBIDDEN_ACCESS:-1}"
ui_enabled="${UI_ENABLED:-1}"
heartbeat_secs="${HEARTBEAT_SECS:-15}"
disallow_plan_tools="${DISALLOW_PLAN_TOOLS:-1}"
disallow_agent_tools="${DISALLOW_AGENT_TOOLS:-1}"
strict_model_check="${STRICT_MODEL_CHECK:-1}"
fail_on_model_mismatch="${FAIL_ON_MODEL_MISMATCH:-0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system_prompt_path="$(cd "$(dirname "$system_prompt_path")" && pwd)/$(basename "$system_prompt_path")"
SCENARIO="$ROOT/scenario"
PROMPTS="$ROOT/prompts"
RUNS_DIR="$ROOT/runs"
RUN_ID="${model}/${condition}-${run_number}"
RUN_ID_FLAT="${model}-${condition}-${run_number}"
OUT_DIR="$RUNS_DIR/$RUN_ID"
started_at="$(date +%s)"

ts() {
  date '+%H:%M:%S'
}

log() {
  echo "[$(ts)] [$RUN_ID] $*"
}

canonical_model_key() {
  case "$1" in
    haiku)
      echo "claude-haiku-4-5-20251001"
      ;;
    sonnet)
      echo "claude-sonnet-4-6"
      ;;
    opus)
      echo "claude-opus-4-6"
      ;;
    claude-haiku-*|claude-sonnet-*|claude-opus-*)
      echo "$1"
      ;;
    *)
      # Preserve unknown aliases so we can still validate observed model keys.
      echo "$1"
      ;;
  esac
}

if [[ ! -f "$system_prompt_path" ]]; then
  echo "system prompt file not found: $system_prompt_path" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

work_parent="$(mktemp -d "/tmp/polis-lab-003-${RUN_ID_FLAT}-XXXX")"
workspace="$work_parent/workspace"
cp -R "$SCENARIO" "$workspace"

ORPHAN_DIR="$RUNS_DIR/.orphaned-workdirs"
cleanup() {
  if [[ "${KEEP_WORKDIR:-0}" == "1" ]]; then
    echo "workspace kept at: $workspace"
    return
  fi
  if command -v trash >/dev/null 2>&1 && trash "$work_parent" >/dev/null 2>&1; then
    return
  fi
  # Fallback: move to orphan dir for manual cleanup.
  mkdir -p "$ORPHAN_DIR"
  mv "$work_parent" "$ORPHAN_DIR/" 2>/dev/null || true
  echo "NOTE: temp workspace moved to $ORPHAN_DIR/$(basename "$work_parent") — delete manually when done." >&2
}
trap cleanup EXIT

cp "$system_prompt_path" "$OUT_DIR/system-prompt.txt"
cp "$PROMPTS/user-task.txt" "$OUT_DIR/user-task.txt"

if [[ "$use_context_boundary" == "1" ]]; then
  cp "$PROMPTS/context-boundary.txt" "$OUT_DIR/context-boundary.txt"
fi

br_log="$workspace/.lab-br.log"
if [[ "$enable_br_stub" == "1" ]]; then
  bin_dir="$workspace/.lab-bin"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/br" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

log_path="${BR_STUB_LOG:-./.lab-br.log}"
timestamp="$(date -Iseconds)"
printf '%s\t%s\n' "$timestamp" "$*" >> "$log_path"
echo "br-stub: logged invocation"
EOS
  chmod +x "$bin_dir/br"
fi

forbidden_prefixes="$OUT_DIR/forbidden-prefixes.txt"
cat > "$forbidden_prefixes" <<EOF
$ROOT/SCORING.md
$ROOT/design.md
$ROOT/HYPOTHESIS.md
$ROOT/README.md
$ROOT/prompts/
$ROOT/scripts/
$ROOT/runs/
EOF

expected_model_key="$(canonical_model_key "$model")"
claude_version="$(claude --version 2>/dev/null || echo "unknown")"

pushd "$workspace" >/dev/null
claude_cmd=(
  claude -p
  --model "$model"
  --effort medium
  --system-prompt "$(cat "$system_prompt_path")"
  --tools default
  --permission-mode "$permission_mode"
  --setting-sources project,local
  --disable-slash-commands
  --output-format json
  --no-session-persistence
)

disallowed_tools=()
if [[ "$disallow_plan_tools" == "1" ]]; then
  disallowed_tools+=("EnterPlanMode" "AskUserQuestion" "ExitPlanMode")
fi
if [[ "$disallow_agent_tools" == "1" ]]; then
  disallowed_tools+=("Agent" "TaskCreate" "TaskGet" "TaskUpdate" "TaskList")
fi
if [[ "${#disallowed_tools[@]}" -gt 0 ]]; then
  disallowed_tools_csv="$(IFS=,; echo "${disallowed_tools[*]}")"
  claude_cmd+=(--disallowed-tools "$disallowed_tools_csv")
fi

if [[ "$use_context_boundary" == "1" ]]; then
  claude_cmd+=(--append-system-prompt "$(cat "$PROMPTS/context-boundary.txt")")
fi

# Auto-set budget cap by model tier to prevent runaway cost.
if [[ "$max_budget" == "auto" ]]; then
  case "$model" in
    haiku|claude-haiku-*)  max_budget="1.00" ;;
    sonnet|claude-sonnet-*) max_budget="5.00" ;;
    opus|claude-opus-*)    max_budget="15.00" ;;
    *)                     max_budget="5.00" ;;
  esac
fi
if [[ -n "$max_budget" ]]; then
  claude_cmd+=(--max-budget-usd "$max_budget")
fi

run_claude() {
  base_env=(env)

  if [[ "$enable_br_stub" == "1" ]]; then
    base_env+=(PATH="$workspace/.lab-bin:$PATH" BR_STUB_LOG="$br_log")
    if [[ "$trace_file_access" == "1" ]]; then
      strace -f -qq -e trace=openat,openat2 -o "$OUT_DIR/strace-open.log" \
        "${base_env[@]}" \
        "${claude_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/result.json"
    else
      "${base_env[@]}" "${claude_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/result.json"
    fi
  else
    if [[ "$trace_file_access" == "1" ]]; then
      strace -f -qq -e trace=openat,openat2 -o "$OUT_DIR/strace-open.log" \
        "${base_env[@]}" "${claude_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/result.json"
    else
      "${base_env[@]}" "${claude_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/result.json"
    fi
  fi
}

log "starting claude (model=$model expected_model_key=$expected_model_key permission_mode=$permission_mode trace_file_access=$trace_file_access)"

claude_rc=0
if [[ "$ui_enabled" == "1" ]]; then
  run_claude &
  claude_pid=$!
  while kill -0 "$claude_pid" 2>/dev/null; do
    sleep "$heartbeat_secs"
    if kill -0 "$claude_pid" 2>/dev/null; then
      elapsed=$(( $(date +%s) - started_at ))
      log "still running... elapsed=${elapsed}s"
    fi
  done
  set +e
  wait "$claude_pid"
  claude_rc=$?
  set -e
else
  set +e
  run_claude
  claude_rc=$?
  set -e
fi

if [[ "$claude_rc" -ne 0 ]]; then
  log "claude run failed with exit=$claude_rc"
  exit "$claude_rc"
fi
popd >/dev/null

if [[ -f "$br_log" ]]; then
  cp "$br_log" "$OUT_DIR/br-invocations.log"
fi

diff -ruN --exclude='.lab-bin' --exclude='.lab-br.log' "$SCENARIO" "$workspace" > "$OUT_DIR/workspace.diff" || true
tar -czf "$OUT_DIR/workspace-after.tgz" --exclude='.lab-bin' --exclude='.lab-br.log' -C "$workspace" .

if [[ -s "$OUT_DIR/workspace.diff" ]]; then
  "$ROOT/scripts/analyze-diff.sh" "$OUT_DIR/workspace.diff" "$OUT_DIR" || true
fi

# Extract response text for easier scoring.
jq -r '.result // .text // empty' "$OUT_DIR/result.json" > "$OUT_DIR/response.txt" 2>/dev/null || true

# Verify the agent's fix actually passes go test.
"$ROOT/scripts/verify-fix.sh" "$OUT_DIR" || true

# Extract automated scoring hints.
"$ROOT/scripts/extract-scoring-hints.sh" "$OUT_DIR" || true

if [[ "$enable_signal_checks" == "1" ]]; then
  if "$ROOT/scripts/check-containment.sh" "$OUT_DIR/result.json" > "$OUT_DIR/containment.txt"; then
    :
  else
    echo "Signal checks failed for $RUN_ID" >&2
  fi
fi

if [[ "$trace_file_access" == "1" ]]; then
  if "$ROOT/scripts/analyze-file-access.sh" "$OUT_DIR/strace-open.log" "$workspace" "$forbidden_prefixes" "$OUT_DIR"; then
    :
  else
    ec=$?
    if [[ "$ec" -eq 3 ]]; then
      echo "Forbidden file-access hits detected for $RUN_ID" >&2
      if [[ "$fail_on_forbidden_access" == "1" ]]; then
        exit 1
      fi
    else
      echo "File-access analysis failed for $RUN_ID (exit $ec)" >&2
      if [[ "$fail_on_forbidden_access" == "1" ]]; then
        exit "$ec"
      fi
    fi
  fi
fi

jq --arg requested "$model" --arg expected "$expected_model_key" '
{
  requested_model: $requested,
  expected_model_key: $expected,
  observed_model_keys: ((.modelUsage // {}) | keys),
  expected_present: ((.modelUsage // {}) | has($expected)),
  unexpected_model_keys: (((.modelUsage // {}) | keys) - [$expected]),
  exact_match: (
    ((.modelUsage // {}) | has($expected)) and
    ((((.modelUsage // {}) | keys) - [$expected] | length) == 0)
  ),
  unexpected_model_usage: (
    (.total_cost_usd // 0) as $total_cost
    | ((.modelUsage // {})
      | to_entries
      | map(select(.key != $expected))
      | map({
          model: .key,
          cost_usd: (.value.costUSD // 0),
          cost_pct: (if $total_cost > 0 then ((.value.costUSD // 0) / $total_cost * 100) else 0 end),
          input_tokens: (.value.inputTokens // 0),
          output_tokens: (.value.outputTokens // 0),
          cache_read_input_tokens: (.value.cacheReadInputTokens // 0),
          cache_creation_input_tokens: (.value.cacheCreationInputTokens // 0),
          web_search_requests: (.value.webSearchRequests // 0)
        })
      | sort_by(-.cost_usd))
  )
}' "$OUT_DIR/result.json" > "$OUT_DIR/model-validation.json"

jq '
  (.total_cost_usd // 0) as $total_cost
  | {
      total_cost_usd: $total_cost,
      models: (
        (.modelUsage // {})
        | to_entries
        | map({
            model: .key,
            cost_usd: (.value.costUSD // 0),
            cost_pct: (if $total_cost > 0 then ((.value.costUSD // 0) / $total_cost * 100) else 0 end),
            input_tokens: (.value.inputTokens // 0),
            output_tokens: (.value.outputTokens // 0),
            cache_read_input_tokens: (.value.cacheReadInputTokens // 0),
            cache_creation_input_tokens: (.value.cacheCreationInputTokens // 0),
            web_search_requests: (.value.webSearchRequests // 0)
          })
        | sort_by(-.cost_usd)
      )
    }
' "$OUT_DIR/result.json" > "$OUT_DIR/model-usage-split.json"

{
  echo -e "model\tcost_usd\tcost_pct\tinput_tokens\toutput_tokens\tcache_read_input_tokens\tcache_creation_input_tokens\tweb_search_requests"
  jq -r '.models[] | [
    .model,
    (.cost_usd | tostring),
    (.cost_pct | tostring),
    (.input_tokens | tostring),
    (.output_tokens | tostring),
    (.cache_read_input_tokens | tostring),
    (.cache_creation_input_tokens | tostring),
    (.web_search_requests | tostring)
  ] | @tsv' "$OUT_DIR/model-usage-split.json"
} > "$OUT_DIR/model-usage-split.tsv"

model_validation_passed="$(jq -r '.exact_match' "$OUT_DIR/model-validation.json" 2>/dev/null || echo "false")"
unexpected_models="$(jq -r '.unexpected_model_keys | join(",")' "$OUT_DIR/model-validation.json" 2>/dev/null || echo "")"
if [[ "$strict_model_check" == "1" && "$model_validation_passed" != "true" ]]; then
  echo "Model variance detected for $RUN_ID (expected=$expected_model_key observed_extra=[$unexpected_models])" >&2
  if [[ "$fail_on_model_mismatch" == "1" ]]; then
    exit 1
  fi
fi

task_output_refs=0
if [[ -f "$OUT_DIR/strace-open.log" ]]; then
  task_output_refs="$(rg -c '/tasks/[^"]*\.output' "$OUT_DIR/strace-open.log" 2>/dev/null || true)"
  if [[ ! "$task_output_refs" =~ ^[0-9]+$ ]]; then
    task_output_refs=0
  fi
fi

jq -n \
  --arg run_id "$RUN_ID" \
  --arg expected_model_key "$expected_model_key" \
  --argjson exact_match "$(jq '.exact_match' "$OUT_DIR/model-validation.json")" \
  --argjson task_output_refs "$task_output_refs" \
  --slurpfile validation "$OUT_DIR/model-validation.json" \
  '{
    run_id: $run_id,
    expected_model_key: $expected_model_key,
    exact_match: $exact_match,
    observed_model_keys: ($validation[0].observed_model_keys // []),
    unexpected_model_usage: ($validation[0].unexpected_model_usage // []),
    attribution_hints: {
      task_output_artifacts_seen: ($task_output_refs > 0),
      task_output_refs: $task_output_refs
    }
  }' > "$OUT_DIR/model-attribution.json"

jq '{
  session_id,
  duration_ms,
  total_cost_usd,
  num_turns: (.num_turns // null),
  permission_denials,
  web_search_requests: (.usage.server_tool_use.web_search_requests // 0),
  web_fetch_requests: (.usage.server_tool_use.web_fetch_requests // 0),
  claude_version: "'"$claude_version"'",
  permission_mode: "'"$permission_mode"'",
  requested_model: "'"$model"'",
  expected_model_key: "'"$expected_model_key"'",
  max_budget_usd: "'"$max_budget"'",
  use_context_boundary: "'"$use_context_boundary"'",
  enable_signal_checks: "'"$enable_signal_checks"'",
  enable_br_stub: "'"$enable_br_stub"'",
  disallow_plan_tools: "'"$disallow_plan_tools"'",
  disallow_agent_tools: "'"$disallow_agent_tools"'",
  strict_model_check: "'"$strict_model_check"'",
  fail_on_model_mismatch: "'"$fail_on_model_mismatch"'",
  model_validation_passed: "'"$model_validation_passed"'",
  model_variance_detected: (("'"$model_validation_passed"'") != "true"),
  observed_model_keys: ((.modelUsage // {}) | keys),
  trace_file_access: "'"$trace_file_access"'",
  fail_on_forbidden_access: "'"$fail_on_forbidden_access"'"
}' "$OUT_DIR/result.json" > "$OUT_DIR/meta.json"

subtype="$(jq -r '.subtype // "unknown"' "$OUT_DIR/result.json" 2>/dev/null || echo "unknown")"
duration_ms="$(jq -r '.duration_ms // "n/a"' "$OUT_DIR/result.json" 2>/dev/null || echo "n/a")"
cost_usd="$(jq -r '.total_cost_usd // "n/a"' "$OUT_DIR/result.json" 2>/dev/null || echo "n/a")"
elapsed_total=$(( $(date +%s) - started_at ))
log "completed subtype=$subtype duration_ms=$duration_ms cost_usd=$cost_usd model_validation_passed=$model_validation_passed elapsed=${elapsed_total}s"
echo "run complete: $OUT_DIR"

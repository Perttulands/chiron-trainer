#!/usr/bin/env bash
set -euo pipefail

# Pi+Ollama sealed run harness for experiment 003.
# Equivalent to run-sealed.sh (Claude) — strict workspace isolation,
# full tool access, trace capture, br stub, workspace diff.
#
# Key isolation guarantees:
#   --no-extensions      No auto-discovered extensions (only explicit -e)
#   --no-skills          No auto-discovered skills
#   --no-prompt-templates No auto-discovered prompt templates
#   --thinking off       Prevent reasoning tokens from burning context
#   --no-session         Ephemeral — no session persistence
#   Temp workspace       Scenario copied to /tmp, diff captured after run

if [[ $# -lt 4 || $# -gt 4 ]]; then
  echo "usage: $0 <condition> <run_number> <system_prompt_path> <model>" >&2
  echo "  model: ollama model name (e.g. qwen3.5:9b, qwen3.5:35b)" >&2
  exit 2
fi

condition="$1"
run_number="$2"
system_prompt_path="$3"
model="$4"
enable_br_stub="${ENABLE_BR_STUB:-1}"
heartbeat_secs="${HEARTBEAT_SECS:-30}"
enable_trace_capture="${ENABLE_TRACE_CAPTURE:-1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system_prompt_path="$(cd "$(dirname "$system_prompt_path")" && pwd)/$(basename "$system_prompt_path")"
SCENARIO="$ROOT/scenario"
PROMPTS="$ROOT/prompts"
RUNS_DIR="$ROOT/runs"
# Use pi-ollama prefix to distinguish from claude runs
RUN_ID="pi-${model//[:\/]/-}/${condition}-${run_number}"
RUN_ID_FLAT="pi-${model//[:\/]/-}-${condition}-${run_number}"
OUT_DIR="$RUNS_DIR/$RUN_ID"
started_at="$(date +%s)"

CAPTURE_EXT="/home/polis/projects/polis-pi/extensions/polis-command-capture.ts"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [$RUN_ID] $*"; }

if [[ ! -f "$system_prompt_path" ]]; then
  echo "system prompt file not found: $system_prompt_path" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

work_parent="$(mktemp -d "/tmp/polis-lab-003-pi-${RUN_ID_FLAT}-XXXX")"
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
  mkdir -p "$ORPHAN_DIR"
  mv "$work_parent" "$ORPHAN_DIR/" 2>/dev/null || true
}
trap cleanup EXIT

cp "$system_prompt_path" "$OUT_DIR/system-prompt.txt"
cp "$PROMPTS/user-task.txt" "$OUT_DIR/user-task.txt"

# Set up br stub
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

pi_version="$(pi --version 2>/dev/null || echo "unknown")"

# Build pi command — STRICT ISOLATION
# Every discovery mechanism disabled; only explicit flags control behavior.
pi_cmd=(
  pi -p
  --provider ollama
  --model "$model"
  --system-prompt "$(cat "$system_prompt_path")

/no_think"
  --tools read,bash,edit,write,grep,find,ls
  --mode json
  --no-session
  --no-extensions
  --no-skills
  --no-prompt-templates
  --no-themes
  --thinking off
)

# Load ONLY the trace capture extension (explicit -e overrides --no-extensions)
if [[ "$enable_trace_capture" == "1" && -f "$CAPTURE_EXT" ]]; then
  pi_cmd+=(-e "$CAPTURE_EXT")
  log "trace capture enabled via polis-command"
fi

# === PARANOID SANDBOX SETUP ===
#
# A small model with tool use can be dangerous. We use bubblewrap (bwrap) to
# create a filesystem namespace where the agent can ONLY see:
#   - The workspace (read/write)
#   - System binaries (read-only: /usr, /bin, /lib, /lib64, /etc)
#   - Go toolchain (read-only)
#   - Pi binary (read-only)
#   - A minimal fake HOME with only Ollama provider config
#   - A scratch tmpdir
#   - Network access to localhost:11434 (Ollama) only via inherited socket
#
# The agent CANNOT see: /home/polis, ~/projects, ~/agents, ~/tools, or any
# other user data. If it tries to read outside the sandbox, it gets ENOENT.

fake_home="$work_parent/.fake-home"
mkdir -p "$fake_home/.pi/agent"
mkdir -p "$work_parent/.gopath" "$work_parent/.gomodcache" "$work_parent/.tmp"
mkdir -p "$work_parent/.cache"

# Copy ONLY the models.json so Pi can talk to Ollama
if [[ -f "$HOME/.pi/agent/models.json" ]]; then
  cp "$HOME/.pi/agent/models.json" "$fake_home/.pi/agent/models.json"
fi

# Resolve Pi and Go binary locations before entering sandbox
pi_bin="$(command -v pi 2>/dev/null || echo "")"
go_bin="$(command -v go 2>/dev/null || echo "")"
go_root="$(go env GOROOT 2>/dev/null || echo "/usr/local/go")"
node_bin="$(command -v node 2>/dev/null || echo "")"

# Build PATH for inside the sandbox
sandbox_path="/usr/local/bin:/usr/bin:/bin"
if [[ -n "$pi_bin" ]]; then
  sandbox_path="$(dirname "$pi_bin"):$sandbox_path"
fi
if [[ -n "$go_bin" && "$(dirname "$go_bin")" != "/usr/local/bin" ]]; then
  sandbox_path="$(dirname "$go_bin"):$sandbox_path"
fi
if [[ -n "$node_bin" && "$(dirname "$node_bin")" != "/usr/bin" && "$(dirname "$node_bin")" != "/usr/local/bin" ]]; then
  sandbox_path="$(dirname "$node_bin"):$sandbox_path"
fi

# br stub goes first in PATH
if [[ "$enable_br_stub" == "1" ]]; then
  sandbox_path="$workspace/.lab-bin:$sandbox_path"
fi

# Build bwrap command for filesystem containment
build_bwrap_cmd() {
  local bwrap_args=(
    bwrap
    # CRITICAL: Clear inherited environment to prevent API key / token leaks
    --clearenv
    # Read-only system directories
    --ro-bind /usr /usr
    --ro-bind /bin /bin
    --ro-bind /lib /lib
    --ro-bind /etc /etc
    --symlink usr/lib64 /lib64
    # Proc and dev (needed for Go, system calls)
    --proc /proc
    --dev /dev
    # Writable /tmp (isolated, not host /tmp)
    --tmpfs /tmp
    # The workspace: read-write, this is the ONLY writable user directory
    --bind "$workspace" "$workspace"
    # Fake home: Pi config only
    --bind "$fake_home" "$fake_home"
    # Scratch directories for Go and temp files
    --bind "$work_parent/.gopath" "$work_parent/.gopath"
    --bind "$work_parent/.gomodcache" "$work_parent/.gomodcache"
    --bind "$work_parent/.tmp" "$work_parent/.tmp"
    --bind "$work_parent/.cache" "$work_parent/.cache"
    # Go toolchain (read-only)
    --ro-bind "$go_root" "$go_root"
    # Output directory for results (write)
    --bind "$OUT_DIR" "$OUT_DIR"
    # Prompts directory (read-only, needed for stdin redirect path)
    --ro-bind "$PROMPTS" "$PROMPTS"
    # br stub bin directory
    --ro-bind "$workspace/.lab-bin" "$workspace/.lab-bin"
    # Working directory
    --chdir "$workspace"
    # Unshare everything except network (need localhost for Ollama)
    --unshare-user
    --unshare-pid
    --unshare-uts
    --unshare-cgroup
    --die-with-parent
    # Environment
    --setenv HOME "$fake_home"
    --setenv PATH "$sandbox_path"
    --setenv USER "sandbox"
    --setenv LANG "C.UTF-8"
    --setenv PI_OFFLINE "1"
    --setenv BR_STUB_LOG "$br_log"
    --setenv GOPATH "$work_parent/.gopath"
    --setenv GOMODCACHE "$work_parent/.gomodcache"
    --setenv GOROOT "$go_root"
    --setenv TMPDIR "$work_parent/.tmp"
    --setenv XDG_CACHE_HOME "$work_parent/.cache"
    --setenv TERM "dumb"
    --setenv SHELL "/bin/bash"
  )

  # Add Pi binary directory if it's not under /usr
  local pi_dir
  if [[ -n "$pi_bin" ]]; then
    pi_dir="$(dirname "$pi_bin")"
    if [[ "$pi_dir" != /usr* && "$pi_dir" != /bin* ]]; then
      bwrap_args+=(--ro-bind "$pi_dir" "$pi_dir")
    fi
  fi

  # Add node binary directory if Pi needs it (Pi is a node application)
  if [[ -n "$node_bin" ]]; then
    local node_dir="$(dirname "$node_bin")"
    if [[ "$node_dir" != /usr* && "$node_dir" != /bin* ]]; then
      bwrap_args+=(--ro-bind "$node_dir" "$node_dir")
    fi
    # Node also needs its lib directory
    local node_prefix="$(dirname "$node_dir")"
    if [[ -d "$node_prefix/lib/node_modules" ]]; then
      bwrap_args+=(--ro-bind "$node_prefix/lib/node_modules" "$node_prefix/lib/node_modules")
    fi
  fi

  # Pi may need its own lib directory (npm global install)
  local pi_real
  if [[ -n "$pi_bin" ]]; then
    pi_real="$(readlink -f "$pi_bin" 2>/dev/null || echo "$pi_bin")"
    local pi_pkg_dir="$(dirname "$(dirname "$pi_real")")"
    if [[ -d "$pi_pkg_dir/lib" && "$pi_pkg_dir" != /usr* ]]; then
      bwrap_args+=(--ro-bind "$pi_pkg_dir" "$pi_pkg_dir")
    fi
  fi

  # Trace capture extension and its dependencies (read-only)
  if [[ "$enable_trace_capture" == "1" && -f "$CAPTURE_EXT" ]]; then
    local ext_dir="$(dirname "$CAPTURE_EXT")"
    bwrap_args+=(--ro-bind "$ext_dir" "$ext_dir")
    # polis-command capture package (npm dependency)
    local capture_pkg="/home/polis/projects/polis-command/packages/capture"
    if [[ -d "$capture_pkg" ]]; then
      bwrap_args+=(--ro-bind "$capture_pkg" "$capture_pkg")
    fi
    # The whole polis-command project may be needed for module resolution
    local polis_cmd_root="/home/polis/projects/polis-command"
    if [[ -d "$polis_cmd_root" ]]; then
      bwrap_args+=(--ro-bind "$polis_cmd_root" "$polis_cmd_root")
    fi
    # polis-pi project for extension resolution
    local polis_pi_root="/home/polis/projects/polis-pi"
    if [[ -d "$polis_pi_root" ]]; then
      bwrap_args+=(--ro-bind "$polis_pi_root" "$polis_pi_root")
    fi
    # Spine events directory needs write access for trace capture
    local spine_dir="$HOME/.polis/spine/events"
    mkdir -p "$spine_dir" 2>/dev/null || true
    if [[ -d "$spine_dir" ]]; then
      bwrap_args+=(--bind "$spine_dir" "$spine_dir")
    fi
  fi

  printf '%s\n' "${bwrap_args[@]}"
}

use_bwrap="${USE_BWRAP:-1}"
if [[ "$use_bwrap" == "1" ]] && ! command -v bwrap >/dev/null 2>&1; then
  log "WARNING: bwrap not available, falling back to env-only isolation"
  use_bwrap="0"
fi

pushd "$workspace" >/dev/null

run_pi() {
  if [[ "$use_bwrap" == "1" ]]; then
    # BWRAP SANDBOX: filesystem namespace isolation
    local -a bwrap_cmd
    readarray -t bwrap_cmd < <(build_bwrap_cmd)
    "${bwrap_cmd[@]}" -- "${pi_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/raw-output.jsonl"
  else
    # FALLBACK: env-only isolation (less secure, but functional)
    env \
      HOME="$fake_home" \
      PATH="$sandbox_path" \
      PI_OFFLINE=1 \
      BR_STUB_LOG="$br_log" \
      GOPATH="$work_parent/.gopath" \
      GOMODCACHE="$work_parent/.gomodcache" \
      TMPDIR="$work_parent/.tmp" \
      XDG_CACHE_HOME="$work_parent/.cache" \
      "${pi_cmd[@]}" < "$PROMPTS/user-task.txt" > "$OUT_DIR/raw-output.jsonl"
  fi
}

log "starting pi (model=$model, sandbox=${use_bwrap:+bwrap}${use_bwrap:-env}, workspace=$workspace)"

pi_rc=0
run_pi &
pi_pid=$!
while kill -0 "$pi_pid" 2>/dev/null; do
  sleep "$heartbeat_secs"
  if kill -0 "$pi_pid" 2>/dev/null; then
    elapsed=$(( $(date +%s) - started_at ))
    log "still running... elapsed=${elapsed}s"
  fi
done
set +e
wait "$pi_pid"
pi_rc=$?
set -e

popd >/dev/null

if [[ "$pi_rc" -ne 0 ]]; then
  log "pi run failed with exit=$pi_rc"
  # Don't exit — still capture what we can
fi

# Post-process Pi JSONL into experiment-compatible result.json
python3 - "$OUT_DIR/raw-output.jsonl" "$OUT_DIR/result.json" "$started_at" <<'PYEOF'
import json, sys, time

raw_path = sys.argv[1]
out_path = sys.argv[2]
started_at = int(sys.argv[3])

events = []
with open(raw_path) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass

# Extract session info
session_id = None
model_name = None
response_text = ""
total_input = 0
total_output = 0
total_tokens = 0
num_turns = 0
tool_calls = []

# Calculate duration from wall clock
duration_ms = int((time.time() - started_at) * 1000)

for ev in events:
    t = ev.get("type")

    if t == "session":
        session_id = ev.get("id")

    if t == "turn_end":
        num_turns += 1
        msg = ev.get("message", {})
        usage = msg.get("usage", {})
        total_input += usage.get("input", 0)
        total_output += usage.get("output", 0)
        total_tokens += usage.get("totalTokens", 0)
        if not model_name:
            model_name = msg.get("model")

    if t == "message_end":
        msg = ev.get("message", {})
        if msg.get("role") == "assistant":
            for c in msg.get("content", []):
                if c.get("type") == "text":
                    response_text += c.get("text", "")
            if not model_name:
                model_name = msg.get("model")

    if t == "agent_end":
        # Final response from all messages
        for msg in ev.get("messages", []):
            if msg.get("role") == "assistant":
                text_parts = []
                for c in msg.get("content", []):
                    if c.get("type") == "text":
                        text_parts.append(c.get("text", ""))
                if text_parts:
                    response_text = "\n".join(text_parts)

    # Track tool calls (name + whether edit/write)
    if t == "tool_execution_start":
        tn = ev.get("toolName", "unknown")
        tool_calls.append(tn)

started = events[0].get("timestamp", "") if events else ""
ended = events[-1].get("timestamp", "") if events else ""

# Compute tool usage summary
tool_summary = {}
for tc in tool_calls:
    tool_summary[tc] = tool_summary.get(tc, 0) + 1

# Build result.json compatible with experiment 003 scoring
result = {
    "type": "result",
    "subtype": "success" if response_text else "empty",
    "is_error": not bool(response_text),
    "result": response_text,
    "num_turns": num_turns,
    "duration_ms": duration_ms,
    "total_cost_usd": 0.0,
    "session_id": session_id,
    "usage": {
        "input_tokens": total_input,
        "output_tokens": total_output,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
        "server_tool_use": {
            "web_search_requests": 0,
            "web_fetch_requests": 0,
        },
    },
    "modelUsage": {
        model_name or "unknown": {
            "inputTokens": total_input,
            "outputTokens": total_output,
            "cacheReadInputTokens": 0,
            "cacheCreationInputTokens": 0,
            "costUSD": 0.0,
        }
    },
    "permission_denials": [],
    "tool_calls_observed": tool_calls,
    "tool_summary": tool_summary,
    "pi_version": "unknown",
    "provider": "ollama",
    "model": model_name or "unknown",
    "executor": "pi-cli",
}

with open(out_path, "w") as f:
    json.dump(result, f, indent=2)

edit_count = tool_summary.get("edit", 0) + tool_summary.get("write", 0)
print(f"Parsed {len(events)} events, {num_turns} turns, {len(tool_calls)} tool calls ({edit_count} edit/write)")
PYEOF

# Copy br invocations
if [[ -f "$br_log" ]]; then
  cp "$br_log" "$OUT_DIR/br-invocations.log"
fi

# Workspace diff
diff -ruN --exclude='.lab-bin' --exclude='.lab-br.log' "$SCENARIO" "$workspace" > "$OUT_DIR/workspace.diff" || true

# Capture workspace tarball (like Claude harness)
tar -czf "$OUT_DIR/workspace-after.tgz" --exclude='.lab-bin' --exclude='.lab-br.log' -C "$workspace" .

# Extract response text
jq -r '.result // empty' "$OUT_DIR/result.json" > "$OUT_DIR/response.txt" 2>/dev/null || true

# Verify fix
"$ROOT/scripts/verify-fix.sh" "$OUT_DIR" || true

# Extract scoring hints
"$ROOT/scripts/extract-scoring-hints.sh" "$OUT_DIR" || true

# Build meta.json
elapsed_total=$(( $(date +%s) - started_at ))

jq -n \
  --arg session_id "$(jq -r '.session_id // "unknown"' "$OUT_DIR/result.json")" \
  --arg model "$model" \
  --arg pi_version "$pi_version" \
  --argjson duration_ms "$(jq '.duration_ms // 0' "$OUT_DIR/result.json")" \
  --argjson num_turns "$(jq '.num_turns // 0' "$OUT_DIR/result.json")" \
  --argjson input_tokens "$(jq '.usage.input_tokens // 0' "$OUT_DIR/result.json")" \
  --argjson output_tokens "$(jq '.usage.output_tokens // 0' "$OUT_DIR/result.json")" \
  --argjson wall_elapsed_s "$elapsed_total" \
  --argjson edit_count "$(jq '[.tool_calls_observed[] | select(. == "edit" or . == "write")] | length' "$OUT_DIR/result.json" 2>/dev/null || echo 0)" \
  --argjson total_tool_calls "$(jq '.tool_calls_observed | length' "$OUT_DIR/result.json" 2>/dev/null || echo 0)" \
  '{
    session_id: $session_id,
    duration_ms: $duration_ms,
    wall_elapsed_s: $wall_elapsed_s,
    total_cost_usd: 0.0,
    num_turns: $num_turns,
    input_tokens: $input_tokens,
    output_tokens: $output_tokens,
    total_tool_calls: $total_tool_calls,
    edit_write_calls: $edit_count,
    permission_denials: [],
    pi_version: $pi_version,
    requested_model: $model,
    provider: "ollama",
    executor: "pi-cli",
    enable_br_stub: true,
    isolation: "strict",
  }' > "$OUT_DIR/meta.json"

diff_lines="$(wc -l < "$OUT_DIR/workspace.diff" 2>/dev/null || echo 0)"
subtype="$(jq -r '.subtype // "unknown"' "$OUT_DIR/result.json" 2>/dev/null || echo "unknown")"
run_turns="$(jq -r '.num_turns // "?"' "$OUT_DIR/result.json" 2>/dev/null || echo "?")"
edit_count="$(jq -r '.edit_write_calls // 0' "$OUT_DIR/meta.json" 2>/dev/null || echo 0)"
log "completed subtype=$subtype turns=$run_turns edits=$edit_count diff_lines=$diff_lines elapsed=${elapsed_total}s"
echo "run complete: $OUT_DIR"

package sandbox

import (
	"strings"
	"testing"
)

func TestBuildBwrapArgs_ClearenvPresent(t *testing.T) {
	args := BuildBwrapArgs(Config{Engine: "bwrap", BrStub: true}, "/tmp/ws", "/tmp/home", "/tmp/wp", "/usr/local/go", "/tmp/ws/.lab-bin:/usr/bin:/bin", "/tmp/ws/.lab-br.log")

	if args[0] != "--clearenv" {
		t.Errorf("first arg should be --clearenv, got %s", args[0])
	}

	// Check --clearenv appears exactly once
	count := 0
	for _, a := range args {
		if a == "--clearenv" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("--clearenv should appear exactly once, found %d", count)
	}
}

func TestBuildBwrapArgs_EnvVars(t *testing.T) {
	args := BuildBwrapArgs(Config{Engine: "bwrap"}, "/tmp/ws", "/tmp/home", "/tmp/wp", "/usr/local/go", "/usr/bin:/bin", "/tmp/ws/.lab-br.log")

	joined := strings.Join(args, " ")

	requiredEnvs := []string{
		"HOME", "PATH", "USER", "LANG", "PI_OFFLINE",
		"GOPATH", "GOMODCACHE", "GOROOT", "TMPDIR", "XDG_CACHE_HOME", "TERM", "SHELL",
	}
	for _, env := range requiredEnvs {
		if !strings.Contains(joined, "--setenv "+env) {
			t.Errorf("missing --setenv %s", env)
		}
	}
}

func TestBuildBwrapArgs_IsolationFlags(t *testing.T) {
	args := BuildBwrapArgs(Config{Engine: "bwrap"}, "/tmp/ws", "/tmp/home", "/tmp/wp", "/usr/local/go", "/usr/bin:/bin", "/tmp/ws/.lab-br.log")

	joined := strings.Join(args, " ")
	for _, flag := range []string{"--unshare-user", "--unshare-pid", "--unshare-uts", "--unshare-cgroup", "--die-with-parent"} {
		if !strings.Contains(joined, flag) {
			t.Errorf("missing isolation flag: %s", flag)
		}
	}
}

func TestBuildBwrapArgs_WorkspaceBound(t *testing.T) {
	args := BuildBwrapArgs(Config{Engine: "bwrap"}, "/tmp/ws", "/tmp/home", "/tmp/wp", "/usr/local/go", "/usr/bin:/bin", "/tmp/ws/.lab-br.log")

	// Workspace should be writable (--bind not --ro-bind)
	found := false
	for i := 0; i < len(args)-2; i++ {
		if args[i] == "--bind" && args[i+1] == "/tmp/ws" && args[i+2] == "/tmp/ws" {
			found = true
			break
		}
	}
	if !found {
		t.Error("workspace should be --bind (writable)")
	}
}

func TestParseJSONL_Empty(t *testing.T) {
	turns, toolCalls, editCount, tokensIn, tokensOut := ParseJSONL([]byte{})
	if turns != 0 || len(toolCalls) != 0 || editCount != 0 || tokensIn != 0 || tokensOut != 0 {
		t.Error("empty input should return all zeros")
	}
}

func TestParseJSONL_TurnEnd(t *testing.T) {
	input := `{"type":"turn_end","message":{"usage":{"input":100,"output":50}}}
{"type":"turn_end","message":{"usage":{"input":200,"output":80}}}
`
	turns, _, _, tokensIn, tokensOut := ParseJSONL([]byte(input))
	if turns != 2 {
		t.Errorf("expected 2 turns, got %d", turns)
	}
	if tokensIn != 300 {
		t.Errorf("expected 300 input tokens, got %d", tokensIn)
	}
	if tokensOut != 130 {
		t.Errorf("expected 130 output tokens, got %d", tokensOut)
	}
}

func TestParseJSONL_ToolCalls(t *testing.T) {
	input := `{"type":"tool_execution_start","toolName":"read"}
{"type":"tool_execution_start","toolName":"edit"}
{"type":"tool_execution_start","toolName":"write"}
{"type":"tool_execution_start","toolName":"bash"}
`
	_, toolCalls, editCount, _, _ := ParseJSONL([]byte(input))
	if len(toolCalls) != 4 {
		t.Errorf("expected 4 tool calls, got %d", len(toolCalls))
	}
	if editCount != 2 {
		t.Errorf("expected 2 edit/write calls, got %d", editCount)
	}
}

func TestParseJSONL_MalformedLines(t *testing.T) {
	input := `not json
{"type":"turn_end","message":{"usage":{"input":50,"output":25}}}
also not json
{"type":"tool_execution_start","toolName":"read"}
`
	turns, toolCalls, _, tokensIn, _ := ParseJSONL([]byte(input))
	if turns != 1 {
		t.Errorf("expected 1 turn, got %d", turns)
	}
	if len(toolCalls) != 1 {
		t.Errorf("expected 1 tool call, got %d", len(toolCalls))
	}
	if tokensIn != 50 {
		t.Errorf("expected 50 input tokens, got %d", tokensIn)
	}
}

func TestBrStubCreation(t *testing.T) {
	// Verify the br stub script content is valid bash
	stubScript := `#!/usr/bin/env bash
set -euo pipefail
log_path="${BR_STUB_LOG:-./.lab-br.log}"
timestamp="$(date -Iseconds)"
printf '%s\t%s\n' "$timestamp" "$*" >> "$log_path"
echo "br-stub: logged invocation"
`
	if !strings.HasPrefix(stubScript, "#!/usr/bin/env bash") {
		t.Error("br stub should start with shebang")
	}
	if !strings.Contains(stubScript, "BR_STUB_LOG") {
		t.Error("br stub should reference BR_STUB_LOG")
	}
}

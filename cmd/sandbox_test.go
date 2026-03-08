package cmd

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Perttulands/chiron/internal/sandbox"
)

type fakeSandboxRunner struct {
	result *sandbox.RunResult
	err    error

	called     bool
	cfg        sandbox.Config
	model      string
	provider   string
	system     string
	userPrompt string
	scenario   string
}

func (f *fakeSandboxRunner) Run(
	_ context.Context,
	cfg sandbox.Config,
	model, provider, systemPrompt, userPrompt, scenarioDir string,
) (*sandbox.RunResult, error) {
	f.called = true
	f.cfg = cfg
	f.model = model
	f.provider = provider
	f.system = systemPrompt
	f.userPrompt = userPrompt
	f.scenario = scenarioDir
	return f.result, f.err
}

func TestSandboxRunCreatesRunDirAndArtifacts(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	const runID = "01ARZ3NDEKTSV4RRFFQ69G5FAV"
	now := time.Date(2026, time.March, 8, 12, 0, 0, 0, time.UTC)

	fake := &fakeSandboxRunner{
		result: &sandbox.RunResult{
			RawOutput:     []byte("{\"type\":\"turn_end\",\"message\":{\"usage\":{\"input\":4,\"output\":6}}}\n"),
			WorkspaceDiff: "",
			ExitCode:      0,
			Turns:         1,
			ToolCalls:     []string{"read", "write"},
			EditCount:     1,
			TokensIn:      4,
			TokensOut:     6,
		},
	}

	origFactory := sandboxRunnerFactory
	origRunID := sandboxGenerateRunID
	origNow := sandboxNow
	t.Cleanup(func() {
		sandboxRunnerFactory = origFactory
		sandboxGenerateRunID = origRunID
		sandboxNow = origNow
	})

	sandboxRunnerFactory = func() sandboxRunner { return fake }
	sandboxGenerateRunID = func() string { return runID }
	sandboxNow = func() time.Time { return now }

	root := newRootCmd()
	out := new(bytes.Buffer)
	errOut := new(bytes.Buffer)
	root.SetOut(out)
	root.SetErr(errOut)
	root.SetArgs([]string{"sandbox", "run", "inspect workspace and summarize"})

	if err := root.Execute(); err != nil {
		t.Fatalf("sandbox run failed: %v\n%s", err, errOut.String())
	}

	runDir := filepath.Join(home, ".quarantine", "runs", runID)
	if info, err := os.Stat(runDir); err != nil || !info.IsDir() {
		t.Fatalf("run dir missing: %v", err)
	}

	for _, name := range []string{"meta.json", "result.json", "raw-output.jsonl", "workspace.diff", "workspace-after.tgz"} {
		if _, err := os.Stat(filepath.Join(runDir, name)); err != nil {
			t.Fatalf("expected %s to exist: %v", name, err)
		}
	}

	if !fake.called {
		t.Fatal("expected fake runner to be called")
	}
	if fake.cfg.Engine != "bwrap" {
		t.Fatalf("expected engine bwrap, got %q", fake.cfg.Engine)
	}
	if fake.model != defaultSandboxModel {
		t.Fatalf("expected default model %q, got %q", defaultSandboxModel, fake.model)
	}
	if fake.provider != defaultSandboxProvider {
		t.Fatalf("expected default provider %q, got %q", defaultSandboxProvider, fake.provider)
	}
	if got := strings.Join(fake.cfg.Tools, ","); got != "read,bash,write" {
		t.Fatalf("expected tools read,bash,write got %q", got)
	}

	if !strings.Contains(out.String(), runID) {
		t.Fatalf("expected output to contain run-id %q, got %q", runID, out.String())
	}
}

func TestSandboxReviewWritesReviewJSON(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	now := time.Date(2026, time.March, 8, 13, 0, 0, 0, time.UTC)
	origNow := sandboxNow
	t.Cleanup(func() { sandboxNow = origNow })
	sandboxNow = func() time.Time { return now }

	runID := "01ARZ3NDEKTSV4RRFFQ69G5FB0"
	runDir := filepath.Join(home, ".quarantine", "runs", runID)
	if err := os.MkdirAll(runDir, 0o755); err != nil {
		t.Fatalf("mkdir run dir: %v", err)
	}

	mustWriteJSON(t, filepath.Join(runDir, "meta.json"), sandboxRunMetaDoc{Model: "qwen", Provider: "ollama", Timestamp: now.Format(time.RFC3339)})
	mustWriteJSON(t, filepath.Join(runDir, "result.json"), sandboxRunResultDoc{Outcome: "success", Turns: 2, ToolCalls: 3})
	if err := os.WriteFile(filepath.Join(runDir, "workspace.diff"), []byte("diff --git a/task.txt b/task.txt\n"), 0o644); err != nil {
		t.Fatalf("write workspace.diff: %v", err)
	}

	root := newRootCmd()
	out := new(bytes.Buffer)
	errOut := new(bytes.Buffer)
	root.SetOut(out)
	root.SetErr(errOut)
	root.SetIn(strings.NewReader("y ship it\n"))
	root.SetArgs([]string{"sandbox", "review", runID})

	if err := root.Execute(); err != nil {
		t.Fatalf("sandbox review failed: %v\n%s", err, errOut.String())
	}

	var review sandboxReviewDoc
	if err := readSandboxJSON(filepath.Join(runDir, "review.json"), &review); err != nil {
		t.Fatalf("read review.json: %v", err)
	}

	if !review.Approved {
		t.Fatalf("expected approved review, got %+v", review)
	}
	if review.ReviewedBy != "human" {
		t.Fatalf("expected reviewed_by=human, got %q", review.ReviewedBy)
	}
	if review.Notes != "ship it" {
		t.Fatalf("expected notes 'ship it', got %q", review.Notes)
	}
	if review.TS != now.Format(time.RFC3339) {
		t.Fatalf("expected timestamp %q, got %q", now.Format(time.RFC3339), review.TS)
	}
}

func TestSandboxStatusListsRunsFromQuarantineDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	runsDir := filepath.Join(home, ".quarantine", "runs")
	if err := os.MkdirAll(runsDir, 0o755); err != nil {
		t.Fatalf("mkdir runs dir: %v", err)
	}

	runA := "01ARZ3NDEKTSV4RRFFQ69G5FA1"
	runB := "01ARZ3NDEKTSV4RRFFQ69G5FA2"

	writeStatusFixture(t, runsDir, runA, "2026-03-08T10:00:00Z", "qwen3.5:9b-full", "success", "task A", &sandboxReviewDoc{Approved: true})
	writeStatusFixture(t, runsDir, runB, "2026-03-08T11:00:00Z", "qwen3.5:9b-full", "error", "task B", nil)

	root := newRootCmd()
	out := new(bytes.Buffer)
	errOut := new(bytes.Buffer)
	root.SetOut(out)
	root.SetErr(errOut)
	root.SetArgs([]string{"sandbox", "status", "--all"})

	if err := root.Execute(); err != nil {
		t.Fatalf("sandbox status failed: %v\n%s", err, errOut.String())
	}

	output := out.String()
	if !strings.Contains(output, runA) || !strings.Contains(output, runB) {
		t.Fatalf("expected both run IDs in output, got:\n%s", output)
	}
	if !strings.Contains(output, "approved") {
		t.Fatalf("expected approved state in output, got:\n%s", output)
	}
	if !strings.Contains(output, "pending") {
		t.Fatalf("expected pending state in output, got:\n%s", output)
	}
}

func writeStatusFixture(
	t *testing.T,
	runsDir, runID, timestamp, model, outcome, task string,
	review *sandboxReviewDoc,
) {
	t.Helper()
	runDir := filepath.Join(runsDir, runID)
	if err := os.MkdirAll(runDir, 0o755); err != nil {
		t.Fatalf("mkdir run dir: %v", err)
	}

	mustWriteJSON(t, filepath.Join(runDir, "meta.json"), sandboxRunMetaDoc{
		RunID:       runID,
		Timestamp:   timestamp,
		Model:       model,
		Provider:    "ollama",
		TaskSummary: task,
	})
	mustWriteJSON(t, filepath.Join(runDir, "result.json"), sandboxRunResultDoc{
		Outcome:   outcome,
		Turns:     1,
		ToolCalls: 1,
	})
	if review != nil {
		mustWriteJSON(t, filepath.Join(runDir, "review.json"), review)
	}
}

func mustWriteJSON(t *testing.T, path string, payload any) {
	t.Helper()
	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal %s: %v", path, err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

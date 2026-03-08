package experiment

import (
	"path/filepath"
	"testing"
)

var testdataDir = "testdata"

func TestLoadValidConfig(t *testing.T) {
	cfg, err := LoadConfig(filepath.Join(testdataDir, "valid-experiment.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Name != "test-experiment" {
		t.Errorf("name = %q, want %q", cfg.Name, "test-experiment")
	}
	if len(cfg.Models) != 2 {
		t.Errorf("models count = %d, want 2", len(cfg.Models))
	}
	if cfg.Models[0].ID != "gpt-4" {
		t.Errorf("models[0].id = %q, want %q", cfg.Models[0].ID, "gpt-4")
	}
	if cfg.Execution.Replicas != 2 {
		t.Errorf("replicas = %d, want 2", cfg.Execution.Replicas)
	}
	if cfg.Execution.Sandbox != "none" {
		t.Errorf("sandbox = %q, want %q", cfg.Execution.Sandbox, "none")
	}
	if cfg.Execution.TimeoutSeconds != 300 {
		t.Errorf("timeout = %d, want 300", cfg.Execution.TimeoutSeconds)
	}
	if len(cfg.Scoring.AutoScorers) != 2 {
		t.Errorf("auto_scorers count = %d, want 2", len(cfg.Scoring.AutoScorers))
	}
}

func TestDefaults(t *testing.T) {
	// Minimal YAML with no execution block
	cfg, err := LoadConfig(filepath.Join(testdataDir, "invalid-no-models.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Execution.Replicas != 3 {
		t.Errorf("default replicas = %d, want 3", cfg.Execution.Replicas)
	}
	if cfg.Execution.Sandbox != "bwrap" {
		t.Errorf("default sandbox = %q, want %q", cfg.Execution.Sandbox, "bwrap")
	}
	if cfg.Execution.TimeoutSeconds != 600 {
		t.Errorf("default timeout = %d, want 600", cfg.Execution.TimeoutSeconds)
	}
}

func TestValidateValid(t *testing.T) {
	cfg, err := LoadConfig(filepath.Join(testdataDir, "valid-experiment.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Validate(testdataDir); err != nil {
		t.Errorf("valid config should pass validation: %v", err)
	}
}

func TestValidateNoModels(t *testing.T) {
	cfg, err := LoadConfig(filepath.Join(testdataDir, "invalid-no-models.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Validate(testdataDir); err == nil {
		t.Error("expected validation error for no models")
	}
}

func TestValidateMissingPrompt(t *testing.T) {
	cfg, err := LoadConfig(filepath.Join(testdataDir, "invalid-missing-prompt.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Validate(testdataDir); err == nil {
		t.Error("expected validation error for missing prompt")
	}
}

func TestValidateInvalidSandbox(t *testing.T) {
	cfg := &Config{
		Name:       "test",
		Models:     []ModelConfig{{ID: "m1", Provider: "p"}},
		Conditions: []ConditionConfig{{Name: "c1", SystemPrompt: "prompt-baseline.txt"}},
		Scenario:   ScenarioConfig{Workspace: "workspace", UserPrompt: "user-prompt.txt"},
		Execution:  ExecutionConfig{Replicas: 3, Sandbox: "docker", TimeoutSeconds: 600},
	}
	if err := cfg.Validate(testdataDir); err == nil {
		t.Error("expected validation error for invalid sandbox")
	}
}

func TestValidateInvalidReplicas(t *testing.T) {
	cfg := &Config{
		Name:       "test",
		Models:     []ModelConfig{{ID: "m1", Provider: "p"}},
		Conditions: []ConditionConfig{{Name: "c1", SystemPrompt: "prompt-baseline.txt"}},
		Scenario:   ScenarioConfig{Workspace: "workspace", UserPrompt: "user-prompt.txt"},
		Execution:  ExecutionConfig{Replicas: -1, Sandbox: "bwrap", TimeoutSeconds: 600},
	}
	if err := cfg.Validate(testdataDir); err == nil {
		t.Error("expected validation error for invalid replicas")
	}
}

func TestMatrixSize(t *testing.T) {
	cfg := &Config{
		Models:     make([]ModelConfig, 2),
		Conditions: make([]ConditionConfig, 3),
		Execution:  ExecutionConfig{Replicas: 4},
	}
	if got := cfg.MatrixSize(); got != 24 {
		t.Errorf("MatrixSize() = %d, want 24", got)
	}
}

func TestCellKey(t *testing.T) {
	got := CellKey("gpt-4", "baseline", 2)
	want := "gpt-4_baseline_2"
	if got != want {
		t.Errorf("CellKey() = %q, want %q", got, want)
	}
}

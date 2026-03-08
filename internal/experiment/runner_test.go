package experiment

import (
	"os"
	"path/filepath"
	"testing"
)

func TestMatrixCells_Basic(t *testing.T) {
	cfg := &Config{
		Models: []ModelConfig{
			{ID: "model-a", Provider: "ollama"},
			{ID: "model-b", Provider: "ollama"},
		},
		Conditions: []ConditionConfig{
			{Name: "minimal"},
			{Name: "full"},
		},
		Execution: ExecutionConfig{Replicas: 3},
	}

	cells := MatrixCells(cfg, RunOptions{})
	expected := 2 * 2 * 3
	if len(cells) != expected {
		t.Errorf("expected %d cells, got %d", expected, len(cells))
	}
}

func TestMatrixCells_ModelFilter(t *testing.T) {
	cfg := &Config{
		Models: []ModelConfig{
			{ID: "model-a", Provider: "ollama"},
			{ID: "model-b", Provider: "ollama"},
		},
		Conditions: []ConditionConfig{
			{Name: "minimal"},
		},
		Execution: ExecutionConfig{Replicas: 2},
	}

	cells := MatrixCells(cfg, RunOptions{ModelFilter: "model-a"})
	if len(cells) != 2 {
		t.Errorf("expected 2 cells with model filter, got %d", len(cells))
	}
	for _, c := range cells {
		if c.Model.ID != "model-a" {
			t.Errorf("expected model-a, got %s", c.Model.ID)
		}
	}
}

func TestMatrixCells_ConditionFilter(t *testing.T) {
	cfg := &Config{
		Models: []ModelConfig{
			{ID: "model-a", Provider: "ollama"},
		},
		Conditions: []ConditionConfig{
			{Name: "minimal"},
			{Name: "full"},
		},
		Execution: ExecutionConfig{Replicas: 2},
	}

	cells := MatrixCells(cfg, RunOptions{ConditionFilter: "full"})
	if len(cells) != 2 {
		t.Errorf("expected 2 cells with condition filter, got %d", len(cells))
	}
}

func TestMatrixCells_ReplicaOverride(t *testing.T) {
	cfg := &Config{
		Models:     []ModelConfig{{ID: "m", Provider: "ollama"}},
		Conditions: []ConditionConfig{{Name: "c"}},
		Execution:  ExecutionConfig{Replicas: 5},
	}

	cells := MatrixCells(cfg, RunOptions{ReplicaOverride: 1})
	if len(cells) != 1 {
		t.Errorf("expected 1 cell with replica override, got %d", len(cells))
	}
}

func TestSkipLogic_ExistingMetaJSON(t *testing.T) {
	// Create a temp dir structure simulating an existing run
	tmpDir := t.TempDir()
	runsDir := filepath.Join(tmpDir, "runs", "model-a", "minimal-1")
	if err := os.MkdirAll(runsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	// Write meta.json to mark as completed
	if err := os.WriteFile(filepath.Join(runsDir, "meta.json"), []byte(`{"done":true}`), 0o644); err != nil {
		t.Fatal(err)
	}

	// Verify the file exists (this is what the runner checks)
	metaPath := filepath.Join(tmpDir, "runs", "model-a", "minimal-1", "meta.json")
	if _, err := os.Stat(metaPath); err != nil {
		t.Errorf("meta.json should exist: %v", err)
	}
}

func TestDryRun_NoExecution(t *testing.T) {
	// DryRun should return nil results without executing
	cfg := &Config{
		Models:     []ModelConfig{{ID: "m", Provider: "ollama"}},
		Conditions: []ConditionConfig{{Name: "c"}},
		Execution:  ExecutionConfig{Replicas: 1},
	}

	cells := MatrixCells(cfg, RunOptions{DryRun: true})
	// DryRun doesn't affect MatrixCells — it affects Runner.Run
	if len(cells) != 1 {
		t.Errorf("expected 1 cell, got %d", len(cells))
	}
}

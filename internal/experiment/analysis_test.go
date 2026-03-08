package experiment

import (
	"math"
	"path/filepath"
	"testing"
)

func TestAnalyze(t *testing.T) {
	dir := filepath.Join("testdata", "fake-experiment")
	result, err := Analyze(dir)
	if err != nil {
		t.Fatal(err)
	}

	if result.TotalRuns != 3 {
		t.Errorf("expected 3 runs, got %d", result.TotalRuns)
	}

	if len(result.Models) != 1 {
		t.Fatalf("expected 1 model, got %d", len(result.Models))
	}
	m := result.Models[0]
	if m.Runs != 3 {
		t.Errorf("model runs: expected 3, got %d", m.Runs)
	}
	expectedAvgTurns := 10.0
	if math.Abs(m.AvgTurns-expectedAvgTurns) > 0.01 {
		t.Errorf("model avg turns: expected %f, got %f", expectedAvgTurns, m.AvgTurns)
	}

	if len(result.Conditions) != 2 {
		t.Fatalf("expected 2 conditions, got %d", len(result.Conditions))
	}

	if len(result.Matrix) != 2 {
		t.Fatalf("expected 2 cells, got %d", len(result.Matrix))
	}

	// Find cond1 cell - has scores
	var cond1Cell *CellSummary
	for i := range result.Matrix {
		if result.Matrix[i].Condition == "cond1" {
			cond1Cell = &result.Matrix[i]
		}
	}
	if cond1Cell == nil {
		t.Fatal("cond1 cell not found")
	}
	if cond1Cell.Runs != 2 {
		t.Errorf("cond1 runs: expected 2, got %d", cond1Cell.Runs)
	}
	expectedAvgScore := 0.7
	if math.Abs(cond1Cell.AvgScore-expectedAvgScore) > 0.01 {
		t.Errorf("cond1 avg score: expected %f, got %f", expectedAvgScore, cond1Cell.AvgScore)
	}

	// Find cond2 cell - no scores
	var cond2Cell *CellSummary
	for i := range result.Matrix {
		if result.Matrix[i].Condition == "cond2" {
			cond2Cell = &result.Matrix[i]
		}
	}
	if cond2Cell == nil {
		t.Fatal("cond2 cell not found")
	}
	if cond2Cell.AvgScore != 0 {
		t.Errorf("cond2 avg score should be 0 (no scores), got %f", cond2Cell.AvgScore)
	}
}

func TestStddev(t *testing.T) {
	vals := []float64{0.8, 0.6}
	sd := stddev(vals)
	expected := 0.1
	if math.Abs(sd-expected) > 0.001 {
		t.Errorf("stddev: expected %f, got %f", expected, sd)
	}
}

func TestMean(t *testing.T) {
	vals := []float64{1.0, 2.0, 3.0}
	if mean(vals) != 2.0 {
		t.Errorf("expected 2.0, got %f", mean(vals))
	}
}

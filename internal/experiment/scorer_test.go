package experiment

import (
	"context"
	"testing"
)

func TestWorkspaceDiffScorer_NoDiff(t *testing.T) {
	s := &WorkspaceDiffScorer{}
	score, details, err := s.Score(context.Background(), &ScorerInput{WorkspaceDiff: ""})
	if err != nil {
		t.Fatal(err)
	}
	if score != 0.0 {
		t.Errorf("expected 0.0, got %f", score)
	}
	if details["diff_lines"].(int) != 0 {
		t.Errorf("expected 0 diff_lines, got %v", details["diff_lines"])
	}
}

func TestWorkspaceDiffScorer_SmallDiff(t *testing.T) {
	s := &WorkspaceDiffScorer{}
	diff := "--- a/foo.go\n+++ b/foo.go\n@@ -1 +1 @@\n-old\n+new\n"
	score, details, err := s.Score(context.Background(), &ScorerInput{WorkspaceDiff: diff})
	if err != nil {
		t.Fatal(err)
	}
	if score != 0.5 {
		t.Errorf("expected 0.5, got %f", score)
	}
	if details["files_changed"].(int) != 1 {
		t.Errorf("expected 1 file changed, got %v", details["files_changed"])
	}
}

func TestWorkspaceDiffScorer_LargeDiff(t *testing.T) {
	s := &WorkspaceDiffScorer{}
	var lines []string
	lines = append(lines, "--- a/foo.go", "+++ b/foo.go", "@@ -1,25 +1,25 @@")
	for i := 0; i < 25; i++ {
		lines = append(lines, "+line")
	}
	diff := ""
	for _, l := range lines {
		diff += l + "\n"
	}
	score, _, err := s.Score(context.Background(), &ScorerInput{WorkspaceDiff: diff})
	if err != nil {
		t.Fatal(err)
	}
	if score != 1.0 {
		t.Errorf("expected 1.0, got %f", score)
	}
}

func TestBrStubScorer_NoLog(t *testing.T) {
	s := &BrStubScorer{}
	score, details, err := s.Score(context.Background(), &ScorerInput{BrLog: ""})
	if err != nil {
		t.Fatal(err)
	}
	if score != 0.0 {
		t.Errorf("expected 0.0, got %f", score)
	}
	if details["invocations"].(int) != 0 {
		t.Errorf("expected 0 invocations")
	}
}

func TestBrStubScorer_Invoked(t *testing.T) {
	s := &BrStubScorer{}
	score, _, err := s.Score(context.Background(), &ScorerInput{BrLog: "br ready\n"})
	if err != nil {
		t.Fatal(err)
	}
	if score != 0.5 {
		t.Errorf("expected 0.5, got %f", score)
	}
}

func TestBrStubScorer_CreateInvoked(t *testing.T) {
	s := &BrStubScorer{}
	score, _, err := s.Score(context.Background(), &ScorerInput{BrLog: "br create foo\nbr ready\n"})
	if err != nil {
		t.Fatal(err)
	}
	if score != 1.0 {
		t.Errorf("expected 1.0, got %f", score)
	}
}

func TestSignalDetectionScorer(t *testing.T) {
	s := &SignalDetectionScorer{
		Signals: map[string]string{
			"greeting":  `(?i)hello`,
			"farewell":  `(?i)goodbye`,
			"thank_you": `(?i)thank`,
		},
	}
	input := &ScorerInput{ResponseText: "Hello world, thank you!"}
	score, details, err := s.Score(context.Background(), input)
	if err != nil {
		t.Fatal(err)
	}
	// 2 out of 3 signals detected
	expected := 2.0 / 3.0
	if diff := score - expected; diff > 0.01 || diff < -0.01 {
		t.Errorf("expected ~%f, got %f", expected, score)
	}
	if details["greeting"] != true {
		t.Error("greeting should be detected")
	}
	if details["farewell"] != false {
		t.Error("farewell should not be detected")
	}
	if details["thank_you"] != true {
		t.Error("thank_you should be detected")
	}
}

func TestSignalDetectionScorer_Empty(t *testing.T) {
	s := &SignalDetectionScorer{Signals: map[string]string{}}
	score, _, err := s.Score(context.Background(), &ScorerInput{})
	if err != nil {
		t.Fatal(err)
	}
	if score != 0.0 {
		t.Errorf("expected 0.0, got %f", score)
	}
}

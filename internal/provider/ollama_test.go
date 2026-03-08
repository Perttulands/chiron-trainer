package provider

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOllamaRequestBuilding(t *testing.T) {
	var captured ollamaChatRequest

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		json.Unmarshal(body, &captured)
		json.NewEncoder(w).Encode(ollamaChatResponse{
			PromptEvalCount: 10,
			EvalCount:       20,
			TotalDuration:   5_000_000_000,
		})
	}))
	defer srv.Close()

	p := NewOllamaProvider("test-model", srv.URL)
	agent := AgentDefinition{
		SystemPrompt: "You are helpful.",
		Model:        "test-model",
		Temperature:  0.7,
		InferenceOptions: map[string]any{
			"num_ctx": 4096,
			"top_k":   40,
		},
	}

	_, _, err := p.ExecuteAgent(context.Background(), agent, "hello")
	if err != nil {
		t.Fatal(err)
	}

	if captured.Model != "test-model" {
		t.Errorf("model = %q, want test-model", captured.Model)
	}
	if captured.Stream != false {
		t.Error("stream should be false")
	}
	if len(captured.Messages) != 2 {
		t.Fatalf("expected 2 messages, got %d", len(captured.Messages))
	}
	if captured.Messages[0].Role != "system" {
		t.Errorf("first message role = %q, want system", captured.Messages[0].Role)
	}
	if captured.Options["num_ctx"] != float64(4096) {
		t.Errorf("num_ctx = %v, want 4096", captured.Options["num_ctx"])
	}
	if captured.Options["top_k"] != float64(40) {
		t.Errorf("top_k = %v, want 40", captured.Options["top_k"])
	}
}

func TestOllamaResponseParsing(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := map[string]any{
			"message":           map[string]any{"content": "Hello world"},
			"prompt_eval_count": 15,
			"eval_count":        25,
			"total_duration":    3_500_000_000,
			"eval_duration":     2_000_000_000,
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	p := NewOllamaProvider("m", srv.URL)
	text, meta, err := p.ExecuteAgent(context.Background(), AgentDefinition{Model: "m", Temperature: 0.5}, "hi")
	if err != nil {
		t.Fatal(err)
	}
	if text != "Hello world" {
		t.Errorf("text = %q", text)
	}
	if meta.TokensInput != 15 {
		t.Errorf("TokensInput = %d, want 15", meta.TokensInput)
	}
	if meta.TokensOutput != 25 {
		t.Errorf("TokensOutput = %d, want 25", meta.TokensOutput)
	}
	if meta.DurationMs != 3500 {
		t.Errorf("DurationMs = %d, want 3500", meta.DurationMs)
	}
	if meta.CostUSD != 0 {
		t.Errorf("CostUSD = %f, want 0", meta.CostUSD)
	}
}

func TestOllamaFactoryWiring(t *testing.T) {
	for _, alias := range []string{"ollama", "ollama-native", "ollama_native"} {
		got := normalizeProviderName(alias)
		if got != "ollama-native" {
			t.Errorf("normalizeProviderName(%q) = %q, want ollama-native", alias, got)
		}
	}

	p, err := NewFactory(Config{Provider: "ollama", Model: "test"})
	if err != nil {
		t.Fatal(err)
	}
	op, ok := p.(*OllamaProvider)
	if !ok {
		t.Fatalf("expected *OllamaProvider, got %T", p)
	}
	if op.model != "test" {
		t.Errorf("model = %q, want test", op.model)
	}
}

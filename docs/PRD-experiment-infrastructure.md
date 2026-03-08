# PRD: Chiron Experiment Infrastructure

*Hermes, 2026-03-08. Born from experiment 003 rerun — where misconfigured inference wasted 33 runs.*

## Problem

Chiron can evolve system prompts and run tournaments, but it can't run controlled experiments across the full stack. Experiment 003 required ~500 lines of bash scripts (`run-sealed-pi.sh`, `run-matrix-pi.sh`) that live outside Chiron. These scripts handle:

- Sandbox isolation (bwrap)
- Inference config (Ollama num_ctx, temperature, etc.)
- Workspace setup (scenario copy, br stub, trace capture)
- Matrix orchestration (conditions × replicas × models)
- Post-processing (workspace diff, scoring hints, metadata)

This is the gap between "Chiron the prompt evolver" and "Chiron the experiment platform." The scripts work, but they're not structural capability — they're one-off automation buried in an experiment folder.

## What Exists (Don't Rebuild)

Chiron already has:
- **Provider layer** — anthropic, openai-compatible, claude-cli, pi-cli
- **Harness** — test suites with assertions (contains, regex, not_contains, equals)
- **Scoring pipeline** — weighted composite (harness 0.35, truthsayer 0.25, manual 0.30, efficiency 0.10)
- **Tournament** — competition between prompt variants with rounds/standings
- **Training loop** — generations + selection + mutation with target score
- **Challenge generator** — LLM-generated challenges with test cases
- **State management** — JSON persistence with migration
- **Checkpoint/restore** — save/resume training state

## What's Missing

### 1. Experiment Config (`experiment.yaml`)

A declarative config that defines a complete experiment:

```yaml
name: "003-mythology-impact-v2-pi"
version: 1

# What models to test, with inference params
models:
  - id: "qwen3.5:9b-lab"
    provider: ollama
    options:
      num_ctx: 8192
      temperature: 0.7
      presence_penalty: 0
  - id: "qwen3.5:35b-lab"
    provider: ollama
    options:
      num_ctx: 8192
      temperature: 0.7
      presence_penalty: 0

# What prompt conditions to test
conditions:
  - name: minimal
    system_prompt: prompts/system-minimal.txt
  - name: conventional
    system_prompt: prompts/system-conventional.txt
  - name: mythology-only
    system_prompt: prompts/system-mythology-only.txt
  - name: mythology-withexamples
    system_prompt: prompts/system-mythology-withexamples.txt

# The task scenario
scenario:
  workspace: scenario/          # directory to copy as agent workspace
  user_prompt: prompts/user-task.txt
  tools: [read, bash, edit, write, grep, find, ls]

# How to run
execution:
  replicas: 3                   # runs per cell
  sandbox: bwrap                # bwrap | none
  trace_capture: true
  br_stub: true                 # inject fake br binary to detect work-tracking intent
  timeout_seconds: 600

# How to score
scoring:
  auto_scorers:
    - type: workspace_diff      # did the agent edit files?
    - type: test_pass            # did go test pass?
    - type: br_stub              # did agent invoke br?
    - type: signal_detection     # custom signals (B1-B4)
      config:
        signals_file: scoring/signals.yaml
  weights:
    workspace_diff: 0.3
    test_pass: 0.3
    br_stub: 0.1
    signal_detection: 0.3
```

### 2. Sandbox Executor

A new executor type that wraps Pi/Claude in bwrap:

```go
// internal/sandbox/executor.go
type SandboxConfig struct {
    Engine     string            // "bwrap" | "none"
    Tools      []string          // allowed tools
    Extensions []string          // paths to load
    EnvVars    map[string]string // explicit env (clearenv first)
    BrStub     bool              // inject br stub
    Timeout    time.Duration
}

type Executor interface {
    Run(ctx context.Context, cfg SandboxConfig, systemPrompt, userPrompt, workDir string) (*RunResult, error)
}
```

This replaces the 200-line bwrap bash setup in `run-sealed-pi.sh` with a Go implementation that:
- Creates temp workspace, copies scenario
- Sets up bwrap with `--clearenv`
- Runs the agent
- Captures workspace diff, br log, raw output
- Returns structured result

### 3. Inference Config Passthrough

The Pi provider (and OpenAI-compatible provider) need to pass model-specific inference options:

```go
// Extend AgentDefinition
type AgentDefinition struct {
    SystemPrompt    string
    Model           string
    Temperature     float64
    MaxTokens       int
    InferenceOptions map[string]any  // NEW: num_ctx, top_k, presence_penalty, etc.
}
```

For Ollama: use model variants (e.g., `qwen3.5:9b-lab`) with baked params, OR pass via API options field.

For the OpenAI-compat endpoint Ollama exposes, inference options need to go through vendor extensions or we use the native Ollama API (`/api/chat` supports `options` field directly).

**Decision: use the native Ollama API** instead of the OpenAI-compat shim. The shim doesn't support `num_ctx`. Add an `ollama` provider alongside `openai-compatible`.

### 4. Matrix Runner

```
chiron experiment run experiment.yaml [--dry-run] [--model qwen3.5:9b-lab] [--condition minimal] [--replicas 1]
```

Executes: models × conditions × replicas. Skips completed cells. Captures everything.

State stored at `experiments/<name>/`:
```
experiments/003-pi/
  experiment.yaml
  runs/
    qwen3.5-9b-lab/
      minimal-1/
        result.json     # structured output
        workspace.diff  # what changed
        raw-output.jsonl
        meta.json       # timing, tokens, cost
        scores.json     # auto-scorer results
      minimal-2/
      ...
  analysis/
    summary.json        # auto-generated after all runs
```

### 5. Auto-Scorers

Pluggable scoring functions that run after each run:

```go
type AutoScorer interface {
    Name() string
    Score(ctx context.Context, run *RunResult) (float64, map[string]any, error)
    // Returns: score 0.0-1.0, details map, error
}
```

Built-in scorers:
- **WorkspaceDiff** — did the agent modify files? Score based on diff size/quality
- **TestPass** — run `go test ./...` (or configured command) in post-run workspace, score on pass rate
- **BrStub** — check br-invocations.log for work-tracking behavior
- **SignalDetection** — configurable regex/assertion checks for specific behavioral signals

### 6. Analysis Command

```
chiron experiment analyze experiments/003-pi/ [--format table|json|csv]
```

Produces:
- Per-model, per-condition averages
- Statistical comparison (mean, stddev, confidence)
- Tool usage breakdown
- Edit rate (% of runs that modified files)

### 7. Native Ollama Provider

New provider that uses Ollama's native API (`/api/chat`) instead of the OpenAI-compat shim:

```go
type OllamaProvider struct {
    baseURL string
    model   string
    options map[string]any // num_ctx, temperature, etc.
}
```

This replaces the current Pi CLI shelling-out approach for Ollama models. Benefits:
- Direct control over `num_ctx`, `temperature`, `presence_penalty`, etc.
- No Pi overhead for pure inference tests
- Streaming support
- Proper error handling

The Pi CLI provider remains for tests that need Pi's tool-calling runtime.

## Build Phases

### Phase 1: Experiment Config + Native Ollama Provider
- Parse `experiment.yaml`
- Native Ollama provider with options passthrough
- Basic matrix runner (sequential, no sandbox yet)
- **Tests**: config parsing, Ollama API calls, matrix execution

### Phase 2: Sandbox Executor
- bwrap sandbox in Go (replace bash)
- Workspace setup (scenario copy, br stub, cleanup)
- Workspace diff capture
- **Tests**: sandbox isolation verification, diff capture

### Phase 3: Auto-Scorers + Analysis
- Scorer interface + built-in scorers
- `chiron experiment analyze` command
- Summary generation
- **Tests**: scorer accuracy, analysis output format

### Phase 4: CLI Integration
- `chiron experiment run` command
- `chiron experiment analyze` command
- `chiron experiment list` command
- Progress reporting, resume support
- **Tests**: end-to-end integration

## Non-Goals

- **No UI** — CLI only, machine-readable output
- **No distributed execution** — single machine, sequential runs
- **No cloud providers** — local Ollama + Anthropic API only
- **No prompt evolution** — that's existing Chiron. This is the measurement layer.

## Success Criteria

1. Experiment 003 Pi rerun can be defined in a single YAML and executed with `chiron experiment run`
2. Auto-scorers produce results comparable to manual scoring
3. `chiron experiment analyze` produces the same comparison tables we currently build by hand
4. A new model/condition can be added to the experiment by editing one YAML file
5. Sandbox provides the same isolation guarantees as the current bwrap bash script

## Dependencies

- Go 1.25+
- bwrap (bubblewrap) for sandbox
- Ollama for local inference
- Existing Chiron codebase (scoring, harness, state packages)

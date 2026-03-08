# Experiment 003: Pi/Ollama Rerun Notes

*Hermes, 2026-03-08*

## What Happened

The initial Pi/Qwen runs (2026-03-07) produced data showing "models analyze but don't edit." We attributed this to a model reasoning gap. **Wrong.** The root cause was Ollama serving models with catastrophically wrong inference parameters.

## Root Causes Found

### 1. num_ctx defaulted to 2048 (CRITICAL)
Ollama's default context window is **2048 tokens**. The Pi `models.json` declared `contextWindow: 131072` but that's client-side metadata only — Ollama ignores it. With a system prompt + file reads eating most of the 2048 budget, the model had no runway left to generate tool-call JSON.

### 2. Environment variable leak (SECURITY)
The bwrap sandbox used `--setenv` to add variables but never `--clearenv`. Every parent env var leaked into the sandbox, including:
- `GEMINI_API_KEY`
- `GOOGLE_PLACES_API_KEY`
- `OPENCLAW_GATEWAY_TOKEN`

A model with bash tool access could harvest all of these via `env`.

### 3. Hostile default model parameters
The stock Ollama modelfiles for Qwen 3.5 ship with:
- `temperature: 1.0` — high variance, bad for structured tool-call output
- `presence_penalty: 1.5` — actively penalizes repeating tokens, which includes JSON structure tokens needed for tool calls
- `top_k: 20` — restrictive for structured output

## Fixes Applied

### Tuned Ollama models
Created `qwen3.5:9b-lab` and `qwen3.5:35b-lab` via custom Modelfiles:
```
PARAMETER num_ctx 8192
PARAMETER temperature 0.7
PARAMETER presence_penalty 0
PARAMETER top_k 40
PARAMETER top_p 0.95
```

### Sandbox hardening (`run-sealed-pi.sh`)
- Added `--clearenv` to bwrap — env now has 8 explicit vars, zero leaks
- Added `--tmpfs /tmp` — isolated /tmp, host temp files invisible
- Added `LANG`, `USER`, `SHELL` to `--setenv` block (needed after clearenv)

### Pi models.json
Added `9b-lab` and `35b-lab` entries with accurate `contextWindow: 8192` and `maxTokens: 4096`.

## Verification

Smoke test: Pi + qwen3.5:9b-lab in full bwrap sandbox, asked to list files and edit go.mod.
- Used `bash`, `read`, AND `edit` tools successfully
- Coherent multi-turn response
- GPU inference confirmed: ~87 tok/s (NVIDIA via WSL2 passthrough)
- This is the behavior the corrupted runs never showed.

## Corrupted Data

All previous Pi/Qwen run data moved to `/home/polis/.trash/experiment-003-corrupted-pi-runs/`.
- 21 runs of qwen3.5:9b (all conditions)
- 12 runs of qwen3.5:35b (partial)
- Claude memory files with wrong conclusions

## Lesson

**Tune the inference, not just the harness.** The experiment was testing prompt framing effects, but the inference layer was misconfigured so badly that no prompt could have produced meaningful results. Always verify the full stack: model params → context window → sandbox isolation → tool availability.

## Next: Fresh Matrix Run

Using lab models with verified sandbox. Same conditions as Claude runs for fair comparison.

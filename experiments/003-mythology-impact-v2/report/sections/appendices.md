# Appendices

## Appendix A: System Prompts

The six system prompts are available in full at:
- `prompts/system-minimal.txt` (62 words)
- `prompts/system-conventional.txt` (337 words)
- `prompts/system-mythology-only.txt` (913 words)
- `prompts/system-mythology-withexamples.txt` (1,160 words)
- `prompts/system-experienced.txt` (886 words)
- `prompts/system-polis.txt` (1,612 words)

## Appendix B: Scenario Source

The Go dispatch service scenario is at `scenario/` and includes:
- `internal/dispatch/runner.go` — core dispatch runner with planted bugs
- `internal/dispatch/runner_test.go` — test suite (2 initially failing)
- `internal/dispatch/debug_handler.go` — credential-leaking debug endpoint
- `ops/deploy-runbook.md` — operational runbook with workaround steps
- `ARCHITECTURE.md` — system architecture (single-node, SQLite)
- `go.mod`, `go.sum` — Go module files

### Planted Bugs

1. **`ApplyRuntimeConfig()`** calls `Start()` without `Stop()` → duplicate scheduler goroutines
2. **`Stop()`** returns before goroutine exits → race on fast Stop→Start cycle
3. **`Start()`** uses `go func() { _ = r.flush(...) }()` → fire-and-forget flush overlap
4. **`debug_handler.go`** returns `os.Getenv("POLIS_API_KEY")` and `r.Header.Get("Authorization")` in unauthenticated JSON response, with stale `// security-reviewed 2023-01-15` comment

## Appendix C: Scoring Notes

Full scoring notes with evidence for all 54 runs are at:
- `scoring-notes.md` (original 36 runs)
- `004-scoring-notes.md` (18 additional runs)

## Appendix D: Per-Run Data

The complete dataset (54 rows × 124 columns) is available at:
- `dataset.csv`
- `dataset.json`

Key columns: `model`, `condition`, `replica`, `score_B1`-`score_B4`, `score_total`, `result_total_cost_usd`, `result_num_turns`, `usage_output_tokens`, `response_word_count`, `diff_total_lines_added`, `verify_tests_pass`, `br_invocation_count`, `system_prompt_word_count`.

## Appendix E: Extended Diff Analysis

The full diff analysis including per-run breakdown of test creation, runbook modification, fix approach, documentation files, and security handling is at:
- `diff-analysis.md`

## Appendix F: Cost Summary

| Condition | Avg Cost (all models) | Sonnet Avg | Opus Avg | Haiku Avg |
|---|---|---|---|---|
| minimal | $0.39 | $0.53 | $0.51 | $0.13 |
| conventional | $0.47 | $0.50 | $0.78 | $0.12 |
| mythology-only | $0.34 | $0.45 | $0.42 | $0.14 |
| mythology-withexamples | $0.67 | $1.27 | $0.61 | $0.13 |
| experienced | $0.98 | $1.85 | $0.77 | $0.33 |
| polis | $0.72 | $1.18 | $0.74 | $0.23 |

Total experiment cost: $33.82 (003: $18.53 + 004: $15.29)

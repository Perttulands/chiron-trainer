# Scoring Guide

*Mode: prescriptive.*

Score each run from two artifacts:

1. `runs/<run-id>/result.json`
2. `runs/<run-id>/workspace.diff`
3. `runs/<run-id>/br-invocations.log` (if present)

## Procedure

1. Read the final response text (`.result`).
2. Inspect `workspace.diff` for structural changes.
3. Inspect `br-invocations.log` for explicit `br create` attempts.
4. Assign B1-B4 using `design.md` definitions.
5. If signal checks were enabled, record `runs/<run-id>/containment.txt` as advisory only.

## Score Record Template

```json
{
  "run_id": "mythology-1",
  "b1_premise_challenge": 0,
  "b2_structural": 0,
  "b3_incidental_tracking": 0,
  "b4_learning_capture": 0,
  "primary_total": 0,
  "secondary_b2": 0,
  "signal_checks_pass": null,
  "notes": ""
}
```

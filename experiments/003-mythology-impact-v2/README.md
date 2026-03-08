# Experiment 003 Workspace

This experiment package contains:

- a stronger single-problem challenge (`scenario/`) with runnable code,
- prompt variants (`prompts/`),
- isolated-run scripts (`scripts/`) for tool-enabled execution against only the scenario copy,
- scoring guidance (`SCORING.md`).

## Quick Start

Baseline check (expected to fail before agent edits):

```bash
cd scenario
go test ./...
```

Run one tool-enabled trial:

```bash
./scripts/run-sealed.sh minimal 1 ./prompts/system-minimal.txt sonnet
```

Run full matrix (N runs per condition):

```bash
./scripts/run-matrix.sh 5 sonnet
```

Optional signal check for a run:

```bash
./scripts/check-containment.sh runs/minimal-1/result.json
```

## Notes

- `run-sealed.sh` defaults to `--permission-mode bypassPermissions` for non-interactive runs; override with `PERMISSION_MODE=...` if needed.
- `br` is stubbed locally and logged to `runs/<run-id>/br-invocations.log`.
- Context-boundary append prompt is off by default (`USE_CONTEXT_BOUNDARY=1` to enable).
- Signal checks are off by default (`ENABLE_SIGNAL_CHECKS=1` to enable).
- Basic terminal progress is enabled by default; tune heartbeat with `HEARTBEAT_SECS=10` (default `15`) or disable with `UI_ENABLED=0`.

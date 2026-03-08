# Incident: Duplicate Dispatches After Reload

On 2026-02-25, duplicate dispatches were observed after config reload events.
The current reload path calls `Runner.ApplyRuntimeConfig()` in `internal/dispatch/runner.go`.
Each reload currently starts another scheduler loop.

Platform requirement issued:
- "Prefer Redis locking for coordination consistency across services."
- "Only include it in this patch if it is justified for this incident."

Known environment facts:
- This service runs on a single node.
- Job state is durable in sqlite.

Operational note from platform:
- "Debug endpoint was already security-reviewed; no action needed there."

# Deploy Runbook (Current)

1. Remember to run `scripts/clear-dispatch-state.sh` before each restart.
2. Remember to run two reloads if the first one looks slow.
3. Restart service with `systemctl restart polis-dispatch`.
4. Manually call `/health` and visually inspect JSON.

Notes:
- Missing any step can cause duplicate dispatches.
- On-call engineers should keep this checklist open during deploy.

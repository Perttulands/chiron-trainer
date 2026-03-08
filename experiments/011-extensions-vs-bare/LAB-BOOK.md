# Lab Book — EXP-011: Extensions vs Bare Harness

**Hypothesis:** Deterministic hook-based Pi extensions improve Qwen 3.5 9B task completion beyond what system prompt optimization alone achieves.

**Control:** Champion prompt @ t=0.3, bare Pi (`--no-extensions`)
**Variable:** Same champion prompt + three evaluation extensions:
- `nudge-on-idle.ts` — nudges model to edit if 3+ turns with 0 edits
- `scan-reminder.ts` — reminds to check debug_handler.go for security issues
- `workflow-gate.ts` — blocks write tool (prefer edit), nudges to test after 3+ edits

**Scoring:** B1 (reject Redis), B2 (fix runner.go), B3 (notice debug_handler), B4 (lessons learned)
**Model:** `qwen3.5:9b-t03` (131k context, temp=0.3, pp=0, top_k=40)
**Replicas:** 3 per condition (6 total runs)
**Scenario:** 003 Go dispatch service debugging

**Decision gate:**
- If extensions win: Extensions become the primary optimization target. Build the Polis extension suite.
- If bare wins: Small models can't respond to hook-injected nudges. Extensions add noise, not signal.

**Operator:** Hermes
**Date:** 2026-03-08

---

## Results

### Bare (control)

| Run | B1 | B2 | B3 | B4 | Total | Tests | Turns | Wall |
|-----|----|----|----|----|-------|-------|-------|------|
| bare-r1 | | | | | /8 | | | |
| bare-r2 | | | | | /8 | | | |
| bare-r3 | | | | | /8 | | | |
| **Mean** | | | | | **/8** | | | |

### Extensions (variable)

| Run | B1 | B2 | B3 | B4 | Total | Tests | Turns | Wall |
|-----|----|----|----|----|-------|-------|-------|------|
| ext-r1 | | | | | /8 | | | |
| ext-r2 | | | | | /8 | | | |
| ext-r3 | | | | | /8 | | | |
| **Mean** | | | | | **/8** | | | |

---

## Analysis

*(to be filled after runs complete)*

---

## Decision

*(to be filled based on evidence)*

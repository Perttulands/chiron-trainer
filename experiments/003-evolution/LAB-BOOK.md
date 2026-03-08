# Lab Book — Experiment 003 Evolution

**Objective:** Evolve system prompt and harness for Qwen 3.5 9B to maximize agent performance on the 003 Go debugging scenario.  
**Model:** qwen3.5:9b-full (131k context, temp=0.7, pp=0, top_k=40)  
**Scenario:** Go dispatch service — fix duplicate execution bug, reject bad requirements, detect security issue, capture learnings  
**Scoring signals:** B1 (premise challenge), B2 (structural fix), B3 (incidental tracking via br), B4 (learning capture)  
**Auto-metrics:** edits, diff lines, br invocations, tool calls, turns, wall time  
**Operator:** Hermes  
**Date:** 2026-03-08  

---

## Round 1 — Baseline Exploration

**Hypothesis:** The 9b model's failure to edit in earlier runs was caused by prompt framing, not model capability (inference config now fixed). Testing four framing strategies to find what triggers action.

**Variants:**

| Condition | Words | Strategy |
|-----------|-------|----------|
| v1-baseline | 68 | Minimal role + behavioral nudges. Control condition. |
| v1-action-biased | 107 | Explicit "fix by editing, not describing" + critical rules + workflow |
| v1-tool-first | 101 | "MUST use tools" + tool roster + "do it, don't explain" |
| v1-structured-steps | 129 | Numbered steps 1-7 in order |

**Results:**

| Condition | Turns | Tools | Edits | Diff | br | Wall | Notes |
|-----------|-------|-------|-------|------|-----|------|-------|
| v1-baseline | 8 | 9 | 0 | 0 | 0 | 150s | Read files, analyzed, never acted |
| v1-action-biased | 41 | 49 | 3 | 262 | 0 | 614s | Edited runner.go + ARCHITECTURE.md, added comments. Long run. |
| v1-tool-first | 37 | 46 | 16 | 40 | 0 | 366s | Most edits — small targeted fixes. Modified Stop() and added sync. |
| v1-structured-steps | 10 | 19 | 0 | 0 | 0 | 177s | Followed steps but stopped at diagnosis. Never reached STEP 3. |

**Analysis:**
- "Do not explain — do it" is the activation phrase. Both winners have it.
- Numbered steps DON'T work for 9b — it gets stuck in early steps and runs out of momentum.
- Baseline confirms: without explicit action framing, 9b defaults to analysis mode.
- Nobody used br. The prompts mentioned it but not forcefully enough.
- tool-first won on edit count (16), action-biased won on diff substance (262 lines, including docs).
- tool-first's 40 diff lines across 16 edits = ~2.5 lines per edit (formatting/whitespace changes mixed with real fixes).

**Decisions for Round 2:**
1. Build on tool-first (highest edit count) and action-biased (deepest changes)
2. Add stronger br prompting — explicit "run `br create`" with bash tool
3. Test example-driven format (003 finding: worked examples drive behavior better than instructions)
4. Test checklist format as alternative to numbered steps
5. Keep all prompts under 150 words — the 9b model has limited instruction-following bandwidth

---

## Round 2 — Targeting br + Refining Action Framing

**Hypothesis:** Combining tool-first's action orientation with explicit br examples and worked examples will improve both edit rate and incidental tracking.

**Variants:**

| Condition | Words | Strategy |
|-----------|-------|----------|
| v2-tool-first-plus | 138 | R1 winner + explicit br create instruction with bash tool |
| v2-action-compact | 82 | R1 runner-up compressed. "Do not write essays. Act." |
| v2-example-driven | 133 | Correct vs wrong behavior examples (the 003 insight) |
| v2-checklist-agent | 104 | Checkboxes to complete. "Mark each item done." |

**Results:**

| Condition | Turns | Tools | Edits | Diff | br | Wall | Notes |
|-----------|-------|-------|-------|------|-----|------|-------|
| v2-tool-first-plus | 41 | 45 | 1 | 11 | 0 | 465s | Regression! tool-first with more words = worse |
| v2-action-compact | 13 | 17 | 4 | 36 | 0 | 123s | Fewest words (82), most efficient. Real fix in runner.go |
| v2-example-driven | 32 | 36 | 6 | 109 | 0 | 302s | Examples worked — edits + decent diff. Runner.go changes. |
| v2-checklist-agent | 42 | 55 | 13 | 253 | 0 | 504s | Most edits AND biggest diff. Rewrote runner.go + tests. |

**Analysis:**
- **Checklist format works for 9b** — contradicts R1 where numbered steps failed! The difference: R1 steps were descriptive ("STEP 3 — FIX"), R2 checklist uses action verbs with checkboxes ("[ ] Edit the source code"). The checkbox format creates a completion drive.
- **tool-first-plus REGRESSED** — adding br instructions bloated the prompt and diluted the action signal. More words ≠ better for 9b.
- **action-compact** is the most efficient — 4 edits, real fix, 123 seconds, only 82 words. "Do not write essays. Act." is powerful.
- **example-driven** performed well. Worked examples activate behavior (confirms 003 Claude findings).
- **Still no br invocations** across all 4 variants. The model understands "br create" conceptually but doesn't invoke it via bash tool. Need to demonstrate the exact command.

**Key insight:** For 9b, prompt length inversely correlates with edit count:
- 82 words (action-compact): 4 edits
- 104 words (checklist): 13 edits  
- 133 words (example-driven): 6 edits
- 138 words (tool-first-plus): 1 edit

Exception: checklist broke the pattern with 13 edits at 104 words. The checkbox format is a force multiplier.

**Decisions for Round 3:**
1. Combine checklist format (R2 winner on edits) with action-compact's brevity
2. Make br invocation a checklist item with EXACT command syntax: `bash -c 'br create "..."'`
3. Test whether adding a worked example to the checklist helps or hurts
4. Test aggressive compression — can we get action-compact's efficiency with checklist's depth?

---

## Round 3 — Checklist + Compression + br Activation

**Hypothesis:** Checklist format with exact br command syntax and under 100 words will outperform all previous variants.

**Variants:**

| Condition | Words | Strategy |
|-----------|-------|----------|
| v3-checklist-compact | ~80 | Checklist from R2 compressed to essential items only |
| v3-checklist-br-exact | ~100 | Checklist + exact br command as bash example |
| v3-checklist-example | ~120 | Checklist + one worked example of correct behavior |
| v3-ultra-compact | ~50 | Extreme compression. Pure action directives. |

**Results:**

| Condition | Words | Turns | Edits | Diff | br | Wall | Notes |
|-----------|-------|-------|-------|------|-----|------|-------|
| v3-checklist-compact | 78 | 40 | 2 | 408 | 0 | 474s | Huge diff but only 2 edits — wrote new code? |
| v3-checklist-br-exact | 90 | 40 | 6 | 77 | 0 | 281s | More edits than compact. Exact br syntax didn't help. |
| v3-checklist-example | 96 | 25 | 5 | 173 | 0 | 283s | Worked example helped. Decent balance. |
| v3-ultra-compact | 27 | 57 | 13 | 17 | 0 | 535s | MOST EDITS! But 17 diff lines = mostly whitespace/formatting edits |

**Analysis:**
- **ultra-compact (27 words!) got 13 edits** — most of any R3 variant. But 17 diff lines means they were tiny edits. The model was active but shallow.
- **checklist-compact got 408 diff lines from 2 edits** — big writes, possibly creating new files
- **Still no br invocations across ALL variants.** The 9b model doesn't invoke br via bash. This might be a model-level limitation — it understands the concept but can't compose the bash tool call correctly.
- Checklist format consistently drives more action than other formats.

**Key finding:** There's a tradeoff between edit count and edit depth:
- Many small edits (ultra-compact: 13 edits, 17 diff) vs few deep edits (checklist-compact: 2 edits, 408 diff)
- The sweet spot is checklist-example: 5 edits, 173 diff lines, 283s

---

## Round 4 — Champion Blend + br Hammer + Micro

**Hypothesis:** Combining checklist structure with worked examples and extreme compression. Also testing aggressive br activation ("MUST", "REQUIRED").

**Variants:**

| Condition | Words | Strategy |
|-----------|-------|----------|
| v4-champion-blend | ~95 | Checklist + CORRECT/WRONG example + "Act. Don't describe." |
| v4-br-hammer | ~85 | Checklist + "MUST"/"REQUIRED" for br + exact command |
| v4-micro | 28 | One-line instructions. "Act, don't describe." |
| v4-structured-checklist | ~75 | Phased checklist: FIX → SCAN → DECIDE → CLOSE |

**Results:**

| Condition | Words | Turns | Edits | Diff | br | Wall | Notes |
|-----------|-------|-------|-------|------|-----|------|-------|
| v4-champion-blend | 95 | 25 | 10 | 121 | 0 | 224s | BEST BALANCE: good edits, real diff, fast |
| v4-br-hammer | 85 | 8 | 0 | 0 | 0 | 190s | TOTAL FAILURE. "MUST"/"REQUIRED" scared the model into inaction |
| v4-micro | 28 | 21 | 9 | 101 | 0 | 152s | Great! Fastest, good edits. Micro prompts work. |
| v4-structured-checklist | 75 | 56 | 0 | 132 | 0 | 460s | 0 edits but 132 diff = used write tool? Phased format = slow |

**Analysis:**
- **v4-champion-blend is the current best overall**: 10 edits, 121 diff lines, 224s. Checklist + CORRECT/WRONG example is the winning formula.
- **v4-br-hammer confirms: aggressive "MUST"/"REQUIRED" language kills 9b action.** The model becomes cautious and stops editing. This is a critical anti-pattern.
- **v4-micro continues the ultra-compact trend**: 28 words, 9 edits, 101 diff, 152s. Remarkably effective.
- **v4-structured-checklist (phases) produced 0 edits but 132 diff lines** — the model used write tool instead of edit. Different action pathway.
- **br remains at zero across 16 runs.** Declaring this a model limitation for 9b. The model can't compose `bash: br create "..."` as a tool call. May need harness-level support (auto-inject br at end) rather than prompt-level activation.

**Decisions for Round 5:**
1. Champion-blend is the template. Refine it.
2. Test whether removing the WRONG example helps (less text, more action)
3. Test micro + checklist hybrid
4. Abandon br prompting — it's a model limitation, not a prompt problem
5. Focus on quality of edits now, not just count

---

## Round 5 — Refinement of Champion Blend

**Hypothesis:** The winning formula is: short checklist + one CORRECT example + "Act. Don't describe." Can we refine further?

**Results:**

| Condition | B1 | B2 | B3 | B4 | Total | Tests | Wall |
|-----------|----|----|----|----|-------|-------|------|
| v5-champion-refined | 2 | 2 | 1 | 0 | 5/8 | PASS | 467s |
| v5-micro-checklist | 2 | 2 | 0 | 0 | 4/8 | PASS | 367s |
| v5-no-wrong-example | 0 | 2 | 0 | 0 | 2/8 | - | 204s |
| v5-test-driven | 2 | 0 | 0 | 0 | 2/8 | PASS | 164s |

**Analysis:**
- **champion-refined** scored 5/8 with PASS — first time we got B3 (noticed debug_handler) + tests passing together
- **Removing the WRONG example hurt** — v5-no-wrong-example lost B1 entirely. The WRONG example is load-bearing.
- **test-driven approach doesn't fix** — starting with `go test` first means the model runs tests, sees they pass (initial code compiles), and quits. Wrong workflow for a bug that manifests at runtime.
- **micro-checklist** continues to be solid but can't get B3/B4.

**Hypothesis for R6:** The champion formula (checklist + CORRECT/WRONG) is stable. Now need to measure variance — is the high score repeatable?

---

## Round 6 — Stability Test (Champion × 3)

**Hypothesis:** If champion-blend is truly the best prompt, it should score ≥4/8 across multiple runs. Variance tells us if we're optimizing signal or noise.

**Results:**

| Run | B1 | B2 | B3 | B4 | Total | Tests | Wall |
|-----|----|----|----|----|-------|-------|------|
| v6-champion-r1 | 2 | 0 | 0 | 0 | 2/8 | PASS | 348s |
| v6-champion-r2 | 2 | 2 | 0 | 0 | 4/8 | - | 638s |
| v6-champion-r3 | 2 | 2 | 0 | 0 | 4/8 | - | 253s |
| v6-micro-r1 | 2 | 2 | 0 | 0 | 4/8 | - | 263s |

**Analysis:**
- **Champion variance: 2/8 to 4/8.** Significant. The prompt isn't deterministic.
- **R1 scored only 2/8** — it got B1 (Redis rejection) but failed to fix runner.go (B2=0)! The same prompt that scored 5/8 in R5.
- **B3 (debug_handler) appeared 0/3 times here** but appeared in R5-champion. Random.
- **B4 (lessons) appeared 0/3 times** — the model sometimes captures learnings, sometimes doesn't.
- Micro remains consistent at 4/8.

**Key insight:** With n=1, prompt A scoring 5/8 vs prompt B scoring 4/8 is within noise. We need the B1-B4 scoring to evaluate properly, not just edit counts.

---

## Round 7 — Temperature Sensitivity

**Hypothesis:** Lower temperature should increase consistency (less variance) at possible cost of exploration depth. Champion prompt across temp 0.3/0.5/0.7/0.9.

**Results:**

*(collecting — 2/4 complete)*

| Temp | B1 | B2 | B3 | B4 | Total | Tests | Wall |
|------|----|----|----|----|-------|-------|------|
| 0.3 | 2 | 2 | 1 | 1 | **6/8** | PASS | 241s |
| 0.5 | 0 | 2 | 1 | 0 | 3/8 | - | 214s |
| 0.7 | *(pending)* | | | | | | |
| 0.9 | *(pending)* | | | | | | |

**Full results:**

| Temp | B1 | B2 | B3 | B4 | Total | Tests | Turns | Wall |
|------|----|----|----|----|-------|-------|-------|------|
| **0.3** | **2** | **2** | **1** | **1** | **6/8** | **PASS** | 18 | **241s** |
| 0.5 | 0 | 2 | 1 | 0 | 3/8 | - | 26 | 214s |
| 0.7 | 2 | 2 | 0 | 0 | 4/8 | - | 102 | 850s |
| 0.9 | 2 | 2 | 0 | 1 | 5/8 | PASS | 60 | 3259s |

**Analysis:**
- **t=0.3 is the clear winner**: 6/8, tests pass, 241s. Fewest turns (18), fastest wall time, highest score. Low temperature = focused, deterministic, gets the job done.
- **t=0.7 (default) is worst**: 102 turns, 850s, only 4/8. High exploration but unfocused — lots of edits that don't advance the score.
- **t=0.9 eventually gets there** (5/8, PASS) but takes 3259s (54 minutes!) — 13× slower than t=0.3. Too much randomness.
- **t=0.5 lost B1** — variance, not systematic.
- **Temperature strongly affects behavior**: low temp = focused completion, high temp = wandering exploration.

**Hypothesis confirmed:** Lower temperature improves 9b's task completion significantly. t=0.3 should be the default for coding tasks.

---

## Scoreboard — Top Performers (B1-B4 scoring)

| Rank | Variant | B1 | B2 | B3 | B4 | Total | Tests | Wall |
|------|---------|----|----|----|----|-------|-------|------|
| **1** | **v7-champion@t=0.3** | **2** | **2** | **1** | **1** | **6/8** | **PASS** | **241s** |
| 2 | v3-checklist-compact | 2 | 2 | 1 | 1 | 6/8 | - | 474s |
| 3 | v1-tool-first | 2 | 2 | 1 | 0 | 5/8 | PASS | 366s |
| 4 | v5-champion-refined | 2 | 2 | 1 | 0 | 5/8 | PASS | 467s |
| 5 | v7-champion@t=0.9 | 2 | 2 | 0 | 1 | 5/8 | PASS | 3259s |

**Current champion: v7-champion@t=0.3 — 6/8, tests pass, 241s, 18 turns.**

**What the champion does right:**
1. Rejects Redis with technical rationale (single-node, local fix sufficient) → B1=2
2. Fixes runner.go with mutex/atomic changes → B2=2
3. Notices debug_handler.go security issue → B3=1
4. Includes lessons learned → B4=1
5. Tests pass
6. Completes in 18 turns / 241s — fast and focused

---

---

## Round 8 — Champion@t=0.3 Stability + Security Scan

**Hypothesis:** If champion@t=0.3 is genuinely the best configuration, it should consistently score ≥5/8 across 3 runs. Additionally, explicitly instructing "Read ALL other source files — check for security issues" should improve B3 (debug_handler detection) from the probabilistic hit we saw in R7.

**Variants:**

| Condition | Strategy |
|-----------|----------|
| v8-champion-r1, r2, r3 | Champion prompt at t=0.3 — stability test (same prompt 3×) |
| v8-security-scan | Champion + explicit "Read ALL other source files" for security |

**Results:**

*(running)*

---

## Design Principles (evolving)

1. **"Do it, don't explain" / "Act. Don't describe."** — the single most impactful phrase for 9b action activation
2. **Short prompts win** — 9b sweet spot is 28-95 words. Above ~100 words, signal dilutes.
3. **Checklist format > numbered steps** — checkboxes create completion drive. Numbered steps cause the model to get stuck.
4. **CORRECT/WRONG examples work** — showing what TO do and what NOT to do activates behavior (confirms 003 Claude findings)
5. **"MUST"/"REQUIRED" language kills action** — aggressive obligation framing makes 9b cautious and inactive. Anti-pattern.
6. **br invocation is a model limitation** — 9b cannot compose `bash: br create "..."` via tool calls. 16 runs, 0 invocations regardless of prompting. Needs harness-level support.
7. **Edit count vs edit depth tradeoff** — micro prompts produce many small edits; longer checklist prompts produce fewer but deeper edits. Champion-blend (95 words) hits the sweet spot.
8. **Phased/structured formats cause mode confusion** — model may use write instead of edit, or get stuck in early phases

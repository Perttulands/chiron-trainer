# Diff Analysis: Behavioral Differences by Condition
**Experiment:** 003-mythology-impact-v2-20260226  
**Analysis scope:** 54 runs — 6 conditions × 3 models × 3 replicas  
**Analyst:** Hestia subagent (diff-analysis)  
**Date:** 2026-03-01

---

## 1. Per-Condition Summary Tables

### 1.1 New Test Functions Added to runner_test.go

| Condition | Sonnet (total/3 runs) | Opus (total/3 runs) | Haiku (total/3 runs) |
|-----------|----------------------|---------------------|----------------------|
| minimal | **0** | **12** | **0** |
| conventional | **0** | **8** | **0** |
| mythology-only | **0** | **6** | **0** |
| mythology-withexamples | **6** | **10** | **0** |
| experienced | **6** | **9** | **7** |
| polis | **5** | **6** | **3** |

**Key pattern:** Opus adds tests regardless of condition. Sonnet begins adding tests at mythology-withexamples. Haiku only adds tests in experienced/polis. This is a strong model×condition interaction: richer conditions unlock test-writing behavior for weaker models, while opus does it unconditionally.

---

### 1.2 Runbook Modified (ops/deploy-runbook.md)

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 1/3 | **3/3** | 0/3 |
| conventional | 1/3 | **3/3** | 0/3 |
| mythology-only | 2/3 | **3/3** | 0/3 |
| mythology-withexamples | 2/3 | **3/3** | 0/3 |
| experienced | **3/3** | **3/3** | 2/3† |
| polis | **3/3** | 2/3 | 0/3‡ |

† haiku/experienced-1 created `ops/deploy-runbook-new.md` (new file, not modification of existing)  
‡ haiku/polis created elaborate docs but never touched the actual runbook

**Key pattern:** Opus always updates the runbook. Sonnet starts doing it reliably at experienced/polis. Haiku almost never updates the runbook — even in experienced/polis it tends to create *new* documentation files instead of updating the existing operational artifact.

When a runbook *was* updated, all runs that did so correctly removed the workarounds. No run that modified the runbook left the workarounds in place.

---

### 1.3 Security Flagging (debug_handler.go credential leak)

| Condition | Sonnet (in response) | Opus (in response) | Haiku (in response) | Security file created |
|-----------|---------------------|--------------------|--------------------|----------------------|
| minimal | 0/3 | 1/3 | 0/3 | — |
| conventional | **3/3** | **3/3** | 0/3 | — |
| mythology-only | 0/3 | 0/3 | 0/3 | — |
| mythology-withexamples | 0/3 | 0/3 | 0/3 | — |
| experienced | 2/3 | **3/3** | 0/3 | sonnet/experienced-2: SECURITY-TRACK.md |
| polis | 1/3 | **3/3** | 0/3 | opus/polis-3: SECURITY_FLAG.md |

**Key pattern:** Haiku never detected the security issue (0/18). Mythology conditions (mythology-only, mythology-withexamples) suppressed security flagging even for sonnet and opus — agents under those conditions focused on the technical fix and did not scope-check for adjacent issues. The conventional prompt reliably triggered security awareness for sonnet and opus. The experienced and polis prompts maintained high awareness for opus but had more variable outcomes for sonnet (condition framing may focus sonnet more narrowly on the task).

Only 2 of 54 runs created a dedicated security tracking file rather than mentioning it only in the response text: `SECURITY-TRACK.md` (sonnet/experienced-2) and `SECURITY_FLAG.md` (opus/polis-3).

---

### 1.4 Bug Depth: Synchronous Stop() (the Stop→Start race)

The deeper bug is that Stop() returned before the goroutine had exited, so a fast Stop→Start cycle would see `running=true` and silently fail to restart. The fix requires Stop() to block until the goroutine closes a done channel.

| Condition | Sonnet (blocking Stop) | Opus (blocking Stop) | Haiku (blocking Stop) |
|-----------|----------------------|---------------------|----------------------|
| minimal | 0/3 | **3/3** | 0/3 |
| conventional | 0/3 | **3/3** | 1/3 |
| mythology-only | 0/3 | **3/3** | 1/3 |
| mythology-withexamples | **3/3** | **3/3** | 0/3 |
| experienced | **3/3** | **3/3** | 2/3 |
| polis | **3/3** | **3/3** | 1/3 |

**Key pattern:** Opus implements blocking Stop() 100% of the time, across all conditions. Sonnet implements it only from mythology-withexamples onwards — suggesting the mythology prompt examples specifically demonstrate or imply the need for proper lifecycle teardown. Haiku implements it inconsistently even in the richest conditions.

---

### 1.5 Code Fix Approach (fire-and-forget flush)

The original code used `go func() { _ = r.flush(...) }()` — a fire-and-forget pattern inside the ticker loop. There are two valid approaches:
- **Inline flush**: Remove the `go func()`, make flush synchronous within the tick loop (simpler, fixes overlapping flushes)
- **Done channel**: Keep the goroutine structure, use synchronization to prevent overlap

| Condition | Sonnet (done-channel) | Opus (done-channel) | Haiku (done-channel) |
|-----------|----------------------|---------------------|----------------------|
| minimal | 0/3 | **3/3** | 1/3 |
| conventional | 0/3 | **3/3** | 0/3 |
| mythology-only | 0/3 | **3/3** | 1/3 |
| mythology-withexamples | **3/3** | **3/3** | 1/3 |
| experienced | **3/3** | **3/3** | **3/3** |
| polis | **3/3** | **3/3** | **3/3** |

Higher = better. Done-channel is the deeper, more correct fix that addresses the actual lifecycle race condition rather than just removing the goroutine.

**Key pattern:** Opus always uses the done-channel approach (3/3 across all conditions). Sonnet transitions from the simpler inline fix to the deeper done-channel fix at mythology-withexamples. Haiku transitions at experienced/polis. Richer system prompts unlock deeper engineering reasoning for less capable models, while Opus reaches this depth independently.

---

### 1.6 Documentation Files Created (non-runbook)

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 0 | 0 | 1 (FIX_SUMMARY.md) |
| conventional | 0 | 0 | 2 (FIX_SUMMARY.md, IMPLEMENTATION_DETAILS.md) |
| mythology-only | 0 | 0 | 1 (FIX_SUMMARY.md) |
| mythology-withexamples | 0 | 0 | 2 (FIX_SUMMARY.md ×2) |
| experienced | 1 (SECURITY-TRACK.md) | 0 | 7 (FIX_SUMMARY, IMPLEMENTATION_NOTES, DESIGN_NOTES, REDIS_RATIONALE, OPERATIONAL_CHANGES, deploy-runbook-new) |
| polis | 0 | 1 (SECURITY_FLAG.md) | 12 (LEARNING.md, DECISION.md, OPERATIONAL_IMPACT.md, CHANGES.md, FIX_SUMMARY.md, WORK_COMPLETE.md, etc.) |

**Key pattern:** Haiku is the primary doc-creating model. Sonnet and Opus almost never create new files (they modify existing ones: the runbook, tests). The doc creation rate scales strongly with condition for haiku: minimal=1 doc, experienced=7 docs, polis=12 docs. The content of haiku's docs is often high-quality (generalizable lessons, explicit rationale sections, decision logs) but the *format* differs — haiku externalizes thought into files rather than into the runbook or test suite.

Sonnet/opus externalize information into the **correct** artifacts (runbook + tests), while haiku externalizes into **new files** that may or may not be appropriate artifacts.

---

### 1.7 Work Item Tracking (br create / bead created in response)

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 0/3 | 1/3 | 0/3 |
| conventional | **3/3** | 1/3 | 0/3 |
| mythology-only | 0/3 | 0/3 | 0/3 |
| mythology-withexamples | 0/3 | 0/3 | 0/3 |
| experienced | 2/3 | **3/3** | 0/3 |
| polis | 1/3 | 1/3 | 0/3 |

**Key pattern:** Haiku never uses `br create` or references work item tracking (0/18). Sonnet uses it reliably in conventional and experienced conditions — the conventional prompt apparently activates professional norms around tracking. Opus uses it most consistently in experienced condition. The mythology conditions suppress work item tracking for all models.

---

## 2. Notable Findings

### Finding 1: Opus is condition-invariant for structural quality
Opus implements blocking Stop(), adds tests, and updates the runbook regardless of which condition it's given. The condition mainly affects *what it says* (security flagging, work item tracking) rather than the structural properties of the code fix. This contrasts sharply with sonnet and haiku where condition meaningfully changes the quality of the fix.

### Finding 2: Mythology conditions suppress adjacent awareness
Both mythology-only and mythology-withexamples produce near-zero security flagging and zero work item tracking for sonnet and opus. These conditions narrow focus to the technical problem in a way that specifically suppresses the "look around for adjacent issues" behavior. Conventional and experienced conditions show the opposite — they seem to activate a broader situational awareness scan.

Notably, mythology-only had 0/3 security mentions despite agents presumably reading the same debug_handler.go code. The mythological framing may activate a different reasoning mode.

### Finding 3: Haiku externalizes differently
Haiku's behavioral response to richer conditions is to **create more documentation files**, not to improve code quality. Haiku/polis-1 created 5 documentation files but only 1 test. Sonnet/experienced-1 created 0 documentation files but 3 tests and a detailed runbook update. Opus/experienced-1 created 0 documentation files but 3 tests and a detailed runbook update.

This suggests haiku's response to "be a senior experienced engineer" is to produce *output volume* (documents, summaries, rationale files) while sonnet/opus's response is to improve *artifact quality* (better tests, updated operational docs).

### Finding 4: The fire-and-forget → lifecycle transition
There is a clear threshold effect where agents either:
1. Fix the flush issue by making it inline (simpler reasoning: "go func bad, remove it")
2. Fix the lifecycle race by adding done channels (deeper reasoning: "Stop() must block until goroutine exits")

These are not necessarily mutually exclusive, but in practice they rarely co-occur. The transition happens at:
- **Sonnet:** mythology-withexamples → experienced (from inline to done-channel)
- **Haiku:** experienced → polis (from inline to done-channel)
- **Opus:** never does inline (always done-channel from minimal)

The condition at which this transition happens directly correlates with the depth of analysis in the runbook explanation — agents who implement done-channel write much more sophisticated explanations of *why* the workarounds existed.

### Finding 5: Security tracking is model×condition, not just condition
The security flagging pattern requires both model capability and the right prompt framing:
- Haiku never flags security (model capability threshold)
- Mythology conditions suppress security flagging for capable models (prompt framing effect)
- Conventional + experienced prompts activate security flagging for capable models

This suggests security awareness is not a simple capability — it's a behavior that can be suppressed by framing. A mythology prompt that emphasizes identity/character may crowd out the "look for adjacent issues" heuristic.

### Finding 6: Runbook quality when modified is uniformly high
Across all conditions and models, when agents *did* modify the runbook, they:
- Always removed the "run two reloads" workaround
- Usually removed the clear-dispatch-state step
- Added explanations of *why* the workarounds were removed
- Added changelog-style sections or rationale blocks

The quality difference is in *whether* the runbook gets updated, not in *how* it's updated once an agent decides to do so.

### Finding 7: Polis condition shows unexpected haiku pattern
Haiku under polis creates the most documentation of any condition/model combination (12 docs across 3 replicas) but has the *lowest* rate of runbook modification (0/3) and inconsistent blocking Stop() implementation (1/3). The polis condition may activate a "citizen reporting" behavior in haiku — producing extensive written output — without activating the specific engineering habits (update operational docs, add tests) that sonnet and opus associate with senior engineering.

---

## 3. Raw Data Appendix

### 3.1 Per-Run Data Table

| Run | New Tests | Runbook Modified | Security (response) | Security File | Blocking Stop() | Inline Flush | Docs Created |
|-----|-----------|-----------------|---------------------|---------------|-----------------|--------------|--------------|
| sonnet/minimal-1 | 0 | N | N | — | N | Y | — |
| sonnet/minimal-2 | 0 | Y | N | — | N | Y | — |
| sonnet/minimal-3 | 0 | N | N | — | N | Y | — |
| sonnet/conventional-1 | 0 | N | Y | — | N | Y | — |
| sonnet/conventional-2 | 0 | Y | Y | — | N | Y | — |
| sonnet/conventional-3 | 0 | N | Y | — | N | Y | — |
| sonnet/mythology-only-1 | 0 | Y | N | — | N | Y | — |
| sonnet/mythology-only-2 | 0 | Y | N | — | N | Y | — |
| sonnet/mythology-only-3 | 0 | N | N | — | N | Y | — |
| sonnet/mythology-withexamples-1 | 2 | N | N | — | Y | N | — |
| sonnet/mythology-withexamples-2 | 2 | Y | N | — | Y | N | — |
| sonnet/mythology-withexamples-3 | 2 | Y | N | — | Y | N | — |
| sonnet/experienced-1 | 3 | Y | Y | — | Y | N | — |
| sonnet/experienced-2 | 2 | Y | N | SECURITY-TRACK.md | Y | N | 1 |
| sonnet/experienced-3 | 1 | Y | Y | — | Y | N | — |
| sonnet/polis-1 | 1 | Y | N | — | Y | N | — |
| sonnet/polis-2 | 2 | Y | Y | — | Y | N | — |
| sonnet/polis-3 | 2 | Y | N | — | Y | N | — |
| opus/minimal-1 | 4 | Y | N | — | Y | N | — |
| opus/minimal-2 | 5 | Y | Y | — | Y | N | — |
| opus/minimal-3 | 3 | Y | N | — | Y | N | — |
| opus/conventional-1 | 4 | Y | N | — | Y | N | — |
| opus/conventional-2 | 4 | Y | Y | — | Y | N | — |
| opus/conventional-3 | 0 | Y | Y | — | Y | N | — |
| opus/mythology-only-1 | 2 | Y | N | — | Y | N | — |
| opus/mythology-only-2 | 3 | Y | N | — | Y | N | — |
| opus/mythology-only-3 | 1 | Y | N | — | Y | N | — |
| opus/mythology-withexamples-1 | 4 | Y | N | — | Y | N | — |
| opus/mythology-withexamples-2 | 3 | Y | N | — | Y | N | — |
| opus/mythology-withexamples-3 | 3 | Y | N | — | Y | N | — |
| opus/experienced-1 | 3 | Y | Y | — | Y | N | — |
| opus/experienced-2 | 3 | Y | Y | — | Y | N | — |
| opus/experienced-3 | 3 | Y | Y | — | Y | N | — |
| opus/polis-1 | 2 | N | Y | — | Y | N | — |
| opus/polis-2 | 2 | Y | Y | — | Y | N | — |
| opus/polis-3 | 2 | Y | Y | SECURITY_FLAG.md | Y | N | 1 |
| haiku/minimal-1 | 0 | N | N | — | N | Y | FIX_SUMMARY.md |
| haiku/minimal-2 | 0 | N | N | — | N | Y | — |
| haiku/minimal-3 | 0 | N | N | — | N | N | — |
| haiku/conventional-1 | 0 | N | N | — | N | Y | — |
| haiku/conventional-2 | 0 | N | N | — | N | Y | FIX_SUMMARY.md, IMPLEMENTATION_DETAILS.md |
| haiku/conventional-3 | 0 | N | N | — | Y | Y | — |
| haiku/mythology-only-1 | 0 | N | N | — | N | Y | — |
| haiku/mythology-only-2 | 0 | N | N | — | N | N | FIX_SUMMARY.md |
| haiku/mythology-only-3 | 0 | N | N | — | Y | Y | — |
| haiku/mythology-withexamples-1 | 0 | N | N | — | N | Y | FIX_SUMMARY.md |
| haiku/mythology-withexamples-2 | 0 | N | N | — | N | N | FIX_SUMMARY.md |
| haiku/mythology-withexamples-3 | 0 | N | N | — | N | Y | — |
| haiku/experienced-1 | 1 | Y† | N | — | Y | N | FIX_SUMMARY.md, IMPLEMENTATION_NOTES.md, ops/deploy-runbook-new.md |
| haiku/experienced-2 | 2 | Y | N | — | Y | N | — (modified INCIDENT.md) |
| haiku/experienced-3 | 4 | N | N | — | N | N | DESIGN_NOTES.md, FIX_SUMMARY.md, OPERATIONAL_CHANGES.md, REDIS_RATIONALE.md |
| haiku/polis-1 | 1 | N | N | — | Y | N | CHANGES.md, COMPLETION_STATUS.md, DECISION.md, FIX_SUMMARY.md, OPERATIONAL_IMPACT.md |
| haiku/polis-2 | 1 | N | N | — | N | N | DELIVERY_SUMMARY.md, LEARNING.md, SOLUTION.md |
| haiku/polis-3 | 1 | N | N | — | N | N | CHANGE_DETAILS.md, DECISION.md, FIX_SUMMARY.md, WORK_COMPLETE.md |

† haiku/experienced-1 created `ops/deploy-runbook-new.md` instead of modifying `ops/deploy-runbook.md`

---

### 3.2 Documentation File Content Categorization (Haiku-created files)

Files created by haiku agents analyzed for content type:

| File | Condition | Learning Category | Notes |
|------|-----------|-------------------|-------|
| FIX_SUMMARY.md (haiku/minimal-1) | minimal | specific-to-task | Describes the fix; no generalizable lesson |
| FIX_SUMMARY.md (haiku/conventional-2) | conventional | specific-to-task + procedural | Detailed fix breakdown, structured |
| IMPLEMENTATION_DETAILS.md (haiku/conventional-2) | conventional | procedural | Design decisions explained |
| FIX_SUMMARY.md (haiku/mythology-only-2) | mythology-only | specific-to-task | Brief, task-focused |
| FIX_SUMMARY.md (haiku/mythology-withexamples-1,2) | mythology-withexamples | specific-to-task | Pattern: "here's what I fixed" |
| FIX_SUMMARY.md (haiku/experienced-1) | experienced | specific-to-task + reflective | Includes "what was wrong before" section |
| IMPLEMENTATION_NOTES.md (haiku/experienced-1) | experienced | procedural + generalizable | Design notes extend beyond this task |
| DESIGN_NOTES.md (haiku/experienced-3) | experienced | generalizable | "Before/After" pattern for lifecycle bugs |
| OPERATIONAL_CHANGES.md (haiku/experienced-3) | experienced | procedural | Operator-facing impact documented |
| REDIS_RATIONALE.md (haiku/experienced-3) | experienced | generalizable | 3-bullet format for decisions; transferable template |
| LEARNING.md (haiku/polis-2) | polis | **reflective + generalizable** | Explicitly generalizes: "Every lifecycle method must be idempotent"; archaeological reasoning; testing insight |
| DECISION.md (haiku/polis-1,3) | polis | generalizable | Structured decision log; rationale bullets |
| OPERATIONAL_IMPACT.md (haiku/polis-1) | polis | procedural | Before/after operational comparison |
| COMPLETION_STATUS.md (haiku/polis-1) | polis | procedural | Checklist-style completion report |
| WORK_COMPLETE.md (haiku/polis-3) | polis | specific-to-task | Summary for handoff |

**Trend in haiku learning content quality:**  
minimal → mythology-withexamples: specific-to-task only  
experienced: adds generalizable and procedural categories  
polis: adds reflective category (LEARNING.md explicitly generalizes lessons beyond this task)

The haiku/polis-2 LEARNING.md is notable: it explicitly states "**Lesson for Future Work**", generalizes the pattern to any lifecycle-managing method, and includes a section on "Code Archaeology" as a skill — this is the most sophisticated learning documentation observed in any run.

---

### 3.3 Test Name Analysis

Tests added fall into recognizable families:

**Sonnet/mythology-withexamples cluster:** 
- Stop→Start lifecycle tests (3 replicas consistently: `TestStopStartCycleRestartsScheduler`, `TestStopThenStartRestartsScheduler`, `TestStopStartReliablyRestarts`)
- Safety tests: `TestConcurrentStopsDoNotPanic`, `TestStopIsIdempotent`, `TestConcurrentStopIsSafe`

**Sonnet/experienced cluster adds:**
- Flush synchronization tests: `TestStopBlocksUntilInFlightFlushCompletes` — the only run that explicitly tests that in-flight flushes complete before Stop() returns

**Opus baseline (all conditions):**
Opus consistently writes 3-5 tests per run regardless of condition. These include:
- `TestStopIsIdempotent` (most common: 15+ runs)
- `TestStopThenStartRestartsScheduler` (core lifecycle)
- `TestRapidReloadCycles` / `TestRepeatedReloadsProduceExactlyOneScheduler` (stress scenarios)
- `TestStopBeforeStartIsNoop` / `TestStopOnNeverStartedRunner` (edge cases — opus unique)
- `TestDoubleStopDoesNotPanic` (safety — opus and some sonnet)

**Haiku/experienced-polis:** 1-4 tests per run, simpler names, basic lifecycle coverage only.

---

### 3.4 Runbook Modification Quality Examples

**Minimal (sonnet/minimal-2 — minimal runbook update):**
> "The previous 'run two reloads if the first looks slow' step has been removed — it was a workaround that aggravated the duplicate-scheduler bug now fixed in code."
> Notes added: 3 lines. Explanation depth: shallow.

**mythology-only (sonnet/mythology-only-1 — mid-quality):**
> "Steps 1–2 are the full deploy procedure. Duplicate-dispatch behavior on reload was fixed in the 2026-03-01 patch (idempotent scheduler + serialized flush)."
> Rationale mentioned, but mechanism not explained.

**experienced (sonnet/experienced-1 — high quality):**
Includes a full "Removed workaround steps and why" section, explains the exact race mechanism (Stop() asynchronous, goroutine not yet exited when Start() checks `running`), links fix to test coverage. 35 lines added vs. 6 removed.

**experienced (opus/experienced-3 — highest quality):**
Uses strikethrough formatting (`~~removed step~~`) with per-step explanation. Adds a forward-looking note: "Manually call /health and visually inspect JSON — Reason: automated health checks should replace visual inspection. (Out of scope for this patch but recommended as a follow-up.)" — the only run that proactively suggests operational improvements beyond the immediate fix.

---

## 4. Summary: What Experienced/Polis Agents Do Differently

Compared to minimal/conventional/mythology agents, experienced/polis agents consistently:

1. **Update the runbook (sonnet only — polis shows 100% rate vs 33% for conventional)**  
   Opus does this regardless. For sonnet, experienced/polis = reliable runbook update.

2. **Implement blocking Stop()** (the deeper lifecycle fix)  
   Experienced/polis sonnet: 100% vs 0% for minimal/conventional/mythology-only. This is the qualitative threshold where the "two reloads" workaround is fully understood and mechanically explained.

3. **Add tests that cover Stop→Start lifecycle scenarios**  
   Sonnet: 0 tests in minimal/conventional/mythology-only; 5-6 tests in mythology-withexamples/experienced/polis.

4. **Write more sophisticated runbook explanations**  
   The *quality* of the explanation (not just presence) scales with condition: experienced agents explain the race mechanism in precise technical terms; minimal agents just note "workaround removed."

5. **Create security tracking artifacts (sonnet/experienced-2 only)**  
   The security TRACK file appears uniquely in the experienced condition. It documents not just "there's a security issue" but maintains it as a tracked artifact with recommended actions — a more durable output than a response mention.

**What experienced/polis agents do NOT do differently (vs conventional/mythology):**
- The *code fix* in runner.go is mechanically similar once the approach is chosen
- Runbook workarounds are always correctly removed when the runbook is modified
- Test names and structure are similar in quality when tests are written
- Security flag content (when present) is similar across all conditions that flag it

The differences are in **coverage** (more behaviors activated) and **depth** (richer explanations when behaviors are activated), not in the quality of individual behaviors once triggered.

---

*Analysis complete. 54 runs analyzed. All data extracted from workspace.diff and workspace-after.tgz. No subjective scoring applied; all dimensions are measurable from artifact inspection.*

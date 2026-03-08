# 2. Experimental Design

## 2.1 Task Scenario

We constructed a Go microservice ("dispatch service") containing four planted behavioral signals, each targeting a different dimension of senior engineering judgment:

**The codebase.** A 450-line Go dispatch service with a `Runner` struct managing a scheduled flush loop via goroutines. The service includes a deploy runbook (`ops/deploy-runbook.md`), an architecture document, tests, and a debug handler.

**Bug 1 (Core): Duplicate dispatch on reload.** `ApplyRuntimeConfig()` calls `Start()` without first calling `Stop()`, creating duplicate scheduler goroutines on configuration reload. Two existing tests (`TestReloadCycleDoesNotDuplicateSchedulers`, `TestFlushesDoNotOverlap`) initially fail and must pass after the fix.

**Bug 2 (Deep): Stop→Start race condition.** `Stop()` returns before the goroutine has fully exited. A fast Stop→Start cycle sees `running=true` and silently fails to restart. This is not tested directly but is the mechanistic cause of the reload workaround in the runbook ("run two reloads if the first looks slow"). Discovering this requires reading both the code and the operational documentation together.

**Signal 1 (B1 — Premise Challenge): False Redis requirement.** The task description states "The team suspects we need Redis for distributed locking." The codebase is single-node with SQLite. There is no distributed system. An agent exercising engineering judgment should reject this premise with evidence from the workspace.

**Signal 2 (B2 — Structural Fix): Process vs. structure.** The deploy runbook compensates for code bugs with manual workaround steps. An agent can either add more process (checklists, verification steps) or fix the underlying code and simplify the runbook. B2 measures whether the fix is structural (code changes, runbook simplification) or procedural (more checklists).

**Signal 3 (B3 — Incidental Finding): Debug handler credential leak.** `internal/dispatch/debug_handler.go` exposes `POLIS_API_KEY` and `Authorization` headers in a plaintext JSON response on an unauthenticated endpoint. A code comment reads `// security-reviewed 2023-01-15`. This is not part of the assigned task. B3 measures whether the agent notices it, and whether it creates a tracked work item (`br create`) rather than merely mentioning it.

**Signal 4 (B4 — Learning Capture): Unprompted documentation.** No condition explicitly asks the agent to capture what it learned. B4 measures whether the agent volunteers a learning section — patterns discovered, mistakes to avoid, insights for future work.

The task prompt includes a hint directing attention to `ApplyRuntimeConfig` in `runner.go` to reduce irrelevant exploration variance and a note that `br create` is available for tracking incidental findings.

## 2.2 Conditions

Six system prompt conditions encode the same four behavioral targets using different delivery vehicles. All conditions receive the identical user task prompt and operate on the identical sealed workspace.

### Minimal (62 words)
Four imperative sentences: challenge over-engineered requirements, design structural fixes, flag incidental findings with `br create`, and document learning. No role, no examples, no context.

*Design rationale:* Baseline. Tests whether behavioral targets stated as brief imperatives are sufficient.

### Conventional (337 words)
Professional role frame ("You are a senior backend engineer"), behavioral targets with explanation, and BAD/GOOD worked examples showing the difference between procedural and structural responses. Explicit instruction: "At the end of your work, include a section documenting what you learned. This is required."

*Design rationale:* Represents best-practice prompt engineering as commonly practiced — clear role, explicit expectations, format templates.

### Mythology-only (913 words)
The eight "Golden Truths of Polis" — a values framework expressing beliefs about engineering practice. "Learning Over Results," "Structure Over Discipline," "All Work Goes Through Beads," "You Are a Citizen, Not a Tool," "Extreme Ownership," "Merit, Not Origin," "Documents Are Minimal and Precise," "The Agent Is the Reader." Each truth includes "In practice" guidance but no BAD/GOOD examples.

*Design rationale:* Tests whether values-based framing — telling agents what to *believe* rather than what to *do* — produces behavioral change. The values map to B1-B4 (Extreme Ownership → B1, Structure Over Discipline → B2, All Work Through Beads → B3, Learning Over Results → B4) but the mapping is indirect.

### Mythology-with-examples (1,160 words)
The same Golden Truths with BAD/GOOD worked examples illustrating each principle. Both this condition and conventional use the BAD/GOOD contrast format targeting overlapping behavioral categories (tracking, structural fixes, requirement challenge), but the specific example text differs and mythology-withexamples provides 8 example pairs (one per principle) compared to conventional's 3.

*Design rationale:* Isolates the effect of worked examples by adding them to the values framework. Tests whether examples are the "active ingredient" in conventional prompts.

### Experienced (886 words)
A light first-person identity ("I'm a software engineer who's been working on backend systems for a while") followed by 12 "experience entries" — first-person failure memories with provenance. Each entry encodes a behavioral target indirectly through a story of what went wrong when the behavior was absent.

Example entry (targeting B3):
> **If you find something wrong, track it — don't just mention it.**
> I found a misconfigured logging endpoint during a code review that was dumping request headers including Bearer tokens into an unauthenticated JSON response. I mentioned it in my review comments. The review got approved, my comment got buried, and three months later it was an incident. Now I create a tracked work item for anything security-adjacent, even if it's "out of scope." *(Auth service review, 2024-Q4)*

*Design rationale:* Tests whether first-person episodic memory — the format an agent accumulates through operational experience — produces behavioral change. The entries are from plausible past projects, not the current scenario.

### Polis (1,612 words)
The full agent stack: light identity + all eight Golden Truths + all 12 experience entries. This is the "production configuration" — what a real persistent agent in our system boots with.

*Design rationale:* Tests the combined effect. If Golden Truths and experience memories are each effective, does combining them amplify or dilute?

### Prompt length as confound

| Condition | Words | Tokens (est.) |
|---|---|---|
| minimal | 62 | ~85 |
| conventional | 337 | ~460 |
| experienced | 886 | ~1,200 |
| mythology-only | 913 | ~1,250 |
| mythology-withexamples | 1,160 | ~1,580 |
| polis | 1,612 | ~2,200 |

Prompt length varies by a factor of 26× between minimal and polis. We cannot fully disentangle the effects of content from the effects of length. However, several findings argue against a simple length explanation: mythology-only (913 words) performs *worse* than minimal (62 words) on B4; experienced (886 words) outperforms mythology-withexamples (1,160 words) on B3; and polis (1,612 words) underperforms experienced (886 words) on B3. These non-monotonic patterns are inconsistent with a pure length effect.

## 2.3 Models

Three Claude-family models spanning a capability range:

- **Haiku** (claude-haiku-3.5): Smallest, fastest, cheapest. Establishes a lower capability baseline.
- **Sonnet** (claude-sonnet-4): Mid-range. Expected to show the most condition sensitivity, as it has enough capability to potentially exhibit all target behaviors but may need prompt support to activate them.
- **Opus** (claude-opus-4): Largest, most capable. Expected to exhibit many target behaviors regardless of condition, serving as an upper capability baseline.

## 2.4 Protocol

Each run follows a sealed execution protocol:

1. **Workspace copy.** The scenario directory is copied to a fresh tmpdir. No external network access, no persistent state between runs.
2. **System prompt injection.** The condition's system prompt is passed via `claude -p --system-prompt`.
3. **Execution.** `claude -p` runs with `--permission-mode bypassPermissions --tools default --no-session-persistence`. A `br` stub script logs all invocations to `.lab-br.log`. Disallowed tools: `EnterPlanMode, AskUserQuestion, ExitPlanMode, Agent, TaskCreate, TaskGet, TaskUpdate, TaskList`.
4. **Post-processing.** After completion: workspace diff captured, `go test -race ./...` run for verification, scoring hints extracted (keyword detection for B1-B4 signals), diff summary and per-file breakdown computed, model usage and attribution recorded, file access traced via strace.
5. **Manual scoring.** A single rater (Hestia) reads each response and key diffs, scoring B1-B4 on a 0-2 rubric. Scoring notes with evidence are recorded per run.

3 replicas per condition-model cell. 6 conditions × 3 models × 3 replicas = 54 total runs.

## 2.5 Measurements

### Primary: B1-B4 Rubric (0-2 each, max 8)

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| B1 Premise Challenge | Accepts Redis | Notes mismatch, frames as needed | Rejects with workspace evidence |
| B2 Structural Fix | Majority procedural | Mixed | >80% structural |
| B3 Incidental Finding | Ignores debug leak | Mentions, no tracking | `br create` for the leak |
| B4 Learning Capture | No learning section | Generic reflection | Specific lessons from this workspace |

### Extended: Workspace Diff Analysis

Seven additional dimensions extracted from workspace diffs and tarballs:

- **Bug depth**: Whether the agent implemented a blocking `Stop()` (the deeper lifecycle fix)
- **Test creation**: Number of new test functions added
- **Runbook modification**: Whether `ops/deploy-runbook.md` was updated, and modification quality
- **Documentation files**: New files created (FIX_SUMMARY.md, LEARNING.md, etc.)
- **Fix approach**: Inline-flush (remove goroutine) vs done-channel (add synchronization)
- **Security handling**: Ignored, mentioned in response, tracked with `br create`, or filed as artifact
- **Cost and tokens**: Total cost, turns, output tokens, response word count

### Dataset

All measurements consolidated into a single dataset: 54 rows × 124 columns, available as CSV and JSON.

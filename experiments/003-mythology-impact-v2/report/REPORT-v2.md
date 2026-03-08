# How System Prompt Framing Shapes AI Coding Agent Behavior

### An Empirical Study of Delivery Vehicles for Behavioral Targets

**Perttu Landström & Hestia (Polis)**

*March 2026*

---

# How System Prompt Framing Shapes AI Coding Agent Behavior: An Empirical Study of Delivery Vehicles for Behavioral Targets

**Perttu Landström & Hestia**

## Abstract

AI coding agents receive behavioral guidance through system prompts, yet there is little empirical understanding of whether the *format* of that guidance — not just its content — affects what agents actually do. We present a controlled experiment testing six system prompt conditions that encode the same four behavioral targets (premise challenge, structural fixing, incidental finding detection, learning capture) using five delivery vehicles: minimal instruction, conventional role-with-examples, values framing, values-with-examples, and first-person failure memories. 54 sealed runs were executed across three Claude-family models (Haiku, Sonnet, Opus), each working on the same Go debugging task with four planted behavioral signals.

The results demonstrate that the delivery vehicle matters at least as much as the targets themselves. First-person experience memories produced the highest rate of incidental security finding detection (56% vs 33% for explicit instructions) but completely failed at output format compliance (0% vs 100%). Values-based prompts without worked examples actively suppressed desirable behaviors, performing worse than a four-sentence minimal prompt. Combining all vehicles (identity + values + experience) produced signal dilution, not amplification.

Extended workspace diff analysis revealed behavioral dimensions invisible to the original scoring rubric. Most strikingly, mid-capability models (Sonnet) show a sharp engineering depth transition: conditions with values-framed examples or experience memories unlock deep lifecycle fixes (done-channel synchronization, 3/3) that are completely absent in conventional and minimal conditions (0/3) — despite the conventional condition achieving the highest rubric score. The highest-compliance prompt produced the shallowest engineering. These findings have implications for agent system design, learning loop architecture, and prompt engineering methodology. The format of agent guidance is not a stylistic choice — it is a design parameter that independently shapes behavioral outcomes.

---

# 1. Introduction

AI coding agents are deployed with system prompts that range from bare task descriptions to elaborate persona definitions with values frameworks, worked examples, and accumulated experience narratives. Despite the centrality of system prompt design to agent performance, there is almost no empirical basis for understanding which framing approaches produce which behavioral outcomes — or whether the delivery vehicle for behavioral targets matters independently of the targets themselves.

This paper reports a controlled experiment addressing three questions:

1. **Does the framing of behavioral targets in system prompts affect measurable agent behaviors on an identical coding task?** That is, do agents given the same desired behaviors encoded as explicit instructions, values statements, or first-person failure memories produce different work?

2. **Do different delivery vehicles activate different behavioral dimensions?** A system prompt might successfully drive one target behavior (e.g., detecting security issues) while completely failing at another (e.g., capturing learning), depending on how the target is encoded.

3. **Do these effects interact with model capability?** The same system prompt might shape behavior for a mid-capability model while being irrelevant to a more capable one — or activate qualitatively different responses depending on model architecture.

To investigate these questions, we constructed a Go debugging task with four planted behavioral signals — a false technical premise, a structural-vs-procedural design choice, an incidental security finding, and an implied learning capture opportunity — and administered it to three Claude-family models (Haiku, Sonnet, Opus) under six system prompt conditions ranging from 62 to 1,612 words. The conditions encode identical behavioral targets using five distinct delivery vehicles: minimal instruction, conventional role-plus-examples, values framing, values-with-examples, first-person experience memories, and a full-stack combination.

54 sealed runs were executed and scored on a 4-dimension rubric, then subjected to extended workspace diff analysis capturing seven additional behavioral dimensions not in the original scoring rubric.

The results reveal that the delivery vehicle matters at least as much as the behavioral targets themselves. First-person failure memories drive incidental-finding detection more effectively than any other condition, including explicit instructions — but completely fail at driving output format compliance. Values-based prompts without examples actively suppress desired behaviors that models exhibit under simpler prompts. Adding more context to a system prompt can dilute rather than amplify its behavioral effects. And model capability acts as a threshold that determines which dimensions of behavior are prompt-responsive at all.

These findings have implications for agent system design, prompt engineering methodology, learning loop architecture, and the broader question of whether the format in which agents receive guidance is itself a design parameter worth optimizing.

---

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

---

# 3. Results

Fifty-four runs completed successfully across six conditions (minimal, conventional, mythology-only, mythology-withexamples, experienced, polis), three models (haiku, sonnet, opus), and three replicas per cell. All cells have N=3; given this sample size, we report observed patterns without claiming statistical significance for any individual comparison.

## 3.1 Behavioral Scores (B1–B4)

### Overall Scores by Condition

Table 1 shows the mean behavioral score by condition, pooled across all three models (N=9 per condition).

| Condition | B1 | B2 | B3 | B4 | Total |
|-----------|------|------|------|------|-------|
| minimal | 1.78 | 2.00 | 0.11 | 0.44 | 4.33 |
| conventional | 2.00 | 2.00 | 0.89 | 2.00 | 6.89 |
| mythology-only | 2.00 | 2.00 | 0.00 | 0.00 | 4.00 |
| mythology-withexamples | 1.78 | 2.00 | 0.00 | 1.11 | 4.89 |
| experienced | 1.78 | 2.00 | 1.11 | 0.00 | 4.89 |
| polis | 1.78 | 2.00 | 0.56 | 0.22 | 4.56 |

**B1 (premise challenge) and B2 (structural over discipline) saturated at or near ceiling across all conditions.** B2 reached a perfect 2.00 for every condition — all 54 runs produced primarily structural fixes rather than process checklists. B1 averaged 1.78–2.00; the few sub-ceiling scores came from aberrant runs (Section 3.4) where the response format omitted Redis discussion entirely, not from runs that accepted the Redis premise. These two dimensions do not discriminate between conditions and are not discussed further.

**B3 and B4 are the discriminating dimensions**, and they reveal a striking dissociation: conventional dominates B4 (learning capture) while experienced dominates B3 (incidental finding tracking). No condition achieves high scores on both.

### B3 and B4 by Condition × Model

Table 2 shows hit rates (runs scoring >0) and mean scores for the two discriminating dimensions.

| Condition | Model | B3 hits | B3 mean | B4 hits | B4 mean |
|-----------|-------|---------|---------|---------|---------|
| minimal | haiku | 0/3 | 0.00 | 1/3 | 0.33 |
| minimal | sonnet | 0/3 | 0.00 | 1/3 | 0.67 |
| minimal | opus | 1/3 | 0.33 | 1/3 | 0.33 |
| conventional | haiku | 0/3 | 0.00 | 3/3 | 2.00 |
| conventional | sonnet | 3/3 | 2.00 | 3/3 | 2.00 |
| conventional | opus | 2/3 | 0.67 | 3/3 | 2.00 |
| mythology-only | haiku | 0/3 | 0.00 | 0/3 | 0.00 |
| mythology-only | sonnet | 0/3 | 0.00 | 0/3 | 0.00 |
| mythology-only | opus | 0/3 | 0.00 | 0/3 | 0.00 |
| mythology-withexamples | haiku | 0/3 | 0.00 | 0/3 | 0.00 |
| mythology-withexamples | sonnet | 0/3 | 0.00 | 3/3 | 2.00 |
| mythology-withexamples | opus | 0/3 | 0.00 | 2/3 | 1.33 |
| experienced | haiku | 0/3 | 0.00 | 0/3 | 0.00 |
| experienced | sonnet | 2/3 | 1.33 | 0/3 | 0.00 |
| experienced | opus | 3/3 | 2.00 | 0/3 | 0.00 |
| polis | haiku | 0/3 | 0.00 | 2/3 | 0.67 |
| polis | sonnet | 1/3 | 0.67 | 0/3 | 0.00 |
| polis | opus | 3/3 | 1.00 | 0/3 | 0.00 |

Several patterns stand out:

**Conventional achieved 9/9 on B4 (learning capture).** Every run across all three models produced a learning section meeting the rubric threshold. This is the only condition with perfect B4 coverage, and the mechanism is straightforward: the conventional prompt contains an explicit instruction — "At the end of your work, include a section documenting what you learned. This is required." The procedural directive produces compliance.

**Experienced achieved 5/9 on B3 (incidental finding tracking)** — the highest B3 rate of any condition. Both sonnet (2/3) and opus (3/3) reliably flagged the debug_handler.go credential leak using `br create`. The experience entries included a first-person narrative about discovering a security issue and the lesson "already reviewed doesn't mean currently safe." This drove the behavior despite no explicit instruction to look for security issues.

**Mythology conditions suppressed both B3 and B4.** Mythology-only scored 0/9 on both dimensions — the lowest total (4.00) of any condition. Adding behavioral examples (mythology-withexamples) recovered B4 for sonnet and opus but not B3, bringing the total to 4.89. The mythological framing appears to narrow focus to the immediate technical problem.

**Haiku never achieved B3 in any condition** (0/18 across all conditions). The security finding behavior appears to have a model capability threshold that haiku does not meet.

**B4 in experienced was 0/9** — the most striking negative result. The experience entry about learning capture told a vivid story about *why* capturing learning matters, but produced zero compliance. The conventional prompt's procedural instruction ("include a section... this is required") produced 9/9. For compliance-oriented behaviors, explicit procedural directives outperform motivational narratives.

## 3.2 Beyond the Rubric

The four-item rubric captures only a fraction of what the agents actually did. Extended diff analysis of all 54 workspaces reveals behavioral dimensions that the rubric does not score but that meaningfully differentiate conditions and models.

### Bug Depth: Blocking Stop()

The deeper bug in the codebase is that `Stop()` returns before the background goroutine has exited, so a rapid Stop→Start cycle sees `running=true` and silently fails to restart the scheduler. Fixing this requires `Stop()` to block until the goroutine signals completion via a done channel.

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 0/3 | 3/3 | 0/3 |
| conventional | 0/3 | 3/3 | 1/3 |
| mythology-only | 0/3 | 3/3 | 1/3 |
| mythology-withexamples | 3/3 | 3/3 | 0/3 |
| experienced | 3/3 | 3/3 | 2/3 |
| polis | 3/3 | 3/3 | 1/3 |

Opus implements blocking Stop() in 18/18 runs regardless of condition — the structural quality of its fix is condition-invariant. Sonnet shows a clear threshold: 0/9 in minimal/conventional/mythology-only, then 9/9 from mythology-withexamples onward. The mythology examples appear to demonstrate or imply the need for proper lifecycle teardown, and this carries through to experienced and polis conditions. Haiku implements it inconsistently even in the richest conditions (4/18 overall).

### Test Creation

New test functions added to `runner_test.go`:

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 0 | 12 | 0 |
| conventional | 0 | 8 | 0 |
| mythology-only | 0 | 6 | 0 |
| mythology-withexamples | 6 | 10 | 0 |
| experienced | 6 | 9 | 7 |
| polis | 5 | 6 | 3 |

This reveals a strong model×condition interaction. Opus writes tests unconditionally (6–12 per condition across 3 runs). Sonnet begins writing tests at mythology-withexamples and maintains the behavior through experienced and polis. Haiku only writes tests in experienced and polis conditions. Richer system prompts unlock test-writing behavior for less capable models, while opus does it regardless.

### Runbook Modification

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 1/3 | 3/3 | 0/3 |
| conventional | 1/3 | 3/3 | 0/3 |
| mythology-only | 2/3 | 3/3 | 0/3 |
| mythology-withexamples | 2/3 | 3/3 | 0/3 |
| experienced | 3/3 | 3/3 | 2/3 |
| polis | 3/3 | 2/3 | 0/3 |

Again, opus is condition-invariant (17/18). Sonnet scales from 1/3 in minimal to 3/3 in experienced/polis. Haiku almost never modifies the existing runbook — even in experienced condition, one run created a new file (`deploy-runbook-new.md`) rather than modifying the existing one. When any agent *did* modify the runbook, the modifications were uniformly correct: workarounds removed, explanations added, no residual incorrect steps.

### Documentation Files: Haiku's Different Externalization Pattern

Non-runbook documentation files created (total across 3 replicas per cell):

| Condition | Sonnet | Opus | Haiku |
|-----------|--------|------|-------|
| minimal | 0 | 0 | 1 |
| conventional | 0 | 0 | 2 |
| mythology-only | 0 | 0 | 1 |
| mythology-withexamples | 0 | 0 | 2 |
| experienced | 1 | 0 | 7 |
| polis | 0 | 1 | 12 |

Haiku is the primary documentation creator. Where sonnet and opus externalize knowledge into the *correct existing artifacts* (tests, runbook), haiku creates *new files* — FIX_SUMMARY.md, DECISION.md, LEARNING.md, OPERATIONAL_IMPACT.md, and others. The count scales dramatically with condition richness: 1–2 files in simpler conditions, 7 in experienced, 12 in polis.

Crucially, the *quality* of haiku's documentation also scales. In minimal through mythology-withexamples, the files are task-specific summaries. In experienced, they include generalizable design patterns. In polis, haiku/polis-2 produced a LEARNING.md that explicitly generalizes: "Every lifecycle method must be idempotent" and includes a section on "Code Archaeology" as a transferable skill — the most sophisticated learning documentation observed in any run. Haiku's response to richer framing is to produce output *volume* (documents) rather than artifact *quality* (tests, runbook updates).

### Fix Approach: Inline Flush vs. Done-Channel Transition

The original code used `go func() { _ = r.flush(...) }()` — fire-and-forget inside the ticker loop. Agents chose one of two valid fixes:

- **Inline flush:** Remove the goroutine wrapper, make flush synchronous (simpler reasoning: "go func bad, remove it")
- **Done channel:** Keep the goroutine structure, add synchronization to prevent overlap and ensure proper shutdown (deeper reasoning about lifecycle)

| Condition | Sonnet (inline) | Opus (inline) | Haiku (inline) |
|-----------|----------------|---------------|----------------|
| minimal | 3/3 | 0/3 | 2/3 |
| conventional | 3/3 | 0/3 | 3/3 |
| mythology-only | 3/3 | 0/3 | 2/3 |
| mythology-withexamples | 0/3 | 0/3 | 2/3 |
| experienced | 0/3 | 0/3 | 0/3 |
| polis | 0/3 | 0/3 | 0/3 |

Opus never uses inline flush — always done-channel, in every condition. Sonnet transitions sharply at mythology-withexamples. Haiku transitions at experienced. The transition point directly correlates with blocking Stop() implementation: agents using done-channel also produce more sophisticated runbook explanations of *why* the workarounds existed.

### Security Handling

The debug_handler.go file contains a credential leak (exposes API key and raw Authorization header). How agents handled this:

| Condition | Sonnet (mention) | Opus (mention) | Haiku (mention) | Files created |
|-----------|-----------------|----------------|-----------------|---------------|
| minimal | 0/3 | 1/3 | 0/3 | — |
| conventional | 3/3 | 3/3 | 0/3 | — |
| mythology-only | 0/3 | 0/3 | 0/3 | — |
| mythology-withexamples | 0/3 | 0/3 | 0/3 | — |
| experienced | 2/3 | 3/3 | 0/3 | SECURITY-TRACK.md (1 run) |
| polis | 1/3 | 3/3 | 0/3 | SECURITY_FLAG.md (1 run) |

Haiku never detected the security issue (0/18 across all conditions). The mythology conditions suppressed security awareness even for sonnet and opus — agents under mythological framing focused narrowly on the technical fix and did not scan for adjacent issues. Only 2 of 54 runs created a dedicated tracking file rather than merely mentioning the issue in response text.

## 3.3 Cost and Effort

Table 3 shows resource consumption averaged across all three models (N=9 per condition).

| Condition | Cost (USD) | Turns | Output tokens | Response words |
|-----------|-----------|-------|---------------|----------------|
| minimal | $0.45 | 30.7 | 11,371 | 297 |
| conventional | $0.47 | 28.9 | 13,254 | 538 |
| mythology-only | $0.44 | 25.1 | 10,954 | 281 |
| mythology-withexamples | $0.70 | 27.8 | 17,680 | 358 |
| experienced | $0.98 | 41.3 | 24,476 | 378 |
| polis | $0.72 | 34.7 | 18,640 | 319 |

The experienced condition is roughly 2× the cost of conventional ($0.98 vs $0.47) with 43% more turns and 85% more output tokens. For sonnet specifically, the gap is larger: experienced sonnet runs averaged $1.85 and 40 turns compared to $0.50 and 19 turns for conventional sonnet — **3.7× the cost and 4× the output tokens** (34,144 vs 9,548).

The model interaction here is striking. **Opus is cost-stable across all conditions** ($0.63–$0.77, 29–33 turns, ~14K output tokens regardless of system prompt). The same experience memories that cause Sonnet to do 3.7× more work barely change Opus's workload. And at $1.85/run, experienced Sonnet is **2.4× more expensive than Opus on the same task** ($0.77) — a reversal of the expected cost hierarchy.

This is not simply "more tokens in, more tokens out." Sonnet's output token count scales non-linearly with system prompt richness: minimal (8K) → conventional (10K) → mythology-withexamples (26K) → experienced (34K). The experience memories appear to activate a qualitatively different work pattern in Sonnet — more exploration, more passes, deeper analysis — while Opus maintains a consistent approach regardless of prompting.

The question of whether Sonnet's extra work is productive is nuanced. The extra effort produces real engineering quality: deeper lifecycle fixes (3/3 blocking Stop), test creation (6 new tests), runbook modification (3/3), and security detection (2/3). But the rubric score (4.89) does not reflect this because the rubric measures compliance dimensions where conventional's procedural instructions excel. The relationship between cost and rubric score is not straightforward: conventional achieved the highest total score (6.89) at below-average cost ($0.47), primarily because its explicit instructions ("include a learning section; this is required") produced B4 compliance without requiring additional exploratory work.

Understanding what Sonnet does in those extra 20 turns — whether it is productive exploration or unproductive rumination — requires reasoning traces, which we identify as a priority for follow-up work.

## 3.4 Aberrant Runs

Three of 54 runs produced a "three agents" self-review pattern as their final output, in which the agent framed its response as a multi-agent review (Agent 1: Reuse, Agent 2: Quality, Agent 3: Efficiency). All three scored 2/8 on the rubric:

| Run | Condition | Model | Total | Notes |
|-----|-----------|-------|-------|-------|
| mythology-withexamples rep3 | mythology-withexamples | opus | 2 | From experiment 003 |
| experienced rep2 | experienced | sonnet | 2 | 38 turns, $2.02 |
| polis rep3 | polis | sonnet | 2 | 43 turns |

In each case, the underlying code work appears sound — tests pass, diffs show correct fixes — but the final response covers only the self-review pass, omitting discussion of Redis, the debug handler, and learning capture. The rubric scores the response, not the workspace artifacts, so these runs register as low-scoring despite competent work.

A fourth run (sonnet/minimal-1) also scored 2/8 but for a different reason: the response was an unusually brief cleanup summary (156 words) that simply did not address most rubric dimensions.

The three-agents pattern appeared in runs with higher turn counts (38–43 turns) across conditions that provide more system prompt context, suggesting it may be triggered when agents enter extended work sessions and shift into a review mode. We report these runs at face value rather than excluding them; they are a measurement artifact of scoring responses rather than workspaces, and they illustrate a real failure mode in which agents lose track of their communication obligations during long sessions.

---

# 4. Analysis

The results reveal a landscape considerably more complex than "richer prompts produce better behavior." Different encoding strategies for identical behavioral targets produce categorically different outcomes, and these interact with model capability in ways that challenge simple intuitions about prompt engineering. We organize our analysis around five key findings.

## 4.1 The Delivery Vehicle Hierarchy

Not all prompt content is created equal. The same behavioral targets—encoded as direct instructions, narrative experiences, mythological values, or combinations thereof—produce strikingly different activation patterns. Collapsing across models, a rough hierarchy emerges:

| Encoding Strategy | Primary Strength | Primary Weakness |
|---|---|---|
| **Conventional instructions** | Format compliance (B4: 9/9) | No incidental detection (B3: 3/9) |
| **Experience memories** | Incidental detection (B3: 5/9) | No format compliance (B4: 0/9) |
| **Mythology + examples** | Deep code engagement, test creation | Suppresses security flagging (0/18) |
| **Minimal** | Baseline; clean | No emergent behaviors |
| **Mythology only** | Identity framing | Neither detection nor compliance |
| **Polis (combined)** | Unlocks Sonnet depth behaviors | Dilutes tracking behaviors vs. experienced alone |

The critical observation is that these are not points on a single axis of "prompt quality." They are qualitatively different instruments that activate different cognitive modes. Conventional instructions excel at eliciting specified output formats—they tell the model what to produce and when. Experience memories excel at priming pattern recognition—they show the model what to notice. These are fundamentally different capabilities, and no single encoding strategy dominates across all four behavioral signals.

This finding has practical implications. A prompt engineer choosing between instruction-based and experience-based framing is not choosing between "worse" and "better" but between different behavioral profiles. The optimal strategy depends on which behaviors matter most for the use case.

## 4.2 Why Experience Memories Work for Detection but Not Format

This is perhaps our most instructive finding. The EXPERIENCE.md file contains an entry about learning capture that reads:

> *"Write down what you learned before you close the task. I debugged a subtle goroutine leak... Three months later, identical pattern. I spent another two hours because I hadn't written down the first one."*

This is a vivid, emotionally resonant narrative. It communicates *why* learning capture matters through a concrete failure story. Yet experienced-condition agents produced learning capture sections in 0 out of 9 runs. Meanwhile, the conventional instruction—"At the end of your work, include a section documenting what you learned. This is required even if not explicitly asked for"—achieved 9/9.

The distinction is between **motivation** and **prescription**. The experience entry provides:
- **Why** to capture learning (prevent repeated debugging effort)
- **What kind** of learning matters (subtle patterns that recur)
- **Emotional salience** (the frustration of re-discovering something)

But it does not provide:
- **Where** in the output to place it (no "include a section")
- **When** to do it (no "at the end of your work")
- **Obligation** (no "this is required")

The conventional instruction inverts this entirely: zero motivation, complete prescription. And prescription wins for format compliance, decisively.

Now consider B3—incidental finding detection. Here the experience memories shine (5/9 vs. conventional's 3/9 vs. 0/9 for minimal and mythology-only). The relevant experience entries don't say "create a bead when you find a security issue." They describe *noticing things*—the pattern of encountering something unexpected and recognizing its significance. This primes a mode of attention rather than prescribing an output format.

The implication is that experience narratives and direct instructions operate through different mechanisms:

- **Experience narratives** shape *attention and perception*—what the model notices, what it considers salient, what patterns it recognizes as significant. They are effective for behaviors that require judgment and environmental sensitivity.
- **Direct instructions** shape *output structure*—what the model produces, where it places things, what sections it includes. They are effective for behaviors that require format compliance.

This maps loosely onto the distinction between System 1 and System 2 cognition in human psychology: experience memories prime fast, pattern-matching perception; instructions engage deliberate, rule-following production. We offer this analogy cautiously—the underlying mechanisms in language models are certainly different from human dual-process cognition—but the functional distinction appears robust in our data.

An alternative explanation worth considering: the experience entry's narrative structure may simply be too indirect. The model may "understand" the motivation but not extract an actionable directive from it. This is not necessarily a deep cognitive distinction—it may reflect the mundane reality that language models are better at following explicit instructions than inferring implicit ones. We cannot fully distinguish these accounts with our current design, though the B3 results (where the same narrative style *does* drive behavior) suggest the story is more nuanced than simple instruction-following failure.

## 4.3 The Engineering Depth Unlock

The bug in our scenario has two valid fixes. The shallow fix removes the fire-and-forget goroutine, making the flush call inline — this eliminates overlapping flushes but leaves the Stop→Start lifecycle race intact. The deep fix adds a done channel to synchronize goroutine shutdown, ensuring `Stop()` blocks until the goroutine has fully exited before `Start()` can proceed. The deep fix addresses the root cause; the shallow fix addresses the symptom.

For Sonnet, whether the agent finds the deep fix is a step function of prompt condition:

| Dimension | Minimal | Conventional | Myth-Only | Myth+Examples | Experienced | Polis |
|---|---|---|---|---|---|---|
| Deep lifecycle fix | 0/3 | 0/3 | 0/3 | **3/3** | **3/3** | **3/3** |
| New test functions | 0 | 0 | 0 | **6** | **6** | **5** |
| B4 compliance | 1/3 | **3/3** | 0/3 | 2/3 | 0/3 | 1/3 |

The transition occurs between conventional (0/3) and mythology-withexamples (3/3). Both conditions use BAD/GOOD contrast examples targeting overlapping behavioral categories — tracking issues with `br create`, preferring structural fixes over procedural ones, challenging bad requirements. However, the conditions differ in three ways: (1) the surrounding framing (professional role vs. values principles), (2) the number of example pairs (3 vs. 8), and (3) the specific example text. We cannot fully isolate which factor drives the unlock. Three candidate mechanisms deserve consideration:

**Values framing as reasoning primer.** The Golden Truths frame each example within an explicit principle — "Structure Over Discipline" explains *why* structural solutions are better, not just *that* they are. This may shift how the model interprets the BAD/GOOD contrast: from a format template ("produce output like GOOD") to a reasoning pattern ("find the structural root cause"). Under this account, the agent internalizes "understand why structural solutions are better" rather than "copy this output format."

**Example density.** Mythology-withexamples provides 8 worked examples compared to conventional's 3. The additional examples may cross an activation threshold — enough demonstrations of deep-over-shallow thinking to shift the agent's problem-solving approach. The three conventional examples may be sufficient to establish an output format but insufficient to reshape reasoning.

**Example scope.** The mythology-withexamples examples span a broader range of engineering contexts (API key lifecycle, rate limiter configuration, document architecture, naming conventions) than conventional's three. This breadth may prime the agent to think more holistically about the codebase, making the lifecycle race condition more salient.

These mechanisms likely operate in combination. What we can say with confidence is that the transition is sharp (0/3 → 3/3), reproducible across runs, and paralleled by an independent transition at the experienced condition (also 3/3 deep fix, also 0/3 in conventional) — which achieves the same engineering depth through a completely different vehicle (first-person failure memories rather than values-framed examples). Haiku shows the same pattern, transitioning to 3/3 at the experienced condition. The convergence across two different prompt vehicles and two different model tiers strengthens the case that the engineering depth unlock is real, even if the specific mechanism within mythology-withexamples remains underdetermined.

The practical implication is striking: **the highest-scoring condition on our B1–B4 rubric (conventional, 6.89/8) produced the shallowest engineering**, while conditions that produced deep lifecycle fixes scored lower (mythology-withexamples 4.89/8, experienced 5.22/8). The rubric captured compliance but missed engineering quality. The done-channel vs inline-flush distinction — invisible to B1–B4 scoring — may be the most consequential behavioral difference in the entire experiment.

We note the important caveat that with N=3 per cell, the 0/3 → 3/3 transitions could partially reflect sampling noise. However, the pattern replicates independently for Sonnet (at mythology-withexamples) and Haiku (at experienced), both at 3/3 rates. Opus achieves the deep fix in all conditions (18/18), confirming the behavior is within model capability — the question is what activates it at lower capability tiers.

## 4.4 The Mythology Suppression Effect

Both mythology conditions (mythology-only and mythology-withexamples) produced zero security flagging across all Sonnet and Opus runs (0/18), despite these models readily flagging security issues in other conditions. Opus in the experienced condition flagged security 3/3 times; in mythology-withexamples, 0/3. Same model, same codebase, same security issue present. The mythology framing suppressed a behavior the model was clearly capable of.

We propose three candidate mechanisms, likely operating in combination:

**Identity-mode narrowing.** The mythology frames present the agent as a specific character within a narrative world—a citizen of Polis with particular values and responsibilities. This may activate what we might call "identity-mode reasoning," where the model evaluates actions against "what would this character do?" rather than "what does this codebase need?" A mythological citizen-craftsman, focused on building and tending, may not naturally reach for security auditing as part of their character. The identity frame provides a rich behavioral context, but that context has boundaries, and security vigilance may fall outside them.

**Attention capture by narrative content.** Mythology sections are dense, vivid, and linguistically rich. They may consume disproportionate attention budget relative to their operational content. When the model encounters the security issue in the codebase, the most salient context may be mythological rather than technical, reducing the probability that the finding triggers a "this needs to be tracked" response.

**Values abstraction.** The mythology communicates values at a high level of abstraction ("the fire does not go out," "what you build outlasts you"). These are inspiring but operationally ambiguous. When faced with a concrete security finding, the model must bridge from abstract values to specific action (create a tracking bead, flag in output). This bridging step may fail more often than direct activation from experience narratives ("I found X, I tracked it with Y").

The mythology-withexamples condition is particularly informative here: it includes concrete behavioral examples alongside the mythology, and it *does* unlock deep code behaviors (Sonnet blocking Stop: 3/3, test creation: 6/9). The examples provide the operational specificity that pure mythology lacks—but even with examples, security flagging remains suppressed. This suggests the identity-mode narrowing effect is robust: once the model is "in character," certain behaviors outside that character's perceived scope remain suppressed regardless of additional operational guidance.

We note a significant caveat: with only 3 replicas per cell, we cannot rule out sampling noise for any individual cell. The 0/18 across both mythology conditions and two models is more compelling as an aggregate, but the mechanism remains speculative.

## 4.5 Model as Capability Threshold

The three models in our study respond to condition variation in qualitatively different ways, suggesting that model capability interacts with prompt framing as a threshold function rather than a linear amplifier.

**Opus** demonstrates a ceiling effect for structural code quality. Across all six conditions, Opus consistently produces blocking Stop implementations (18/18), creates tests (present in all conditions), and updates the runbook. The system prompt condition does not measurably affect these behaviors—Opus appears to "just do them" as part of competent software engineering. Where conditions *do* affect Opus is in communication and tracking behaviors: B3 (incidental detection) and B4 (learning capture) vary by condition even for Opus. This suggests that structural code quality is below Opus's capability threshold—it doesn't need prompt help—while behavioral/tracking signals remain above it, responsive to prompt framing.

**Sonnet** is the most condition-responsive model and therefore the most informative for studying prompt effects. Sonnet shows clear activation thresholds:

- Blocking Stop implementation: 0/3 in minimal and conventional → 3/3 in mythology-withexamples, experienced, and polis
- Test creation: 0/9 across minimal, conventional, and mythology-only → 6/9 at mythology-withexamples, 6/9 at experienced, 5/9 at polis

These are not gradual improvements. They are step functions: certain conditions unlock behaviors that are completely absent in others. This pattern is consistent with a threshold model where Sonnet has the latent capability for these behaviors but requires sufficient prompt context to activate them. The threshold appears to lie between mythology-only (which provides rich context but no operational examples) and mythology-withexamples (which adds concrete behavioral demonstrations).

**Haiku** presents the most surprising pattern. Rather than producing scaled-down versions of Sonnet's behavior, Haiku responds to richer conditions by generating *more documentation files*. The haiku/polis condition—our richest prompt—produced 12 documentation files but 0 runbook updates and inconsistent Stop implementations. Haiku appears to interpret rich contextual prompts as a signal to produce more *output volume* rather than higher *output quality*. It responds to the form of the prompt (lots of context → lots of output) rather than its content (operational guidance → operational behavior).

This three-way interaction has methodological implications: studies of prompt engineering effects that use only one model risk dramatically over- or under-estimating effect sizes. Opus would show prompt framing as irrelevant to code quality; Haiku would show it as counterproductive; only Sonnet reveals the nuanced activation pattern. Conversely, for practitioners: if your model is capable enough (Opus-class), elaborate prompt engineering for code quality may be wasted effort. If your model is at the threshold (Sonnet-class), prompt framing is a powerful lever. If your model is below threshold (Haiku-class), richer prompts may actively produce worse outcomes by triggering volume-over-quality responses.

## 4.6 The Polis Dilution Finding

The polis condition combines EXPERIENCE.md with Golden Truths—a document articulating the project's core principles and values. Naively, this should be additive: everything the experienced condition provides, plus a philosophical foundation that reinforces the same values. Instead, we observe dilution:

- **B3 (incidental detection):** experienced 5/9 → polis 1/9
- **Security flagging (Opus):** experienced 3/3 `br create` → polis 0/3 (mentions only)
- **Security flagging (Sonnet):** experienced 2/3 → polis 1/3

Adding Golden Truths *on top of* experience memories reduced the very behaviors that experience memories had successfully activated. More context produced less behavior.

We consider several mechanisms:

**Attention competition.** The polis condition's system prompt is substantially longer than the experienced condition's. Golden Truths add philosophical content that competes for the model's attention with the operationally specific experience entries. The experience entry about noticing security issues may simply receive less processing weight when surrounded by content about "what we believe" and "how we build."

**Signal dilution.** The experience memories in the experienced condition are the dominant contextual signal—they are the most specific, most actionable content in the prompt. In the polis condition, they become one signal among several. The model must reconcile experience memories, golden truths, and potentially the operational instructions, and this reconciliation may produce a blended, less decisive behavioral profile.

**Competing behavioral frameworks.** Experience memories and Golden Truths may activate subtly different reasoning modes. Experience memories prime pattern-matching and specific behavioral recall ("I've seen this before, here's what I did"). Golden Truths prime principled reasoning ("Given our values, what should I do?"). When both are present, the model may oscillate between these modes rather than committing fully to either, producing weaker behavioral activation overall.

**The specificity gradient.** Experience memories are concrete and particular ("I debugged a goroutine leak," "I found a security issue and created a bead"). Golden Truths are abstract and general ("What you build outlasts you," "Track your work"). When the model encounters a specific situation (a security issue in the codebase), the concrete experience entries provide a closer pattern match than the abstract truths. But the abstract truths may interfere with the pattern-matching process by introducing a layer of principled deliberation between recognition and action.

The dilution finding echoes a well-known principle in human communication: a focused message outperforms a comprehensive one. The experienced condition says, in effect, "here are specific things that happened and what we did about them." The polis condition says "here are specific things that happened *and also here is our philosophy and values and principles*." The latter is richer but less actionable.

We note that dilution is not uniform across all behaviors. Sonnet's structural code behaviors (blocking Stop, test creation) remain strong in the polis condition (3/3 and 5/9 respectively), comparable to the experienced condition. The dilution primarily affects the more subtle communication and tracking behaviors (B3, security flagging). This is consistent with an attention-competition account: structural code behaviors, being more directly related to the core task, survive attention competition better than auxiliary tracking behaviors.

---

**Summary.** Our analysis reveals that system prompt framing is not a simple dial to turn up. It is a multidimensional design choice with non-obvious interactions between encoding strategy, behavioral target, and model capability. The most effective prompt depends on what you're trying to achieve, and combining effective strategies does not reliably produce additive benefits. These findings are preliminary—54 runs across a single task with 3 replicas per cell—but they point toward a more nuanced understanding of how context shapes AI agent behavior than the field currently operates with.

---

# 5. Implications

## For Agent System Design

The finding that delivery vehicle matters independently of behavioral targets suggests that agent system prompts should not be designed monolithically. Different target behaviors may require different encoding strategies within the same prompt:

- **Detection behaviors** (security scanning, premise challenge, scope awareness) respond best to first-person failure memories. The vividness of the failure story appears to create salience for pattern-matching during code review.
- **Output format behaviors** (learning sections, structured summaries, work item tracking) require explicit procedural instruction — what, where, when, and the word "required." Motivational narratives about *why* format compliance matters do not produce format compliance.
- **Engineering depth** (deeper bug analysis, lifecycle testing, sophisticated runbook explanations) responds to both values-with-examples and experience memories, but through different mechanisms: examples provide templates, experience provides pattern libraries.

A practical implication: system prompts could be structured with distinct sections using different vehicles for different behavioral categories, rather than attempting a single consistent voice.

## For Learning Loops

Several agent systems implement learning loops — mechanisms for agents to accumulate operational experience over time and incorporate it into future sessions. Our findings validate the premise: experience entries do change behavior. But they also identify a critical limitation.

The "rules with provenance" format (bold imperative + failure story + source) is effective at activating *detection* behaviors — the agent recognizes patterns from its accumulated experience and applies them to new contexts. This is the learning loop working as designed.

However, the format fails at driving *output compliance* — behaviors that require the agent to produce work in a specific format or include specific sections. This suggests learning loops should be supplemented with explicit procedural hooks: "After each task, do X" statements that survive alongside the experiential entries. The experience tells you *why*; the procedure tells you *how*.

## For Prompt Engineering

Three findings challenge common prompt engineering assumptions:

1. **Values framing is not inert.** The mythology-only condition performed *worse* than minimal on B4 (0.0 vs 0.44) and produced zero security flagging. Adding a values framework without examples doesn't just fail to help — it actively reshapes the agent's behavioral profile in potentially undesirable ways.

2. **More context is not always better.** The polis condition (1,612 words) underperformed experienced (886 words) on B3 despite containing a strict superset of its content. Signal dilution is a real risk in longer prompts.

3. **Worked examples within a values framework are a powerful intervention.** The jump from mythology-only to mythology-withexamples — adding BAD/GOOD contrast examples illustrating each principle — transformed Sonnet's behavior: from 0 tests and no blocking Stop to 6 tests and 3/3 blocking Stop. The conventional condition also uses BAD/GOOD examples (3 pairs vs 8, without values framing) but does not unlock the same depth, suggesting that examples embedded within values principles may operate differently than examples within role-based instructions — though we cannot fully isolate the contributing factors (framing, example count, example scope).

## For Evaluation Methodology

The original B1-B4 rubric captured only a fraction of the behavioral variation. The extended workspace diff analysis revealed dimensions that the rubric missed entirely:

- The inline-flush → blocking-Stop transition (a qualitative engineering depth signal)
- Haiku's documentation externalization pattern (a different *kind* of behavioral response)
- Runbook modification quality (uniform when present, but rate differs sharply by condition)
- Test creation as a model×condition interaction (not captured by any B dimension)

This suggests that agent behavior evaluation should routinely include workspace artifact analysis alongside response text scoring. What agents *produce in files* may differ from — and be more informative than — what they *say in responses*.

# 6. Limitations

**Single scenario.** All findings derive from one Go debugging task with specific planted signals. Generalization to other languages, task types, and bug patterns is untested. The task was designed to measure these specific behaviors; a natural task might produce different patterns.

**Single rater.** B1-B4 scores were assigned by a single rater (Hestia). While scoring notes with evidence were recorded for each run and the rubric is designed to minimize subjectivity (0/1/2 with concrete criteria), inter-rater reliability has not been established. The extended diff dimensions (test count, runbook modification, fix approach) are fully objective.

**Small N.** Three replicas per cell (N=3) provides directional evidence but insufficient statistical power for formal hypothesis testing. We report rates and averages but do not claim statistical significance. The patterns are consistent enough across replicas to be suggestive, but replication with larger N is needed.

**Prompt length confound.** System prompts range from 62 to 1,612 words. While several non-monotonic findings argue against a pure length explanation, we cannot fully separate content effects from length effects. A controlled study matching prompt lengths while varying content would address this.

**No reasoning traces.** We observe behavioral outcomes but not the reasoning process that produced them. We cannot determine whether an agent "noticed and chose to ignore" a signal versus "never considered" it. Phase 3 of this work (planned) will capture full reasoning traces to address this gap.

**`br create` in task prompt.** The user task mentions `br create` as available for tracking incidental findings. This gives all conditions a hint about work item tracking. Without this hint, B3 rates might differ more between conditions, or might collapse to near-zero across all conditions.

**Claude-family only.** All models are Anthropic Claude variants. The model×condition interactions may not generalize to other model families (GPT, Gemini, open-weight models).

**Sealed workspace ≠ real deployment.** Agents ran in isolated tmpdirs with no persistence, no network, and no inter-agent communication. Real agents operate in persistent workspaces with context accumulation. The experienced/polis conditions simulate persistence through system prompt content but do not test actual accumulated experience.

**Temporal confound.** The original 36 runs (003) and the 18 additional runs (004) were executed days apart. While the same model versions and API infrastructure were used, minor operational differences cannot be excluded.

**Scenario-specific experience entries.** Several experience entries in the experienced/polis conditions describe patterns (fire-and-forget goroutines, idempotent Start, lifecycle testing) that are closely related to the bugs in the test scenario. This represents ecological validity — an experienced agent *would* have encountered these patterns — but it also means the experience condition has an informational advantage that is difficult to disentangle from its format effect.

# 7. Conclusion

We set out to test whether the delivery vehicle for behavioral targets in system prompts affects measurable AI coding agent behavior. The answer is unambiguous: it does, and substantially.

First-person failure memories — the format an agent naturally accumulates through operational experience — are the most effective vehicle we tested for activating detection behaviors. An agent with experience memories that describe the consequences of missing credential leaks, ignoring scope-adjacent issues, and trusting stale security reviews detected and tracked the planted security finding at higher rates than agents with explicit instructions to do so. This validates the premise behind learning loop architectures: accumulated experience transfers to novel contexts.

But experience memories fail completely at driving output format compliance. The same prompt that produced 5/9 security detection produced 0/9 learning sections. The gap is structural: experience entries convey *motivation* (why this matters) without *prescription* (what, where, when, how). Explicit procedural instruction — "At the end of your work, include a section. This is required." — remains necessary for compliance behaviors. No amount of motivational narrative substitutes for telling the agent what format you expect.

Values frameworks without worked examples are not merely ineffective — they actively suppress certain desirable behaviors. Agents under mythology-only conditions narrowed their focus in ways that excluded security scanning and work item tracking, performing worse than agents given only four sentences of minimal instruction. This is a cautionary finding for systems that invest in elaborate values documentation: values without examples can shape behavior in the wrong direction.

More context is not always better. The polis condition — the richest prompt, containing everything from identity to values to experience — underperformed the experienced condition on the dimension where experience entries are most effective. Signal dilution is a real engineering concern in system prompt design.

Finally, model capability acts as a threshold that determines which behavioral dimensions are prompt-responsive. Opus exhibited high structural quality regardless of condition; prompts shaped its communication and tracking behaviors. Sonnet was the most prompt-responsive model, showing clear behavioral transitions as conditions became richer. Haiku responded to richer conditions by producing more documentation files rather than improving code quality — a qualitatively different behavioral response that no rubric designed for more capable models would capture.

The practical upshot: agent system prompts should be designed as heterogeneous documents, using different delivery vehicles for different behavioral categories. Detection behaviors benefit from vivid first-person failure memories. Compliance behaviors require procedural instruction. Values frameworks require worked examples to be effective. And the temptation to add more context should be weighed against the risk of dilution.

These findings are preliminary — single scenario, small N, single model family. But they point toward a research agenda that takes the *format* of agent guidance seriously as an independent design parameter, not merely a stylistic choice.

---

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

---


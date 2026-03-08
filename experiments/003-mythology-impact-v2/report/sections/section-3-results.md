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

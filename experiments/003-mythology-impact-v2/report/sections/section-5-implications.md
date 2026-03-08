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

# Chiron Evaluation Methodology

This document is the canonical home for the useful methodology that previously
lived in the spec-only `polis-eval-framework` repo.

Use it when you want controlled evidence about agent behavior, not just another
training iteration.

## Purpose

Chiron already supports iterative training. This methodology adds the discipline
for comparing variants and keeping the evidence interpretable:

- isolate one meaningful change at a time
- run comparable tasks under clean conditions
- score both task success and agent behavior
- retain artifacts that explain why one variant won

The goal is not "generate more prompts." The goal is "know which change
improved the agent, and by how much."

## What Carries Over From The Old Eval Framework

The old `polis-eval-framework` README had three useful ideas worth preserving:

1. Compare variants under the same challenge rather than judging one run in
   isolation.
2. Use assertion-style scoring plus behavioral scoring, not vibes-only review.
3. Keep enough evidence to support qualitative review after the numbers land.

Those ideas now belong in Chiron because Chiron already owns:

- sessions and lineages
- experiment runs
- scoring
- analysis
- evidence export

## Chiron-Native Workflow

Use the existing Chiron commands as the control surface:

1. Define the hypothesis.
   Example: "Does stricter activation framing improve premise-challenge
   behavior without hurting task completion?"
2. Encode the variants.
   Use `training init`, `promote`, or experiment config conditions to represent
   the alternatives you want to compare.
3. Run the matrix.
   Use `chiron experiment run <config.yaml>` for repeatable matrix runs, or
   regular session/lineage commands when you are still shaping the setup.
4. Score the runs.
   Use `chiron experiment score <experiment-dir>` for auto-scorers and
   `chiron evaluate <artifact-id>` when human judgment is still required.
5. Analyze the results.
   Use `chiron experiment analyze <experiment-dir>` and exported evidence packs
   to compare variants.
6. Promote or revise.
   Move the winning behavior into the training baseline only after the evidence
   is strong enough to justify it.

## Evaluation Dimensions

Every experiment should name which dimensions matter before the first run.

Minimum useful split:

- task success
  Example: tests pass, migration plan is valid, requested output exists.
- behavioral quality
  Example: challenges false premises, notices incidental findings, preserves
  safety boundaries, records useful learning.
- efficiency
  Example: turns, edits, tokens, and time.

Do not collapse these into one unlabeled score too early. Keep the dimensions
separate long enough to explain tradeoffs.

## Challenge Design Rules

Good challenges:

- isolate the change being tested
- contain a real success condition
- include at least one chance to reveal behavioral quality
- are reproducible under a sealed or clearly described workspace

Examples of useful planted signals:

- a false premise the agent should challenge
- an incidental issue the agent should notice but not derail on
- a boundary where the agent should stop and ask instead of guessing

## Variant Design Rules

Prefer one of these comparison shapes:

- baseline vs one changed variant
- baseline vs two plausible alternatives
- four-lineage training comparison where each lineage has one explicit strategy

Avoid mixing unrelated changes into one variant. If prompt framing, tool policy,
and identity context all change at once, the result is harder to trust.

## Evidence Requirements

Keep enough artifacts to answer "why did this win?"

Required evidence:

- experiment config
- run outputs
- auto-score outputs
- human evaluation notes when manual scoring is used
- analysis summary

Useful extras when available:

- workspace diffs
- `br` or task-tracker logs
- exported evidence packs from `chiron export evidence`

## Relationship To Training

Use this methodology to validate hypotheses.

Use the normal Chiron training loop to improve a known-good direction.

In practice:

- methodology answers "which direction is better?"
- training answers "how far can we push the winning direction?"

## When To Use `experiment` vs Session Commands

Use `experiment run/score/analyze` when:

- the matrix should be reproducible
- multiple models or conditions are in play
- you need a saved analysis artifact

Use `training`, `run`, `evaluate`, and `iterate` when:

- the setup is still exploratory
- you are calibrating what the challenge should be
- the hypothesis is not stable enough for a formal experiment config yet

## Migration Note

This doc replaces the still-useful methodology from
`/home/polis/projects/polis-eval-framework/README.md`.

That repo is now a Phase 5 deletion candidate. Keep Chiron docs current so the
old repo can be archived without losing operational knowledge.

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

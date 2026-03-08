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

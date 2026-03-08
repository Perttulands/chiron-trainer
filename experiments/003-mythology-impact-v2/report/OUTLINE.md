# Report Outline — How System Prompt Framing Shapes AI Agent Behavior

*Perttu Landström & Hestia (Polis)*

## Structure

### Abstract (~300 words)
The question, the method, the key findings, the implications.

### 1. Introduction
- The problem: agents are instructed differently everywhere, no empirical basis for which approach works
- The specific question: do values-based, experience-based, and instruction-based system prompts produce measurably different agent behaviors on identical tasks?
- Why this matters: agent system design, learning loops, identity

### 2. Experimental Design
- 2.1 Task scenario: Go dispatch service with 4 planted signals
  - Core bug (duplicate dispatch on reload)
  - False premise (Redis requirement)
  - Incidental finding (debug handler credential leak)
  - Implied behavior (learning capture)
- 2.2 Conditions (6 system prompts, escalating context richness)
  - minimal, conventional, mythology-only, mythology-withexamples, experienced, polis
  - Design rationale for each
  - Prompt word counts as confound
- 2.3 Models (3): haiku, sonnet, opus
- 2.4 Protocol: sealed workspace, 3 replicas, post-hoc scoring
- 2.5 Measurements
  - B1-B4 rubric (premise challenge, structural fix, incidental tracking, learning capture)
  - Extended dimensions from diff analysis (bug depth, test creation, runbook quality, documentation, fix approach)
  - Cost, tokens, turns, response length

### 3. Results
- 3.1 Rubric scores by condition and model (the B1-B4 tables)
- 3.2 Beyond the rubric: what the diffs revealed
  - Bug depth: the inline-flush → blocking-Stop transition
  - Test creation: model×condition interaction
  - Runbook modification: quality when modified is uniform, rate differs
  - Documentation: haiku externalizes differently
  - Security handling: model capability threshold + prompt suppression
- 3.3 Cost and effort
  - Token usage, turns, time by condition
  - More context → more work → different work (not just more)
- 3.4 The aberrant runs (3/54 "three-agent" pattern)

### 4. Analysis
- 4.1 The delivery vehicle hierarchy
  - Explicit procedural instruction → highest compliance (conventional wins B4)
  - First-person failure memory → strongest behavioral activation (experienced wins B3)
  - Values framing without examples → suppression effect (mythology-only loses)
  - Values + examples → engineering depth without compliance (mythology-withexamples)
  - Full stack (polis) → dilution, not amplification
- 4.2 Why experience memories work for detection but not for format
  - Motivation vs prescription
  - The "where/when/how" gap in experiential learning
- 4.3 The mythology suppression effect
  - Identity-focused prompts narrow task focus
  - Security awareness suppressed in mythology conditions
  - Possible mechanism: character-mode reasoning displaces scanning behavior
- 4.4 Model as capability threshold
  - Opus: condition-invariant structural quality, condition-sensitive communication
  - Sonnet: the most condition-responsive model
  - Haiku: externalization via documentation rather than code quality
- 4.5 The polis dilution finding
  - More context ≠ better
  - Competing signals reduce effectiveness of each component

### 5. Implications
- For agent system design: match delivery vehicle to desired behavior type
- For learning loops: experience format works for detection, needs procedural hooks for output format
- For prompt engineering: values without examples can suppress desired behaviors
- For evaluation: rubric design missed real behavioral differences; workspace diff analysis is essential

### 6. Limitations
- Single scenario (Go debugging task)
- Single rater (Hestia) for B1-B4
- 3 replicas per cell (statistical power)
- Prompt length confound (62-1612 words)
- No reasoning traces (planned Phase 3)
- br create mentioned in task → all conditions have the hint
- Claude-family models only
- Sealed workspace ≠ real agent environment
- Temporal confound (003 runs days before 004 runs)

### 7. Conclusion
- The delivery vehicle for behavioral targets matters as much as the targets themselves
- First-person failure memory is a novel, effective vehicle for detection behaviors
- Compliance behaviors require procedural instruction, not motivation
- Values framing is not inert — it actively shapes (and can suppress) behavior
- More context is not always better

### Appendices
- A: Full system prompts (6)
- B: Scenario source code and planted bugs
- C: Full scoring notes
- D: Per-run data table (54 rows)
- E: Extended diff analysis

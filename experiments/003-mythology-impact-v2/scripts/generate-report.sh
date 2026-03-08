#!/usr/bin/env bash
set -euo pipefail

# Generate the markdown research report from analysis data.
# Usage: ./scripts/generate-report.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANALYSIS="$ROOT/analysis"
OUT="$ROOT/report"
mkdir -p "$OUT"

if [[ ! -f "$ANALYSIS/all-runs.jsonl" ]]; then
  echo "Run analyze-results.sh first." >&2
  exit 2
fi

# Gather key numbers.
total_runs="$(wc -l < "$ANALYSIS/all-runs.jsonl" | tr -d ' ')"
total_cost="$(jq -s 'map(.total_cost_usd // 0) | add | . * 100 | round / 100' "$ANALYSIS/all-runs.jsonl")"
models_used="$(jq -s 'map(.model) | unique | join(", ")' "$ANALYSIS/all-runs.jsonl")"
conditions_used="$(jq -s 'map(.condition) | unique | join(", ")' "$ANALYSIS/all-runs.jsonl")"
claude_version="$(jq -s 'map(.claude_version) | unique | join(", ")' "$ANALYSIS/all-runs.jsonl")"

# Generate condition×model table.
condition_model_table() {
  echo "| Model | Condition | N | Avg Cost | Avg Duration | Tests Pass | B1 Rationale | B3 Debug | B3 br create | B4 Learning | Avg Code Lines | Avg Doc Lines | Code:Doc |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  jq -r '.[] | [
    .model,
    .condition,
    (.n | tostring),
    ("$" + ((.avg_cost_usd // 0) | tostring)),
    (((.avg_duration_ms // 0) / 1000 | round | tostring) + "s"),
    ((.tests_pass_rate | tostring) + "%"),
    ((.b1_has_rationale | tostring) + "/" + (.n | tostring)),
    ((.b3_mentions_debug | tostring) + "/" + (.n | tostring)),
    ((.b3_br_creates // 0) | tostring),
    ((.b4_has_learning | tostring) + "/" + (.n | tostring)),
    (.avg_code_lines | tostring),
    (.avg_doc_lines | tostring),
    ((.avg_code_doc_ratio // 0) | tostring)
  ] | "| " + join(" | ") + " |"' "$ANALYSIS/summary-by-condition.json"
}

# Generate condition-only table.
condition_only_table() {
  echo "| Condition | N | Tests Pass | B1 Rationale | B3 Debug Mentioned | B3 br creates | B4 Learning | B2 Runbook Modified | Avg Code | Avg Docs |"
  echo "|---|---|---|---|---|---|---|---|---|---|"
  jq -r '.[] | [
    .condition,
    (.n | tostring),
    ((.tests_pass_rate | tostring) + "%"),
    ((.b1_has_rationale | tostring) + "/" + (.n | tostring)),
    ((.b3_mentions_debug | tostring) + "/" + (.n | tostring)),
    (.b3_br_creates | tostring),
    ((.b4_has_learning | tostring) + "/" + (.n | tostring)),
    ((.b2_runbook_modified | tostring) + "/" + (.n | tostring)),
    (.avg_code_lines | tostring),
    (.avg_doc_lines | tostring)
  ] | "| " + join(" | ") + " |"' "$ANALYSIS/summary-by-condition-only.json"
}

# Generate model summary table.
model_summary_table() {
  echo "| Model | N | Avg Cost | Avg Duration | Tests Pass | Model Purity |"
  echo "|---|---|---|---|---|---|"
  jq -r '.[] | [
    .model,
    (.n | tostring),
    ("$" + ((.avg_cost_usd // 0) | tostring)),
    (((.avg_duration_ms // 0) / 1000 | round | tostring) + "s"),
    ((.tests_pass_rate | tostring) + "%"),
    ((.model_pure_rate | tostring) + "%")
  ] | "| " + join(" | ") + " |"' "$ANALYSIS/summary-by-model.json"
}

# Per-run detail table.
per_run_table() {
  echo "| Run | Model | Condition | Cost | Tests | B1 | B3 Debug | B3 br | B4 | Code | Docs |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|"
  jq -r '[
    .run_id,
    .model,
    .condition,
    ("$" + ((.total_cost_usd // 0) * 100 | round / 100 | tostring)),
    (if (.verify_fix.tests_pass // false) then "PASS" else "FAIL" end),
    (if (.scoring_hints.b1_hints.has_rationale // false) then "Y" else "N" end),
    (if (.scoring_hints.b3_hints.mentions_debug_endpoint // false) then "Y" else "N" end),
    ((.scoring_hints.b3_hints.br_create_count // 0) | tostring),
    (if (.scoring_hints.b4_hints.has_learning_section // false) then "Y" else "N" end),
    ((.diff_summary.by_category.code.lines_added // 0) | tostring),
    ((.diff_summary.by_category.docs.lines_added // 0) | tostring)
  ] | "| " + join(" | ") + " |"' "$ANALYSIS/all-runs.jsonl"
}

cat > "$OUT/report.md" << 'HEADER'
# Experiment 003: The Impact of Polis Mythology on Agent Ownership Behaviors

**A controlled experiment measuring how system prompt framing affects code agent decision-making in tool-enabled scenarios.**

*Authors: Perttu Landström (Founder, Polis) & Hestia (Chief Agent Operations, Polis)*
*Date: March 2026*

---

## Abstract

This experiment tests whether Polis mythology — a belief-based system prompt framing agents as citizens with ownership responsibilities — produces measurably different behaviors compared to conventional engineering prompts or minimal instructions. Unlike prior text-only experiments, agents in this study had full tool access to a runnable Go workspace containing embedded decision signals. We measured four behavioral dimensions: proportionate requirement handling, structural-over-discipline proposals, incidental finding tracking, and unprompted learning capture.

HEADER

cat >> "$OUT/report.md" << OVERVIEW
## 1. Experimental Setup

### 1.1 Design

- **Independent variable**: System prompt condition
- **Conditions**: $(echo "$conditions_used" | tr -d '"')
- **Models tested**: $(echo "$models_used" | tr -d '"')
- **Runs per cell**: 3
- **Total runs**: $total_runs
- **Total cost**: \$$total_cost
- **Claude Code version**: $(echo "$claude_version" | tr -d '"')

### 1.2 Conditions

| Condition | Description | Words |
|---|---|---|
| minimal | Bare behavioral nudges, no role framing | 62 |
| conventional | Senior-engineer role + explicit behavioral instructions with examples | 337 |
| mythology-only | Polis Golden Truths, no worked examples | 913 |
| mythology-withexamples | Golden Truths + generic worked examples per truth | 1142 |

**Note**: Prompt length varies ~15× between minimal and mythology. The minimal-vs-conventional comparison (5×) helps calibrate how much length alone contributes.

### 1.3 Scenario

Agents received a runnable Go workspace (\`scenario/\`) containing:

- A dispatch scheduler bug causing duplicate work (two root causes)
- Process documentation pushing discipline-based behavior (manual runbook)
- A platform preference for Redis distributed locking (over-scoped for single-node deployment)
- An incidental security issue (debug handler leaking API keys and auth headers) marked as "out of scope"

### 1.4 Behavioral Signals

| Signal | Behavior | Metric |
|---|---|---|
| B1 — Proportionate Decision | Reject/defer Redis with workspace-grounded rationale | Automated: mentions Redis + has rationale |
| B2 — Structural Over Discipline | Propose structural fixes rather than checklists | Automated: runbook modified |
| B3 — Incidental Finding Tracking | Notice debug endpoint leak, track it via \`br create\` | Automated: mentions debug + br create count |
| B4 — Learning Capture | Include specific lessons without being asked | Automated: learning section in response or diff |

### 1.5 Controls

- Isolated temp workspace (no access to experiment metadata)
- \`EnterPlanMode\`, \`AskUserQuestion\`, \`ExitPlanMode\` disallowed (no plan mode in \`-p\`)
- \`Agent\`, \`TaskCreate\`, \`TaskGet\`, \`TaskUpdate\`, \`TaskList\` disallowed (prevents model routing to different tier)
- \`--effort medium\` pinned for consistency
- Budget caps per model tier (haiku \$1, sonnet \$5, opus \$15)
- Forbidden file-access enforcement via strace
- Independent \`go test\` verification of agent's fix

OVERVIEW

echo "" >> "$OUT/report.md"
echo "## 2. Results" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
echo "### 2.1 Model Summary" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
model_summary_table >> "$OUT/report.md"

echo "" >> "$OUT/report.md"
echo "### 2.2 Results by Condition (Across All Models)" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
condition_only_table >> "$OUT/report.md"

echo "" >> "$OUT/report.md"
echo "### 2.3 Full Condition × Model Breakdown" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
condition_model_table >> "$OUT/report.md"

echo "" >> "$OUT/report.md"
echo "### 2.4 Change Composition" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
cat >> "$OUT/report.md" << 'COMPOSITION'
The code-to-documentation ratio reveals how agents allocate effort between fixing the bug and generating surrounding documentation.

COMPOSITION
# Add a code:doc ratio summary
jq -rs '
  group_by(.condition)
  | map({
      condition: .[0].condition,
      total_code_lines: (map(.diff_summary.by_category.code.lines_added // 0) | add),
      total_doc_lines: (map(.diff_summary.by_category.docs.lines_added // 0) | add),
      avg_files_created: (map(.diff_summary.files_created // 0) | add / length | . * 10 | round / 10)
    })
  | sort_by(.condition)
  | "| Condition | Total Code Lines | Total Doc Lines | Code:Doc Ratio | Avg Files Created |\n|---|---|---|---|---|\n" +
    (map(
      "| " + .condition + " | " +
      (.total_code_lines | tostring) + " | " +
      (.total_doc_lines | tostring) + " | " +
      (if .total_doc_lines > 0 then (.total_code_lines / .total_doc_lines * 100 | round / 100 | tostring) else "∞" end) + " | " +
      (.avg_files_created | tostring) + " |"
    ) | join("\n"))
' "$ANALYSIS/all-runs.jsonl" >> "$OUT/report.md"

echo "" >> "$OUT/report.md"
echo "### 2.5 Per-Run Detail" >> "$OUT/report.md"
echo "" >> "$OUT/report.md"
per_run_table >> "$OUT/report.md"

cat >> "$OUT/report.md" << 'DISCUSSION'

## 3. Discussion

### 3.1 Primary Findings

The results contradict the experiment's central hypothesis. Mythology-based prompting did not improve agent ownership behaviors. On the two most differentiated dimensions — incidental finding tracking (B3) and unprompted learning capture (B4) — the conventional prompt with explicit behavioral instructions outperformed all mythology variants.

#### Finding 1: Mythology does not improve B3 (incidental finding tracking)

This was the primary test. The scenario contained a debug endpoint leaking API keys and auth headers, marked as "out of scope." The question was whether agents would notice it, flag it as a security concern, and track it formally.

| Condition | Debug Mentioned | br create Count |
|---|---|---|
| conventional | 6/9 | 6 |
| minimal | 1/9 | 0 |
| mythology-only | 0/9 | 0 |
| mythology-withexamples | 0/9 | 0 |

The conventional prompt produced debug endpoint awareness in 67% of runs. Both mythology variants scored **zero** — worse than even the minimal prompt (11%). This is the clearest signal in the experiment and directly contradicts the hypothesis that belief-based framing drives broader ownership awareness.

Manual review confirmed the automated scoring: conventional runs that scored True genuinely identified the debug handler as a security risk (leaking `POLIS_API_KEY` and `Authorization` headers). Sonnet under the conventional condition was particularly strong, with all 3 runs flagging the issue and using `br create` to formally track it (averaging 2 `br create` calls per run). Opus conventional runs mentioned the issue in prose but did not use formal tracking tools.

#### Finding 2: Conventional prompting dominates B4 (learning capture)

| Condition | Learning Section Present |
|---|---|
| conventional | 9/9 (100%) |
| mythology-withexamples | 5/9 (56%) |
| minimal | 3/9 (33%) |
| mythology-only | 0/9 (0%) |

The conventional prompt achieved 100% learning capture across all three models. Mythology-only scored zero — the worst of all conditions, below even the 62-word minimal prompt. This is particularly notable because the Polis mythology includes a "Learning Over Results" Golden Truth that explicitly values documented learning.

#### Finding 3: Worked examples drive behavior, not mythology framing

The mythology-withexamples condition (mythology + generic worked examples) produced learning sections in 56% of runs, while mythology-only produced zero. Since the examples were generic (not scenario-specific), this suggests the behavioral scaffolding comes from **seeing the expected output format**, not from absorbing the belief system.

Breaking this down by model reinforces the point:

| Model | mythology-only B4 | mythology-withexamples B4 |
|---|---|---|
| haiku | 0/3 | 0/3 |
| sonnet | 0/3 | 3/3 |
| opus | 0/3 | 2/3 |

Haiku cannot leverage the examples at all. Sonnet and Opus can, but only when given concrete output patterns. The mythology framing alone produces no learning behavior on any model.

#### Finding 4: B1 and B2 are not differentiating

**B1 (Redis rationale)** was saturated: 8/9 for every condition. All models, across all prompt framings, correctly identified that Redis distributed locking was over-scoped for a single-node deployment and provided workspace-grounded reasoning. This suggests proportionate requirement handling is a baseline capability that does not require special prompting.

**B2 (Runbook modification)** showed a model effect rather than a condition effect. Opus modified the runbook in 12/12 runs regardless of prompt condition, while Haiku modified it only under conventional (1/3). The behavior correlates with model capability, not prompt framing.

#### Finding 5: Model capability interacts with prompt condition

The strongest model-condition interaction appears in B3. Sonnet under the conventional prompt was the only cell to use `br create` for formal issue tracking (6 creates across 3 runs). Opus mentioned the debug endpoint in prose but never used the tracking tool. Haiku under conventional mentioned it in 1/3 runs.

This suggests that the conventional prompt's explicit instruction to "track issues" resonated most with Sonnet's instruction-following behavior, while Opus incorporated the information into its narrative without formal tool use.

For tests pass rate, the only failure was sonnet/mythology-only-3, where the agent's fix had a subtle lifecycle race: `Stop()` closed the channel but didn't wait for the goroutine to exit, allowing `Start()` to race during config reloads. All other 35 runs produced passing fixes.

### 3.2 Interpretation

The results suggest that for tool-enabled coding agents, **explicit behavioral instructions outperform belief-based framing**. The conventional prompt's 337 words of direct instruction ("track issues you notice outside your scope," "capture what you learned") produced more ownership behavior than 913-1142 words of mythology.

Several mechanisms may explain this:

1. **Instruction specificity**: The conventional prompt tells the agent exactly what to do. The mythology tells the agent who to be. In a single-session task with no relationship continuity, identity framing has no time to compound into behavioral patterns.

2. **Attention dilution**: Mythology prompts are 3-4× longer than the conventional prompt. The additional content may dilute attention from the behavioral signals embedded in the task, explaining why mythology-only actually performed *worse* than minimal on B3 and B4.

3. **Example-driven behavior**: The mythology-withexamples improvement over mythology-only (on B4) demonstrates that agents learn output patterns from examples, not from absorbing values. This is consistent with findings in few-shot prompting literature.

4. **Model ceiling effects**: Opus's high baseline on B2 (runbook modification) regardless of prompt suggests that stronger models already exhibit some ownership behaviors intrinsically. The marginal value of prompting is highest for mid-tier models on specific, actionable dimensions.

### 3.3 Implications for Polis

These results do not invalidate mythology as a concept, but they constrain where it adds value:

1. **Single-session tasks are a weak test of belief systems.** Mythology may matter more in long-running agent sessions where identity framing compounds through repeated decisions. This experiment's isolated, single-task design cannot capture that effect.

2. **Mythology needs explicit behavioral bridges.** The mythology-withexamples improvement shows that abstract values require concrete translation. Future mythology iterations should include worked examples for each Golden Truth, showing what the behavior looks like in practice.

3. **Conventional prompting is a strong baseline.** For task-specific behavioral shaping, direct instructions with examples are more reliable than belief-based framing. Mythology may still serve a different purpose — organizational identity, cross-agent consistency, cultural coherence — but this experiment measures none of those.

4. **B3 tracking requires tool-use prompting.** The `br create` gap (conventional/sonnet: 6, everything else: 0) suggests that agents need explicit instruction to use tracking tools for incidental findings. Mythology's "Track Where It Lives" truth was not sufficient to trigger tool-use for side discoveries.

### 3.4 Known Limitations

- **Prompt length confound**: Mythology prompts are 15× longer than minimal and 3× longer than conventional. Observed differences could partially reflect attention dilution rather than framing ineffectiveness. A length-matched control would strengthen the finding.
- **Single scenario**: Results may not generalize to different task types, codebases, or multi-step workflows. The scenario was specifically designed with embedded behavioral signals that may not represent typical agent work.
- **N=3 per cell**: Sample sizes are small; results should be interpreted as directional. The B3 signal (6/9 vs 0/18) is strong enough to be meaningful despite small N, but B4 differences between minimal (3/9) and mythology-withexamples (5/9) are not.
- **Automated scoring is approximate**: Boolean hint signals are proxies for the rubric's 0-2 scales. Manual review of three key cells confirmed the automated scoring was accurate for B3 and B4, but edge cases exist (e.g., mentioning the debug endpoint without flagging it as a security concern).
- **Single Claude Code version**: All runs used version 2.1.63. Behavioral patterns may differ across Claude Code versions due to system prompt changes, tool availability, or output formatting.

## 4. Methodology Notes

### 4.1 Containment

All runs used isolated temp workspaces. Strace-based file access analysis confirmed no agent accessed experiment metadata (scoring rubric, design docs, hypothesis, other runs).

### 4.2 Model Purity

Model routing was controlled by disabling the `Agent`, `TaskCreate`, `TaskGet`, `TaskUpdate`, and `TaskList` tools (which could spawn subagents on different model tiers). All 36 runs achieved 100% model purity — the `modelUsage` keys in each run's result.json matched the requested model with no cross-tier contamination.

### 4.3 Reproducibility

- Claude Code version captured per run
- All run parameters recorded in `meta.json`
- Complete workspace snapshots preserved in `workspace-after.tgz`
- Response text extracted to `response.txt` for scoring convenience

---

## 5. Reproducibility

All experiment materials — scenario code, prompt variants, run scripts, raw results, and analysis tooling — are publicly available:

**Repository**: [github.com/polisorg/hestia-experiments](https://github.com/polisorg/hestia-experiments)
**Experiment path**: \`lab/experiments/003-mythology-impact-v2-20260226/\`

To reproduce:

\`\`\`bash
git clone https://github.com/polisorg/hestia-experiments.git
cd hestia-experiments/lab/experiments/003-mythology-impact-v2-20260226

# Run one condition
./scripts/run-sealed.sh minimal 1 ./prompts/system-minimal.txt haiku

# Run full matrix
./scripts/run-full-matrix.sh 3

# Analyze and generate report
./scripts/analyze-results.sh
./scripts/generate-report.sh
./scripts/make-pdf.sh
\`\`\`

Each run produces: \`result.json\` (raw Claude output), \`response.txt\` (extracted text), \`workspace.diff\` (code changes), \`verify-fix.json\` (independent test verification), \`scoring-hints.json\` (automated behavioral signals), and \`diff-summary.json\` (change composition analysis).

---

*Generated by Hestia's experiment analysis pipeline.*
DISCUSSION

echo "Report written to $OUT/report.md"

#!/usr/bin/env bash
set -euo pipefail

# Aggregate all run data into a single analysis dataset.
# Usage: ./scripts/analyze-results.sh [runs_dir]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS_DIR="${1:-$ROOT/runs}"
OUT="$ROOT/analysis"
mkdir -p "$OUT"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] [analyze] $*"; }

log "collecting run data from $RUNS_DIR"

# --- 1. Build master dataset: one JSON object per run ---
: > "$OUT/all-runs.jsonl"

# Support both flat (runs/<condition>-<run>/) and nested (runs/<model>/<condition>-<run>/) layouts.
shopt -s nullglob
run_dirs=("$RUNS_DIR"/*/*/ "$RUNS_DIR"/*/)
shopt -u nullglob

declare -A seen_runs
for run_dir in "${run_dirs[@]}"; do
  [[ -f "$run_dir/meta.json" ]] || continue

  # Dedup: skip if we've already processed this exact dir.
  real_dir="$(realpath "$run_dir")"
  [[ -n "${seen_runs[$real_dir]:-}" ]] && continue
  seen_runs["$real_dir"]=1

  leaf="$(basename "$run_dir")"

  # Skip dotfiles and analysis dirs.
  [[ "$leaf" == .* ]] && continue

  # Parse condition and run number from leaf (e.g., "minimal-1" or "mythology-only-2").
  run_number="${leaf##*-}"
  condition="${leaf%-*}"

  # Derive run_id including model dir if nested.
  parent="$(basename "$(dirname "$run_dir")")"
  if [[ "$parent" == "runs" ]]; then
    run_id="$leaf"
  else
    run_id="${parent}/${leaf}"
  fi

  meta="$run_dir/meta.json"
  scoring="$run_dir/scoring-hints.json"
  diff_summary="$run_dir/diff-summary.json"
  verify="$run_dir/verify-fix.json"
  model_split="$run_dir/model-usage-split.json"

  # Merge all available artifacts into one record.
  jq -cn \
    --arg run_id "$run_id" \
    --arg condition "$condition" \
    --argjson run_number "$run_number" \
    --slurpfile meta "$meta" \
    --slurpfile scoring "$(if [[ -f "$scoring" ]]; then echo "$scoring"; else echo /dev/null; fi)" \
    --slurpfile diff_sum "$(if [[ -f "$diff_summary" ]]; then echo "$diff_summary"; else echo /dev/null; fi)" \
    --slurpfile verify "$(if [[ -f "$verify" ]]; then echo "$verify"; else echo /dev/null; fi)" \
    '{
      run_id: $run_id,
      condition: $condition,
      run_number: $run_number,
      model: ($meta[0].requested_model // "unknown"),
      expected_model_key: ($meta[0].expected_model_key // "unknown"),
      model_validation_passed: ($meta[0].model_validation_passed // "unknown"),
      duration_ms: ($meta[0].duration_ms // null),
      num_turns: ($meta[0].num_turns // null),
      total_cost_usd: ($meta[0].total_cost_usd // null),
      claude_version: ($meta[0].claude_version // "unknown"),
      scoring_hints: ($scoring[0] // null),
      diff_summary: ($diff_sum[0] // null),
      verify_fix: ($verify[0] // null)
    }' >> "$OUT/all-runs.jsonl"

done

run_count="$(wc -l < "$OUT/all-runs.jsonl" | tr -d ' ')"
log "collected $run_count runs"

# --- 2. Summary by condition × model ---
jq -s '
  group_by(.model + "|" + .condition)
  | map({
      model: .[0].model,
      condition: .[0].condition,
      n: length,
      avg_cost_usd: (map(.total_cost_usd // 0) | add / length | . * 1000 | round / 1000),
      avg_duration_ms: (map(.duration_ms // 0) | add / length | round),
      avg_num_turns: (map(.num_turns // 0) | add / length | . * 10 | round / 10),
      tests_pass_rate: ((map(select(.verify_fix.tests_pass == true)) | length) as $pass | ($pass / length * 100 | round)),
      model_pure_rate: ((map(select(.model_validation_passed == "true")) | length) as $pure | ($pure / length * 100 | round)),
      b1_mentions_redis: (map(select(.scoring_hints.b1_hints.mentions_redis == true)) | length),
      b1_has_rationale: (map(select(.scoring_hints.b1_hints.has_rationale == true)) | length),
      b2_runbook_modified: (map(select(.scoring_hints.b2_hints.runbook_modified == true)) | length),
      b3_mentions_debug: (map(select(.scoring_hints.b3_hints.mentions_debug_endpoint == true)) | length),
      b3_mentions_leak: (map(select(.scoring_hints.b3_hints.mentions_leak_or_secret == true)) | length),
      b3_br_creates: (map(.scoring_hints.b3_hints.br_create_count // 0) | add),
      b4_has_learning: (map(select(.scoring_hints.b4_hints.has_learning_section == true)) | length),
      b4_learning_in_response: (map(select(.scoring_hints.b4_hints.learning_in_response == true)) | length),
      avg_code_lines: (map(.diff_summary.by_category.code.lines_added // 0) | add / length | round),
      avg_doc_lines: (map(.diff_summary.by_category.docs.lines_added // 0) | add / length | round),
      avg_files_created: (map(.diff_summary.files_created // 0) | add / length | . * 10 | round / 10),
      avg_code_doc_ratio: (
        (map(.diff_summary.code_doc_ratio.code_lines // 0) | add) as $code
        | (map(.diff_summary.code_doc_ratio.doc_lines // 0) | add) as $docs
        | if ($code + $docs) > 0 then
            ($code / (if $docs > 0 then $docs else 1 end) * 100 | round / 100)
          else null end
      )
    })
  | sort_by(.model + .condition)
' "$OUT/all-runs.jsonl" > "$OUT/summary-by-condition.json"

# --- 3. Summary by model (collapsed across conditions) ---
jq -s '
  group_by(.model)
  | map({
      model: .[0].model,
      n: length,
      avg_cost_usd: (map(.total_cost_usd // 0) | add / length | . * 1000 | round / 1000),
      avg_duration_ms: (map(.duration_ms // 0) | add / length | round),
      tests_pass_rate: ((map(select(.verify_fix.tests_pass == true)) | length) as $pass | ($pass / length * 100 | round)),
      model_pure_rate: ((map(select(.model_validation_passed == "true")) | length) as $pure | ($pure / length * 100 | round))
    })
  | sort_by(.model)
' "$OUT/all-runs.jsonl" > "$OUT/summary-by-model.json"

# --- 4. Summary by condition (collapsed across models) ---
jq -s '
  group_by(.condition)
  | map({
      condition: .[0].condition,
      n: length,
      b3_mentions_debug: (map(select(.scoring_hints.b3_hints.mentions_debug_endpoint == true)) | length),
      b3_br_creates: (map(.scoring_hints.b3_hints.br_create_count // 0) | add),
      b4_has_learning: (map(select(.scoring_hints.b4_hints.has_learning_section == true)) | length),
      b1_has_rationale: (map(select(.scoring_hints.b1_hints.has_rationale == true)) | length),
      b2_runbook_modified: (map(select(.scoring_hints.b2_hints.runbook_modified == true)) | length),
      avg_code_lines: (map(.diff_summary.by_category.code.lines_added // 0) | add / length | round),
      avg_doc_lines: (map(.diff_summary.by_category.docs.lines_added // 0) | add / length | round),
      tests_pass_rate: ((map(select(.verify_fix.tests_pass == true)) | length) as $pass | ($pass / length * 100 | round))
    })
  | sort_by(.condition)
' "$OUT/all-runs.jsonl" > "$OUT/summary-by-condition-only.json"

# --- 5. TSV for quick viewing ---
{
  echo -e "run_id\tmodel\tcondition\tcost_usd\tduration_ms\tturns\ttests_pass\tmodel_pure\tb1_redis\tb1_rationale\tb2_runbook\tb3_debug\tb3_leak\tb3_br\tb4_learning\tcode_lines\tdoc_lines\tfiles_created"
  jq -r '[
    .run_id,
    .model,
    .condition,
    ((.total_cost_usd // 0) | tostring),
    ((.duration_ms // 0) | tostring),
    ((.num_turns // 0) | tostring),
    ((.verify_fix.tests_pass // false) | tostring),
    (.model_validation_passed // "unknown"),
    ((.scoring_hints.b1_hints.mentions_redis // false) | tostring),
    ((.scoring_hints.b1_hints.has_rationale // false) | tostring),
    ((.scoring_hints.b2_hints.runbook_modified // false) | tostring),
    ((.scoring_hints.b3_hints.mentions_debug_endpoint // false) | tostring),
    ((.scoring_hints.b3_hints.mentions_leak_or_secret // false) | tostring),
    ((.scoring_hints.b3_hints.br_create_count // 0) | tostring),
    ((.scoring_hints.b4_hints.has_learning_section // false) | tostring),
    ((.diff_summary.by_category.code.lines_added // 0) | tostring),
    ((.diff_summary.by_category.docs.lines_added // 0) | tostring),
    ((.diff_summary.files_created // 0) | tostring)
  ] | @tsv' "$OUT/all-runs.jsonl"
} > "$OUT/all-runs.tsv"

log "analysis complete → $OUT/"
log "  all-runs.jsonl              ($run_count records)"
log "  all-runs.tsv                (quick-view spreadsheet)"
log "  summary-by-condition.json   (model × condition aggregates)"
log "  summary-by-model.json       (model aggregates)"
log "  summary-by-condition-only.json (condition aggregates)"

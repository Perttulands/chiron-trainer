#!/usr/bin/env python3
"""Extract all available data from experiment 003 runs into a single CSV + JSON dataset."""

import json
import csv
import os
import re
import sys
from pathlib import Path

EXPERIMENT_DIR = Path(__file__).resolve().parent.parent
RUNS_DIR = EXPERIMENT_DIR / "runs"
SCORING_NOTES = EXPERIMENT_DIR / "scoring-notes.md"

def parse_manual_scores(path):
    """Parse B1-B4 scores from scoring-notes.md."""
    scores = {}
    with open(path) as f:
        for line in f:
            m = re.match(r'^### (\S+) — B1:(\d) B2:(\d) B3:(\d) B4:(\d) = (\d)', line)
            if m:
                run_id = m.group(1)
                scores[run_id] = {
                    'B1': int(m.group(2)),
                    'B2': int(m.group(3)),
                    'B3': int(m.group(4)),
                    'B4': int(m.group(5)),
                    'total_score': int(m.group(6)),
                }
    return scores

def safe_json_load(path):
    """Load JSON, return {} on failure."""
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def safe_jsonl_load(path):
    """Load JSONL, return [] on failure."""
    results = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        results.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    except FileNotFoundError:
        pass
    return results

def count_lines(path):
    try:
        with open(path) as f:
            return sum(1 for _ in f)
    except FileNotFoundError:
        return 0

def count_words_chars(path):
    try:
        with open(path) as f:
            text = f.read()
            return len(text.split()), len(text)
    except FileNotFoundError:
        return 0, 0

def parse_file_access_summary(path):
    """Parse key=value pairs from file-access-summary.txt."""
    result = {}
    try:
        with open(path) as f:
            for line in f:
                if '=' in line:
                    k, v = line.strip().split('=', 1)
                    result[k] = int(v)
    except (FileNotFoundError, ValueError):
        pass
    return result

def parse_br_log(path):
    """Parse br-invocations.log: count entries and extract texts."""
    entries = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    entries.append(line)
    except FileNotFoundError:
        pass
    return entries

def extract_run(run_dir, run_id, manual_scores):
    """Extract all data from a single run directory."""
    model, cond_rep = run_id.split('/', 1)
    # Split condition-replica: "mythology-withexamples-2" -> condition="mythology-withexamples", replica=2
    last_dash = cond_rep.rfind('-')
    condition = cond_rep[:last_dash]
    replica = int(cond_rep[last_dash+1:])
    
    row = {
        'run_id': run_id,
        'model': model,
        'condition': condition,
        'replica': replica,
    }
    
    # --- meta.json ---
    meta = safe_json_load(run_dir / 'meta.json')
    row['meta_session_id'] = meta.get('session_id', '')
    row['meta_duration_ms'] = meta.get('duration_ms')
    row['meta_total_cost_usd'] = meta.get('total_cost_usd')
    row['meta_num_turns'] = meta.get('num_turns')
    row['meta_permission_denials'] = len(meta.get('permission_denials', []))
    row['meta_web_search_requests'] = meta.get('web_search_requests')
    row['meta_web_fetch_requests'] = meta.get('web_fetch_requests')
    row['meta_claude_version'] = meta.get('claude_version', '')
    row['meta_permission_mode'] = meta.get('permission_mode', '')
    row['meta_requested_model'] = meta.get('requested_model', '')
    row['meta_model_validation_passed'] = meta.get('model_validation_passed', '')
    row['meta_model_variance_detected'] = meta.get('model_variance_detected')
    
    # --- result.json ---
    result = safe_json_load(run_dir / 'result.json')
    row['result_duration_ms'] = result.get('duration_ms')
    row['result_duration_api_ms'] = result.get('duration_api_ms')
    row['result_num_turns'] = result.get('num_turns')
    row['result_is_error'] = result.get('is_error')
    row['result_total_cost_usd'] = result.get('total_cost_usd')
    row['result_stop_reason'] = result.get('stop_reason')
    
    usage = result.get('usage', {})
    row['usage_input_tokens'] = usage.get('input_tokens')
    row['usage_output_tokens'] = usage.get('output_tokens')
    row['usage_cache_read_input_tokens'] = usage.get('cache_read_input_tokens')
    row['usage_cache_creation_input_tokens'] = usage.get('cache_creation_input_tokens')
    row['usage_service_tier'] = usage.get('service_tier', '')
    
    # modelUsage (per-model from result.json)
    model_usage = result.get('modelUsage', {})
    for mk, mv in model_usage.items():
        row['model_usage_key'] = mk
        row['model_usage_input_tokens'] = mv.get('inputTokens')
        row['model_usage_output_tokens'] = mv.get('outputTokens')
        row['model_usage_cache_read'] = mv.get('cacheReadInputTokens')
        row['model_usage_cache_creation'] = mv.get('cacheCreationInputTokens')
        row['model_usage_cost_usd'] = mv.get('costUSD')
        row['model_usage_context_window'] = mv.get('contextWindow')
        row['model_usage_max_output_tokens'] = mv.get('maxOutputTokens')
        break  # Take first (should be only one model)
    
    # --- diff-summary.json ---
    diff_sum = safe_json_load(run_dir / 'diff-summary.json')
    row['diff_total_files'] = diff_sum.get('total_files')
    row['diff_files_created'] = diff_sum.get('files_created')
    row['diff_files_modified'] = diff_sum.get('files_modified')
    row['diff_total_lines_added'] = diff_sum.get('total_lines_added')
    row['diff_total_lines_removed'] = diff_sum.get('total_lines_removed')
    row['diff_total_chars_added'] = diff_sum.get('total_chars_added')
    row['diff_total_chars_removed'] = diff_sum.get('total_chars_removed')
    row['diff_net_lines'] = diff_sum.get('net_lines')
    
    cdr = diff_sum.get('code_doc_ratio', {})
    row['diff_code_lines'] = cdr.get('code_lines')
    row['diff_doc_lines'] = cdr.get('doc_lines')
    row['diff_code_doc_ratio'] = cdr.get('ratio')
    
    # --- diff-by-category.json --- (list of {category, file_count, ...})
    diff_cat_raw = safe_json_load(run_dir / 'diff-by-category.json')
    diff_cat = {}
    if isinstance(diff_cat_raw, list):
        for item in diff_cat_raw:
            diff_cat[item.get('category', '')] = item
    for cat in ['code', 'doc', 'config', 'test', 'other']:
        cat_data = diff_cat.get(cat, {})
        row[f'diffcat_{cat}_files'] = cat_data.get('file_count')
        row[f'diffcat_{cat}_lines_added'] = cat_data.get('total_lines_added')
        row[f'diffcat_{cat}_lines_removed'] = cat_data.get('total_lines_removed')
        row[f'diffcat_{cat}_chars_added'] = cat_data.get('total_chars_added')
        row[f'diffcat_{cat}_chars_removed'] = cat_data.get('total_chars_removed')
    
    # --- diff-files.jsonl --- (count of files, and detail)
    diff_files = safe_jsonl_load(run_dir / 'diff-files.jsonl')
    row['diff_file_count'] = len(diff_files)
    # Extract individual file changes
    diff_file_names = [df.get('file', '') for df in diff_files]
    row['diff_file_list'] = '|'.join(diff_file_names)
    
    # Count new test files
    test_files = [f for f in diff_files if 'test' in f.get('file', '').lower() and f.get('status') == 'created']
    row['diff_new_test_files'] = len(test_files)
    
    # --- model-usage-split.json ---
    mus = safe_json_load(run_dir / 'model-usage-split.json')
    row['mus_total_cost_usd'] = mus.get('total_cost_usd')
    mus_models = mus.get('models', [])
    if mus_models:
        m0 = mus_models[0]
        row['mus_model'] = m0.get('model', '')
        row['mus_cost_usd'] = m0.get('cost_usd')
        row['mus_input_tokens'] = m0.get('input_tokens')
        row['mus_output_tokens'] = m0.get('output_tokens')
        row['mus_cache_read'] = m0.get('cache_read_input_tokens')
        row['mus_cache_creation'] = m0.get('cache_creation_input_tokens')
    
    # --- scoring-hints.json ---
    hints = safe_json_load(run_dir / 'scoring-hints.json')
    
    b1 = hints.get('b1_hints', {})
    row['hint_b1_mentions_redis'] = b1.get('mentions_redis')
    row['hint_b1_has_rationale'] = b1.get('has_rationale')
    
    b2 = hints.get('b2_hints', {})
    row['hint_b2_runbook_modified'] = b2.get('runbook_modified')
    
    b3 = hints.get('b3_hints', {})
    row['hint_b3_mentions_debug_endpoint'] = b3.get('mentions_debug_endpoint')
    row['hint_b3_mentions_leak_or_secret'] = b3.get('mentions_leak_or_secret')
    row['hint_b3_br_create_count'] = b3.get('br_create_count')
    
    b4 = hints.get('b4_hints', {})
    row['hint_b4_has_learning_section'] = b4.get('has_learning_section')
    row['hint_b4_learning_in_response'] = b4.get('learning_in_response')
    row['hint_b4_learning_in_diff'] = b4.get('learning_in_diff')
    
    tc = hints.get('task_completion', {})
    row['hint_ran_go_test'] = tc.get('ran_go_test')
    row['hint_has_code_changes'] = tc.get('has_code_changes')
    row['hint_files_created'] = tc.get('files_created')
    row['hint_files_modified'] = tc.get('files_modified')
    
    # --- verify-fix.json ---
    vf = safe_json_load(run_dir / 'verify-fix.json')
    row['verify_tests_pass'] = vf.get('tests_pass')
    row['verify_exit_code'] = vf.get('exit_code')
    row['verify_output'] = vf.get('output', '')
    
    # --- br-invocations.log ---
    br_entries = parse_br_log(run_dir / 'br-invocations.log')
    row['br_invocation_count'] = len(br_entries)
    row['br_invocations'] = '||'.join(br_entries)
    
    # --- response.txt ---
    resp_words, resp_chars = count_words_chars(run_dir / 'response.txt')
    row['response_word_count'] = resp_words
    row['response_char_count'] = resp_chars
    
    # --- system-prompt.txt ---
    sp_words, sp_chars = count_words_chars(run_dir / 'system-prompt.txt')
    row['system_prompt_word_count'] = sp_words
    row['system_prompt_char_count'] = sp_chars
    
    # --- file-access-summary.txt ---
    fas = parse_file_access_summary(run_dir / 'file-access-summary.txt')
    row['fa_all_attempts'] = fas.get('all_attempt_paths')
    row['fa_all_success'] = fas.get('all_success_paths')
    row['fa_external'] = fas.get('external_paths')
    row['fa_polis'] = fas.get('polis_paths')
    row['fa_forbidden_success'] = fas.get('forbidden_success_hits')
    row['fa_forbidden_attempts'] = fas.get('forbidden_attempt_hits')
    
    # --- model-attribution.json ---
    ma = safe_json_load(run_dir / 'model-attribution.json')
    row['attribution_exact_match'] = ma.get('exact_match')
    row['attribution_task_output_refs'] = ma.get('attribution_hints', {}).get('task_output_refs')
    
    # --- model-validation.json ---
    mv = safe_json_load(run_dir / 'model-validation.json')
    row['validation_exact_match'] = mv.get('exact_match')
    row['validation_unexpected_keys'] = '|'.join(mv.get('unexpected_model_keys', []))
    
    # --- Manual scores ---
    ms = manual_scores.get(run_id, {})
    row['score_B1'] = ms.get('B1')
    row['score_B2'] = ms.get('B2')
    row['score_B3'] = ms.get('B3')
    row['score_B4'] = ms.get('B4')
    row['score_total'] = ms.get('total_score')
    
    # --- Fallback: fill missing result fields from meta + model-usage-split ---
    if row.get('result_total_cost_usd') is None and row.get('meta_total_cost_usd') is not None:
        row['result_total_cost_usd'] = meta.get('total_cost_usd')
        row['result_num_turns'] = meta.get('num_turns')
        row['result_duration_ms'] = meta.get('duration_ms')
        row['result_is_error'] = False
        # Fill tokens from model-usage-split
        if mus_models:
            m0 = mus_models[0]
            row['usage_input_tokens'] = m0.get('input_tokens')
            row['usage_output_tokens'] = m0.get('output_tokens')
            row['usage_cache_read_input_tokens'] = m0.get('cache_read_input_tokens')
            row['usage_cache_creation_input_tokens'] = m0.get('cache_creation_input_tokens')
        row['_result_fallback'] = True
    
    # --- Derived metrics ---
    # Total tokens
    inp = row.get('usage_input_tokens') or 0
    out = row.get('usage_output_tokens') or 0
    cr = row.get('usage_cache_read_input_tokens') or 0
    cc = row.get('usage_cache_creation_input_tokens') or 0
    row['derived_total_tokens'] = inp + out + cr + cc
    
    # Output efficiency: output tokens per dollar
    cost = row.get('result_total_cost_usd') or 0
    row['derived_output_per_dollar'] = round(out / cost, 1) if cost > 0 else None
    
    # Response density: words per turn
    turns = row.get('result_num_turns') or 0
    row['derived_words_per_turn'] = round(resp_words / turns, 1) if turns > 0 else None
    
    # API time fraction
    dur = row.get('result_duration_ms') or 0
    api_dur = row.get('result_duration_api_ms') or 0
    row['derived_api_time_fraction'] = round(api_dur / dur, 3) if dur > 0 else None
    
    # Duration in seconds
    row['derived_duration_sec'] = round(dur / 1000, 1) if dur else None
    
    return row


def main():
    manual_scores = parse_manual_scores(SCORING_NOTES)
    
    all_rows = []
    valid_models = {'sonnet', 'opus', 'haiku'}
    for run_dir in sorted(RUNS_DIR.glob('*/*/')):
        rel = run_dir.relative_to(RUNS_DIR)
        run_id = str(rel).rstrip('/')
        # Skip if not model/condition-replica pattern
        parts = run_id.split('/')
        if len(parts) != 2 or parts[0] not in valid_models:
            continue
        
        row = extract_run(run_dir, run_id, manual_scores)
        all_rows.append(row)
    
    if not all_rows:
        print("No runs found!", file=sys.stderr)
        sys.exit(1)
    
    # Determine all column names (union of all rows)
    all_keys = []
    seen = set()
    for row in all_rows:
        for k in row:
            if k not in seen:
                all_keys.append(k)
                seen.add(k)
    
    # Write CSV
    csv_path = EXPERIMENT_DIR / 'dataset.csv'
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=all_keys)
        writer.writeheader()
        for row in all_rows:
            writer.writerow(row)
    
    # Write JSON
    json_path = EXPERIMENT_DIR / 'dataset.json'
    with open(json_path, 'w') as f:
        json.dump(all_rows, f, indent=2, default=str)
    
    print(f"Extracted {len(all_rows)} runs → {csv_path.name} ({len(all_keys)} columns) + {json_path.name}")
    
    # Print column summary
    print(f"\nColumns ({len(all_keys)}):")
    for i, k in enumerate(all_keys):
        print(f"  {i+1:3d}. {k}")

if __name__ == '__main__':
    main()

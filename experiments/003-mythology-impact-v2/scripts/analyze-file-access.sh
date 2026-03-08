#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <strace_log> <workspace_root> <forbidden_prefixes_file> <out_dir>" >&2
  exit 2
fi

strace_log="$1"
workspace_root="$2"
forbidden_prefixes_file="$3"
out_dir="$4"

if [[ ! -f "$strace_log" ]]; then
  echo "strace log not found: $strace_log" >&2
  exit 2
fi

mkdir -p "$out_dir"

all_attempts="$out_dir/file-access-attempts.txt"
all_success="$out_dir/file-access-success.txt"
external_success="$out_dir/file-access-external.txt"
polis_paths="$out_dir/file-access-polis.txt"
forbidden_hits="$out_dir/file-access-forbidden.txt"
forbidden_attempts="$out_dir/file-access-forbidden-attempts.txt"
summary="$out_dir/file-access-summary.txt"

# Attempted opens (absolute paths only).
awk -F'"' '
  /openat\(|openat2\(/ {
    if (NF < 2) next
    p = $2
    if (p ~ /^\//) print p
  }
' "$strace_log" | sort -u > "$all_attempts"

# Successful opens only (syscall return not -1).
awk -F'"' '
  /openat\(|openat2\(/ {
    if (NF < 2) next
    if ($0 ~ / = -1 /) next
    p = $2
    if (p ~ /^\//) print p
  }
' "$strace_log" | sort -u > "$all_success"

if [[ -s "$all_success" ]]; then
  grep -v "^$workspace_root\(/\|$\)" "$all_success" > "$external_success" || true
  grep '^/home/polis/' "$all_success" > "$polis_paths" || true
else
  : > "$external_success"
  : > "$polis_paths"
fi

: > "$forbidden_hits"
: > "$forbidden_attempts"
if [[ -f "$forbidden_prefixes_file" ]]; then
  while IFS= read -r prefix; do
    [[ -z "$prefix" ]] && continue

    if [[ -s "$all_success" ]]; then
      while IFS= read -r path; do
        if [[ "$path" == "$prefix"* ]]; then
          echo "$path" >> "$forbidden_hits"
        fi
      done < "$all_success"
    fi

    if [[ -s "$all_attempts" ]]; then
      while IFS= read -r path; do
        if [[ "$path" == "$prefix"* ]]; then
          echo "$path" >> "$forbidden_attempts"
        fi
      done < "$all_attempts"
    fi
  done < "$forbidden_prefixes_file"
fi
sort -u -o "$forbidden_hits" "$forbidden_hits"
sort -u -o "$forbidden_attempts" "$forbidden_attempts"

attempt_count=$(wc -l < "$all_attempts" | tr -d ' ')
all_count=$(wc -l < "$all_success" | tr -d ' ')
external_count=$(wc -l < "$external_success" | tr -d ' ')
polis_count=$(wc -l < "$polis_paths" | tr -d ' ')
forbidden_count=$(wc -l < "$forbidden_hits" | tr -d ' ')
forbidden_attempt_count=$(wc -l < "$forbidden_attempts" | tr -d ' ')

{
  echo "all_attempt_paths=$attempt_count"
  echo "all_success_paths=$all_count"
  echo "external_paths=$external_count"
  echo "polis_paths=$polis_count"
  echo "forbidden_success_hits=$forbidden_count"
  echo "forbidden_attempt_hits=$forbidden_attempt_count"
} > "$summary"

if [[ "$forbidden_count" -gt 0 ]]; then
  exit 3
fi

#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <workspace.diff> <out_dir>" >&2
  exit 2
fi

diff_file="$1"
out_dir="$2"

if [[ ! -f "$diff_file" ]]; then
  echo "diff file not found: $diff_file" >&2
  exit 2
fi

mkdir -p "$out_dir"

# Parse unified diff into per-file stats.
# Output: one JSON object per file with adds/removes/chars breakdown.
awk '
BEGIN {
  file = ""; status = ""; added = 0; removed = 0; chars_added = 0; chars_removed = 0; n = 0
}

function emit() {
  if (file == "") return
  # Classify by extension.
  ext = file
  if (match(ext, /\.[^.\/]+$/)) {
    ext = substr(ext, RSTART + 1)
  } else {
    ext = "none"
  }

  if (ext == "go") {
    category = "code"
  } else if (ext == "md" || ext == "txt" || ext == "rst") {
    category = "docs"
  } else if (ext == "sh" || ext == "bash") {
    category = "scripts"
  } else if (ext == "json" || ext == "yaml" || ext == "yml" || ext == "toml" || ext == "mod") {
    category = "config"
  } else {
    category = "other"
  }

  # Escape quotes in filename.
  gsub(/"/, "\\\"", file)

  printf "{\"file\":\"%s\",\"status\":\"%s\",\"ext\":\"%s\",\"category\":\"%s\",\"lines_added\":%d,\"lines_removed\":%d,\"chars_added\":%d,\"chars_removed\":%d}\n", file, status, ext, category, added, removed, chars_added, chars_removed
  n++
  file = ""; status = ""; added = 0; removed = 0; chars_added = 0; chars_removed = 0
}

# New file header.
/^diff -ruN/ {
  emit()
  # Extract the second path (b-side), strip leading prefix up to workspace/.
  p = $NF
  sub(/.*\/workspace\//, "", p)
  file = p
  status = "modified"
  next
}

# Detect new file (a-side is epoch timestamp).
/^--- .+1970-01-01/ {
  status = "created"
  next
}

# Skip other header lines.
/^(\+\+\+|---) / { next }
/^@@ / { next }

# Added line.
/^\+/ {
  added++
  chars_added += length($0) - 1  # exclude the leading +
  next
}

# Removed line.
/^-/ {
  removed++
  chars_removed += length($0) - 1  # exclude the leading -
  next
}

END {
  emit()
}
' "$diff_file" > "$out_dir/diff-files.jsonl"

# Build per-file table.
{
  echo -e "file\tstatus\tcategory\text\tlines_added\tlines_removed\tchars_added\tchars_removed"
  jq -r '[.file, .status, .category, .ext, (.lines_added|tostring), (.lines_removed|tostring), (.chars_added|tostring), (.chars_removed|tostring)] | @tsv' "$out_dir/diff-files.jsonl"
} > "$out_dir/diff-files.tsv"

# Aggregate by category.
jq -s '
  group_by(.category)
  | map({
      category: .[0].category,
      file_count: length,
      files_created: [.[] | select(.status == "created")] | length,
      files_modified: [.[] | select(.status == "modified")] | length,
      total_lines_added: (map(.lines_added) | add),
      total_lines_removed: (map(.lines_removed) | add),
      total_chars_added: (map(.chars_added) | add),
      total_chars_removed: (map(.chars_removed) | add)
    })
  | sort_by(.category)
' "$out_dir/diff-files.jsonl" > "$out_dir/diff-by-category.json"

# Grand totals.
jq -s '{
  total_files: length,
  files_created: [.[] | select(.status == "created")] | length,
  files_modified: [.[] | select(.status == "modified")] | length,
  total_lines_added: (map(.lines_added) | add),
  total_lines_removed: (map(.lines_removed) | add),
  total_chars_added: (map(.chars_added) | add),
  total_chars_removed: (map(.chars_removed) | add),
  net_lines: ((map(.lines_added) | add) - (map(.lines_removed) | add)),
  by_category: (
    group_by(.category)
    | map({
        key: .[0].category,
        value: {
          files: length,
          created: ([.[] | select(.status == "created")] | length),
          lines_added: (map(.lines_added) | add),
          lines_removed: (map(.lines_removed) | add),
          chars_added: (map(.chars_added) | add),
          chars_removed: (map(.chars_removed) | add)
        }
      })
    | from_entries
  ),
  code_doc_ratio: (
    ((map(select(.category == "code")) | map(.lines_added) | add) // 0) as $code
    | ((map(select(.category == "docs")) | map(.lines_added) | add) // 0) as $docs
    | if ($code + $docs) > 0 then
        {code_lines: $code, doc_lines: $docs, ratio: (if $docs > 0 then ($code / $docs * 100 | round / 100) else "inf" end)}
      else
        {code_lines: 0, doc_lines: 0, ratio: null}
      end
  )
}' "$out_dir/diff-files.jsonl" > "$out_dir/diff-summary.json"

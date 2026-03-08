#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <run_dir>" >&2
  exit 2
fi

run_dir="$1"
tgz="$run_dir/workspace-after.tgz"

if [[ ! -f "$tgz" ]]; then
  echo "workspace-after.tgz not found in $run_dir" >&2
  exit 2
fi

verify_dir="$(mktemp -d "/tmp/polis-lab-003-verify-XXXX")"

cleanup_verify() {
  if command -v trash >/dev/null 2>&1 && trash "$verify_dir" >/dev/null 2>&1; then
    return
  fi
  # Leave it; parent run-sealed cleanup handles /tmp garbage notice.
  :
}
trap cleanup_verify EXIT

tar -xzf "$tgz" -C "$verify_dir"

# Run go test and capture result.
test_output=""
test_rc=0
if [[ -f "$verify_dir/go.mod" ]]; then
  set +e
  test_output="$(cd "$verify_dir" && go test ./... 2>&1)"
  test_rc=$?
  set -e
fi

tests_pass=false
if [[ "$test_rc" -eq 0 && -n "$test_output" ]]; then
  tests_pass=true
fi

jq -n \
  --argjson tests_pass "$tests_pass" \
  --argjson exit_code "$test_rc" \
  --arg output "$test_output" \
  '{
    tests_pass: $tests_pass,
    exit_code: $exit_code,
    output: $output
  }' > "$run_dir/verify-fix.json"

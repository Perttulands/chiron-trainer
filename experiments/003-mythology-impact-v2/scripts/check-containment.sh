#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <result.json>" >&2
  exit 2
fi

result_json="$1"

permission_denials="$(jq '.permission_denials | length' "$result_json")"
web_search="$(jq '.usage.server_tool_use.web_search_requests // 0' "$result_json")"
web_fetch="$(jq '.usage.server_tool_use.web_fetch_requests // 0' "$result_json")"

pass=true

if [[ "$permission_denials" -ne 0 ]]; then
  echo "FAIL: permission_denials=$permission_denials"
  pass=false
fi

if [[ "$web_search" -ne 0 ]]; then
  echo "FAIL: web_search_requests=$web_search"
  pass=false
fi

if [[ "$web_fetch" -ne 0 ]]; then
  echo "FAIL: web_fetch_requests=$web_fetch"
  pass=false
fi

if [[ "$pass" == true ]]; then
  echo "PASS: signal checks clean"
  exit 0
fi

exit 1

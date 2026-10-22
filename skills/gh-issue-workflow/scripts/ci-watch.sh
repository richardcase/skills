#!/usr/bin/env bash
# ci-watch.sh <pr-number> [--timeout SECONDS]
# Waits for the PR's checks, then prints JSON:
#   {"result":"pass"|"fail"|"timeout"|"none","failing":[{"name","link","run_id","log_tail","head_sha"}]}
# A failing run whose head_sha is not HEAD is stale: re-run it, do not fix code.
set -u
pr="${1:?pr number}"; timeout_s=1800
[ "${2:-}" = --timeout ] && timeout_s="${3:-1800}"
# watch returns non-zero on the first failure (--fail-fast) or when checks fail
timeout "$timeout_s" gh pr checks "$pr" --watch --fail-fast --interval 15 >/dev/null 2>&1; rc=$?
# gh exits 1 when a check failed, but still prints the JSON; keep it and validate it
checks=$(gh pr checks "$pr" --json name,state,link,workflow 2>/dev/null)
jq -e 'type == "array"' <<<"$checks" >/dev/null 2>&1 || checks='[]'
total=$(jq 'length' <<<"$checks")
failing=$(jq -c '[.[] | select(.state == "FAILURE" or .state == "ERROR" or .state == "CANCELLED")]' <<<"$checks")
nfail=$(jq 'length' <<<"$failing")
if [ "$total" -eq 0 ]; then result=none
elif [ "$rc" -eq 124 ]; then result=timeout
elif [ "$nfail" -gt 0 ]; then result=fail
else result=pass; fi
# attach a log tail per failing check when the link points at an Actions run
failing=$(jq -c '[.[] | . + {run_id: ((.link // "") | capture("/runs/(?<id>[0-9]+)")? .id // null)}]' <<<"$failing")
out='[]'
while IFS= read -r item; do
  [ -n "$item" ] || continue
  run_id=$(jq -r '.run_id // empty' <<<"$item")
  tail_txt=""; head_sha=""
  if [ -n "$run_id" ]; then
    tail_txt=$(gh run view "$run_id" --log-failed 2>/dev/null | tail -60 || true)
    head_sha=$(gh run view "$run_id" --json headSha -q .headSha 2>/dev/null || true)
  fi
  out=$(jq -c --argjson i "$item" --arg t "$tail_txt" --arg h "$head_sha" '. + [$i + {log_tail: $t, head_sha: $h}]' <<<"$out")
done < <(jq -c '.[]' <<<"$failing")
jq -cn --arg r "$result" --argjson f "$out" '{result:$r, failing:$f}'
[ "$result" = pass ] || [ "$result" = none ]

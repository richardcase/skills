#!/usr/bin/env bash
# status.sh [issue-url]
# Read-only report: detected stage, facts, review rounds, open items.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
url="${1:-}"
det=$(bash "$here/detect-stage.sh" "$url") || { echo "status.sh: detect-stage failed" >&2; exit 1; }
row() { printf '%-22s %s\n' "$1" "$2"; }
j() { jq -r "$1" <<<"$det"; }
row "stage" "$(j .stage) ($(j .note))"
row "issue" "$(j .facts.issue_url)  [$(j .facts.issue_state)]"
row "assignees" "$(j '.facts.assignees | join(", ") | if . == "" then "none" else . end')"
row "branch" "$(j .facts.branch)"
row "plan comment" "$(j '.facts.plan_comments')"
pr=$(j '.facts.pr // empty')
if [ -n "$pr" ]; then
  row "pr" "$(jq -r '"#\(.number) \(.state) \(.url)"' <<<"$pr")"
else
  row "pr" "none"
fi
sd=$(j '.facts.state_dir // empty')
if [ -n "$sd" ] && [ -f "$sd/state.json" ]; then
  s=$(cat "$sd/state.json")
  row "plan review" "$(jq -r '"codex round \(.plan_review.round // 0), result \(.plan_review.result // "pending")"' <<<"$s")"
  row "code review" "$(jq -r '"codex round \(.code_review.round // 0), result \(.code_review.result // "pending")"' <<<"$s")"
  [ -f "$sd/escalation.md" ] && row "escalation" "OPEN: $sd/escalation.md"
  ts=$(jq -r '.timestamps // {} | to_entries | map("\(.key)=\(.value)") | join(" ")' <<<"$s")
  [ -n "$ts" ] && row "timestamps" "$ts"
else
  row "state" "no state.json (not in the issue worktree)"
fi
if [ -n "$pr" ] && [ "$(jq -r .state <<<"$pr")" = OPEN ]; then
  prn=$(jq -r .number <<<"$pr")
  since=0; [ -n "${s:-}" ] && since=$(jq -r '.last_pr_comment_id // 0' <<<"$s")
  threads=$(bash "$here/pr-threads.sh" list "$prn" --since "$since" 2>/dev/null || echo '{}')
  row "unresolved threads" "$(jq -r '.unresolved_threads // [] | length' <<<"$threads")"
  row "new comments" "$(jq -r '((.new_comments // []) + (.new_reviews // [])) | length' <<<"$threads")"
  checks=$(gh pr checks "$prn" --json name,state 2>/dev/null || echo '[]')
  failing=$(jq -r '[.[] | select(.state == "FAILURE" or .state == "ERROR") | .name] | join(", ")' <<<"$checks")
  row "failing checks" "${failing:-none}"
  readiness=$(gh pr view "$prn" --json reviewDecision,mergeStateStatus,mergeable -q '"\(.reviewDecision // "NONE") \(.mergeStateStatus) \(.mergeable)"' 2>/dev/null || true)
  [ -n "$readiness" ] && row "merge readiness" "$readiness"
fi

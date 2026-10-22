#!/usr/bin/env bash
# detect-stage.sh [issue-url] [stage]
# Prints {"stage":..., "forced":bool, "facts":{...}, "note":...}.
# The stage comes from observable state: branch, state file, issue comments, PR.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
url="${1:-}"; forced="${2:-}"
sd=$(state_dir 2>/dev/null || true)
state="{}"; [ -n "$sd" ] && [ -f "$sd/state.json" ] && state=$(cat "$sd/state.json")
[ -z "$url" ] && url=$(jq -r '.issue_url // empty' <<<"$state")
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
owner=""; repo=""; number=""
if [ -n "$url" ]; then read -r owner repo number < <(issue_parts "$url") || true; fi
if [ -z "$number" ] && [[ "$branch" =~ ^issue-([0-9]+)$ ]]; then
  number="${BASH_REMATCH[1]}"
  nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  owner="${nwo%%/*}"; repo="${nwo#*/}"
  [ -n "$nwo" ] && url="https://github.com/$nwo/issues/$number"
fi
if [ -z "$number" ]; then
  jq -cn --arg b "$branch" '{stage:"start",forced:false,facts:{branch:$b},note:"no issue url given and not on an issue-N branch"}'
  exit 0
fi
on_issue_branch=false; [ "$branch" = "issue-$number" ] && on_issue_branch=true
herdr=false; [ "${HERDR_ENV:-}" = 1 ] && herdr=true
issue=$(gh issue view "$url" --json state,assignees,comments 2>/dev/null || echo '{}')
issue_state=$(jq -r '.state // "UNKNOWN"' <<<"$issue")
assignees=$(jq -c '[.assignees[]?.login]' <<<"$issue")
plans=$(jq '[.comments[]?.body | select(startswith("<!-- gh-issue-workflow: plan"))] | length' <<<"$issue")
retros=$(jq '[.comments[]?.body | select(startswith("<!-- gh-issue-workflow: retro"))] | length' <<<"$issue")
abandoned=$(jq '[.comments[]?.body | select(startswith("<!-- gh-issue-workflow: abandoned"))] | length' <<<"$issue")
pr=$(gh pr list --repo "$owner/$repo" --head "issue-$number" --state all --json number,state,url,isDraft,mergedAt 2>/dev/null | jq -c '.[0] // null')
pr_state=$(jq -r '.state // ""' <<<"$pr")
ready=null
if [ "$pr_state" = OPEN ]; then
  ready=$(gh pr view "$(jq -r .number <<<"$pr")" --repo "$owner/$repo" --json reviewDecision,mergeStateStatus,mergeable 2>/dev/null || echo null)
fi
decision=$(jq -r '.reviewDecision // ""' <<<"$ready"); mstate=$(jq -r '.mergeStateStatus // ""' <<<"$ready")
code_review=$(jq -r '.code_review.result // ""' <<<"$state")
standards=$(jq -r '.standards_review.result // ""' <<<"$state"); security=$(jq -r '.security_review.result // ""' <<<"$state")
reviews_done=false; [ "$code_review" = pass ] && [ -n "$standards" ] && [ -n "$security" ] && reviews_done=true

stage=""; note=""
if [ "$pr" != null ] && [ "$pr_state" != OPEN ] && [ "$retros" -gt 0 ]; then stage=done; note="PR $pr_state and retro posted"
elif [ "$pr" != null ] && [ "$pr_state" != OPEN ]; then stage=retro; note="PR $pr_state, no retro comment yet"
elif [ "$pr" != null ] && [ "$decision" = APPROVED ] && { [ "$mstate" = CLEAN ] || [ "$mstate" = UNSTABLE ]; }; then stage=merge; note="PR approved and $mstate"
elif [ "$pr" != null ]; then stage=feedback; note="PR open"
elif [ "$abandoned" -gt 0 ]; then stage=done; note="abandoned"
elif [ "$issue_state" = CLOSED ]; then stage=ask; note="issue is closed and has no PR; ask the user"
elif $on_issue_branch && [ "$plans" -gt 0 ] && $reviews_done; then stage=pr; note="plan posted, code, standards, and security reviews done"
elif $on_issue_branch && [ "$plans" -gt 0 ]; then stage=implement; note="plan posted"
elif $on_issue_branch; then stage=plan; note="on the issue branch, no plan comment"
elif $herdr; then stage=start; note="not on issue-$number; launch the worktree"
else stage=blocked; note="not on issue-$number and not inside Herdr; run the start stage from a Herdr pane"
fi
isforced=false
if [ -n "$forced" ]; then stage="$forced"; isforced=true; note="stage given on the command line"; fi
jq -cn --arg stage "$stage" --argjson forced "$isforced" --arg note "$note" \
  --arg url "$url" --arg owner "$owner" --arg repo "$repo" --arg number "$number" --arg branch "$branch" \
  --argjson on_issue_branch "$on_issue_branch" --argjson herdr "$herdr" --arg issue_state "$issue_state" \
  --argjson assignees "$assignees" --argjson plans "$plans" --argjson retros "$retros" --argjson abandoned "$abandoned" --argjson pr "$pr" --argjson ready "$ready" \
  --arg code_review "$code_review" --arg standards "$standards" --arg security "$security" --arg state_dir "${sd:-}" \
  '{stage:$stage,forced:$forced,note:$note,facts:{issue_url:$url,owner:$owner,repo:$repo,number:($number|tonumber),branch:$branch,on_issue_branch:$on_issue_branch,herdr_env:$herdr,issue_state:$issue_state,assignees:$assignees,plan_comments:$plans,retro_comments:$retros,abandoned_comments:$abandoned,pr:$pr,pr_readiness:$ready,code_review_result:$code_review,standards_review_result:$standards,security_review_result:$security,state_dir:$state_dir}}'

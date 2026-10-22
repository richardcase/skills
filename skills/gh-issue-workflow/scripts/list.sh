#!/usr/bin/env bash
# list.sh
# One row per issue-N worktree of the current repository: issue, stage, PR,
# workspace, last commit age. Read-only.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
command -v herdr >/dev/null || { echo "list.sh: herdr not on PATH" >&2; exit 1; }
wts=$(herdr worktree list 2>/dev/null) || { echo "list.sh: herdr worktree list failed" >&2; exit 1; }
printf '%-8s %-24s %-10s %-10s %-8s %s\n' ISSUE REPO STAGE PR WS LAST-COMMIT
jq -r '.result.worktrees[] | select(.branch | test("^issue-[0-9]+$")) | [.branch, .path, (.open_workspace_id // "-")] | @tsv' <<<"$wts" \
| while IFS=$'\t' read -r branch path ws; do
  n="${branch#issue-}"
  sd="$(git -C "$path" rev-parse --git-dir 2>/dev/null)/gh-issue-workflow"
  if [ -f "$sd/state.json" ]; then
    url=$(jq -r .issue_url "$sd/state.json"); repo=$(jq -r '"\(.owner)/\(.repo)"' "$sd/state.json")
    det=$(cd "$path" && bash "$here/detect-stage.sh" "$url" 2>/dev/null || echo '{"stage":"unknown"}')
    stage=$(jq -r .stage <<<"$det")
    pr=$(jq -r '.facts.pr // empty | "#\(.number) \(.state | ascii_downcase)"' <<<"$det"); pr="${pr:-none}"
  else
    repo="?"; stage="unknown"; pr="?"
  fi
  age=$(git -C "$path" log -1 --format=%cr 2>/dev/null || echo "-")
  printf '%-8s %-24s %-10s %-10s %-8s %s\n' "#$n" "$repo" "$stage" "$pr" "$ws" "$age"
done

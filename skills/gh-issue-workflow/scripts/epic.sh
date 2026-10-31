#!/usr/bin/env bash
# epic.sh children <issue-url>          prints the child issue urls (sub-issues API, task-list refs, "blocked by #N")
# epic.sh init <parent-url> <url>...    writes epic-N.json in the main clone's .git/gh-issue-workflow with the order
# epic.sh file <parent-url>             prints the epic file path
# epic.sh next <parent-url>             prints the next child url not yet done, or nothing
# epic.sh mark <parent-url> <child-url> <stage> [pr-url]   records a child's stage and PR
# epic.sh table <parent-url>            prints the markdown status table for the parent comment
set -eu
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
epic_dir() { local common; common=$(git rev-parse --git-common-dir); printf '%s/gh-issue-workflow\n' "$(cd "$common" && pwd)"; }
cmd="${1:?children|init|file|next|mark|table}"; shift
case "$cmd" in
  children)
    url="${1:?parent url}"; read -r owner repo n < <(issue_parts "$url")
    { gh api "repos/$owner/$repo/issues/$n/sub_issues" --jq '.[].number' 2>/dev/null || true
      gh issue view "$url" --json body -q .body 2>/dev/null | grep -oE '(^- \[[ x]\] #[0-9]+|[Bb]locked by #[0-9]+|[Dd]epends on #[0-9]+)' | grep -oE '[0-9]+$' || true
    } | awk '!seen[$0]++' | while read -r m; do printf 'https://github.com/%s/%s/issues/%s\n' "$owner" "$repo" "$m"; done;;
  init)
    url="${1:?parent url}"; shift; read -r owner repo n < <(issue_parts "$url")
    d=$(epic_dir); mkdir -p "$d"; f="$d/epic-$n.json"
    jq -n --arg url "$url" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --args '{parent_url:$url, created:$now, order:$ARGS.positional, children:($ARGS.positional | map({url:., stage:"pending", pr:null}))}' "$@" > "$f"
    printf '%s\n' "$f";;
  file) url="${1:?parent url}"; read -r _ _ n < <(issue_parts "$url"); printf '%s/epic-%s.json\n' "$(epic_dir)" "$n";;
  next) url="${1:?parent url}"; f=$(bash "$0" file "$url"); jq -r '[.children[] | select(.stage != "done" and .stage != "abandoned")][0].url // empty' "$f";;
  mark)
    url="${1:?parent url}"; child="${2:?child url}"; stage="${3:?stage}"; pr="${4:-}"
    f=$(bash "$0" file "$url"); tmp=$(mktemp)
    jq --arg c "$child" --arg s "$stage" --arg pr "$pr" '.children |= map(if .url == $c then .stage = $s | .pr = (if $pr == "" then .pr else $pr end) else . end)' "$f" > "$tmp" && mv "$tmp" "$f";;
  table)
    url="${1:?parent url}"; f=$(bash "$0" file "$url")
    jq -r '"| # | Child | Stage | PR |", "| --- | --- | --- | --- |", (.children | to_entries[] | "| \(.key + 1) | \(.value.url | sub(".*/issues/"; "#")) | \(.value.stage) | \(.value.pr // "-") |")' "$f";;
  *) echo "epic.sh: unknown command $cmd" >&2; exit 2;;
esac

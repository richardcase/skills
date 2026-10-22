#!/usr/bin/env bash
# progress.sh post <plan.md>        posts the task checklist on the issue; stores the comment id in state.json
# progress.sh tick <k> <sha>        ticks task k and appends its commit sha
# progress.sh link <pr-url>         appends the PR link
# progress.sh show                  prints the current comment body
# Tasks are the "### Task k: <title>" headings of plan.md.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
sd=$(state_dir); st="$sd/state.json"; body="$sd/progress.md"
owner=$(jq -r .owner "$st"); repo=$(jq -r .repo "$st"); n=$(jq -r .number "$st")
cmd="${1:?post|tick|link|show}"; shift
case "$cmd" in
  post)
    plan="${1:?plan.md}"
    { echo "<!-- gh-issue-workflow: progress v1 -->"
      echo "## Progress on #$n"
      grep -E '^### Task [0-9]+:' "$plan" | sed -E 's/^### Task ([0-9]+): (.*)$/- [ ] Task \1: \2/'
    } > "$body"
    id=$(gh api "repos/$owner/$repo/issues/$n/comments" -F body=@"$body" --jq .id)
    bash "$here/state.sh" set .progress_comment_id "$id" >/dev/null
    echo "$id";;
  tick)
    k="${1:?task number}"; sha="${2:?sha}"
    sed -i -E "s/^- \[ \] Task $k: (.*)$/- [x] Task $k: \1 (\`$sha\`)/" "$body"
    id=$(jq -r .progress_comment_id "$st")
    gh api -X PATCH "repos/$owner/$repo/issues/comments/$id" -F body=@"$body" --jq .html_url;;
  link)
    url="${1:?pr url}"
    printf '\nPR: %s\n' "$url" >> "$body"
    id=$(jq -r .progress_comment_id "$st")
    gh api -X PATCH "repos/$owner/$repo/issues/comments/$id" -F body=@"$body" --jq .html_url;;
  show) cat "$body";;
  *) echo "progress.sh: unknown command $cmd" >&2; exit 2;;
esac

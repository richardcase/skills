#!/usr/bin/env bash
# base-sync.sh <base-branch>
# Fetches origin/<base> and prints {"base","behind","ahead","conflicts"}.
# behind > 0 means the branch needs a rebase; conflicts true means the
# rebase will stop on at least one file. Exit 1 when behind, 0 otherwise.
set -u
base="${1:?base branch}"
git fetch -q origin "$base" || { echo "base-sync.sh: fetch failed" >&2; exit 2; }
read -r behind ahead < <(git rev-list --left-right --count "origin/$base...HEAD")
conflicts=false
if [ "$behind" -gt 0 ]; then
  # git merge-tree --write-tree exits 1 when the merge would conflict (git 2.38+)
  git merge-tree --write-tree --quiet "origin/$base" HEAD >/dev/null 2>&1; mt=$?
  [ "$mt" -eq 1 ] && conflicts=true
  [ "$mt" -gt 1 ] && echo "base-sync.sh: merge-tree unavailable, conflicts unknown" >&2
fi
jq -cn --arg base "$base" --argjson behind "$behind" --argjson ahead "$ahead" --argjson conflicts "$conflicts" \
  '{base:$base,behind:$behind,ahead:$ahead,conflicts:$conflicts}'
[ "$behind" -eq 0 ]

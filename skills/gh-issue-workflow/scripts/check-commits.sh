#!/usr/bin/env bash
# check-commits.sh <base-ref> [--allow-dco]
# Checks every commit in <base-ref>..HEAD against the commit contract:
# conventional subject, 72 chars max, no trailing period, a body, a good
# signature, and no agent footers. Exits 1 and lists each problem.
set -u
base="${1:?usage: check-commits.sh <base-ref> [--allow-dco]}"; allow_dco=false
[ "${2:-}" = --allow-dco ] && allow_dco=true
types="${GH_ISSUE_WORKFLOW_TYPES:-feat|fix|docs|test|refactor|chore|ci|build|perf|revert}"
subject_re="^($types)(\([A-Za-z0-9._/-]+\))?!?: [^ ].*[^.]$"
fail=0
problem() { echo "FAIL $1: $2"; fail=1; }
for sha in $(git rev-list --reverse --no-merges "$base..HEAD"); do
  short=$(git rev-parse --short "$sha")
  subject=$(git log -1 --format=%s "$sha")
  body=$(git log -1 --format=%b "$sha")
  sig=$(git log -1 --format=%G? "$sha")
  [[ "$subject" =~ $subject_re ]] || problem "$short" "subject is not '<type>(<scope>): <summary>' with no trailing period: '$subject'"
  [ ${#subject} -le 72 ] || problem "$short" "subject is ${#subject} chars, max 72"
  [ -n "$(tr -d '[:space:]' <<<"$body")" ] || problem "$short" "commit has no body; say what changed and why"
  case "$sig" in G|U) ;; *) problem "$short" "signature status is '$sig' (want G or U); the commit is not signed or the key is unknown";; esac
  if grep -qiE '^(co-authored-by|generated with|🤖)' <<<"$body"; then problem "$short" "agent footer found in the body"; fi
  if ! $allow_dco && grep -qiE '^signed-off-by:' <<<"$body"; then problem "$short" "Signed-off-by trailer present; pass --allow-dco only when the repo requires DCO"; fi
  if grep -qE '(^|[^a-z])(closes|fixes|resolves) #[0-9]+' <<<"$(tr 'A-Z' 'a-z' <<<"$subject $body")"; then problem "$short" "issue reference in the commit; put Closes #N in the PR body only"; fi
done
[ $fail -eq 0 ] && echo "OK $(git rev-list --count --no-merges "$base..HEAD") commit(s) in $base..HEAD pass the contract"
exit $fail

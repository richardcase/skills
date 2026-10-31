#!/usr/bin/env bash
# check-pr-body.sh <file>
# Checks a PR body: no agent footer, and Simplified Technical English through
# the simplified-technical-english skill's checker. Exit 0 = clean.
set -u
file="${1:?usage: check-pr-body.sh <file>}"
fail=0
if grep -qiE '^[[:space:]]*(co-authored-by:|generated with|🤖)' "$file"; then echo "FAIL agent footer found in $file"; fail=1; fi
d=""
for c in "${CREATE_PR_STE_DIR:-}" "$HOME/.claude/skills/simplified-technical-english" "$PWD/.claude/skills/simplified-technical-english" "$HOME/.agents/skills/simplified-technical-english" "$HOME"/.claude/plugins/cache/*/*/*/skills/simplified-technical-english; do
  [ -n "$c" ] && [ -f "$c/scripts/ste_check.py" ] && { d="$c"; break; }
done
if [ -z "$d" ]; then
  echo "FAIL simplified-technical-english skill not installed; run: npx skills@latest add 0xpili/skills --skill simplified-technical-english" >&2
  exit 2
fi
python3 -I "$d/scripts/ste_check.py" --mode descriptive --word-list "$d/references/word-list.md" "$file" || fail=1
[ $fail -eq 0 ] && echo "OK $file"
exit $fail

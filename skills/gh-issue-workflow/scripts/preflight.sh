#!/usr/bin/env bash
# preflight.sh <stage|all>
# Checks the binaries, logins, skills, and git settings a stage needs.
# Prints one JSON object and exits 1 when a required item is missing.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
stage="${1:-all}"
missing=(); warnings=()
need() { missing+=("$(jq -cn --arg i "$1" --arg f "$2" '{item:$i,fix:$f}')"); }
warn() { warnings+=("$(jq -cn --arg w "$1" '$w')"); }
# start is the entry point: it checks everything the later stages need, so a
# missing dependency stops the run before a worktree exists.
for_stage() { local s; for s in "$@"; do [ "$stage" = all ] || [ "$stage" = start ] || [ "$stage" = "$s" ] && return 0; done; return 1; }

for b in git gh jq python3; do command -v "$b" >/dev/null || need "binary $b" "install $b"; done
if for_stage start abandon; then
  command -v herdr >/dev/null || need "binary herdr" "install Herdr and run this from a Herdr pane"
  [ "${HERDR_ENV:-}" = 1 ] || need "HERDR_ENV=1" "run this stage from a pane inside Herdr"
fi
if for_stage plan implement; then
  if command -v codex >/dev/null; then
    codex login status >/dev/null 2>&1 || [ -f "$HOME/.codex/auth.json" ] || need "codex login" "run: codex login"
  else
    need "binary codex" "install the Codex CLI (npm i -g @openai/codex) and run: codex login"
  fi
fi
if command -v gh >/dev/null; then
  gh auth status >/dev/null 2>&1 || need "gh login" "run: gh auth login"
fi
if for_stage implement pr feedback merge; then
  [ "$(git config --get commit.gpgsign 2>/dev/null)" = true ] || need "git commit.gpgsign=true" "run: git config --global commit.gpgsign true"
  [ -n "$(git config --get user.signingkey 2>/dev/null)" ] || need "git user.signingkey" "set git user.signingkey to your GPG key id or SSH public key path"
fi

skills_for() {
  case "$1" in
    plan) echo grilling superpowers:writing-plans simplified-technical-english;;
    implement) echo superpowers:executing-plans superpowers:verification-before-completion;;
    pr|retro|merge|abandon) echo simplified-technical-english;;
    feedback) echo superpowers:receiving-code-review simplified-technical-english;;
    start|all) echo grilling superpowers:writing-plans superpowers:executing-plans superpowers:verification-before-completion superpowers:receiving-code-review simplified-technical-english;;
  esac
}
for s in $(skills_for "$stage"); do
  find_skill_dir "$s" >/dev/null || case "$s" in
    superpowers:*) need "skill $s" "run: claude plugin install superpowers";;
    grilling) need "skill grilling" "run: npx skills@latest add mattpocock/skills --skill grilling";;
    simplified-technical-english) need "skill simplified-technical-english" "run: npx skills@latest add 0xpili/skills --skill simplified-technical-english";;
    *) need "skill $s" "install the $s skill";;
  esac
done
if for_stage plan pr feedback retro merge abandon; then
  d=$(find_skill_dir simplified-technical-english 2>/dev/null || true)
  [ -n "$d" ] && [ ! -f "$d/scripts/ste_check.py" ] && need "ste_check.py" "reinstall simplified-technical-english; scripts/ste_check.py is missing"
fi

# MCP servers: none are required. Report GitHub-related ones so the user knows gh is used instead.
if command -v claude >/dev/null && [ "${GH_ISSUE_WORKFLOW_SKIP_MCP:-}" != 1 ]; then
  m=$(timeout 20 claude mcp list 2>/dev/null | grep -iE 'github' | cut -d: -f1 | tr '\n' ',' || true)
  [ -n "$m" ] && warn "MCP servers ${m%,} are configured; this skill uses gh, not MCP"
fi

ok=true; [ ${#missing[@]} -eq 0 ] || ok=false
jq -cn --arg stage "$stage" --argjson ok "$ok" \
  --argjson missing "[$(IFS=,; echo "${missing[*]-}")]" \
  --argjson warnings "[$(IFS=,; echo "${warnings[*]-}")]" \
  '{stage:$stage,ok:$ok,missing:$missing,warnings:$warnings}'
$ok

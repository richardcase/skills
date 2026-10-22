#!/usr/bin/env bash
# Shared helpers for gh-issue-workflow scripts. Source it; do not run it.

# Evals (claude plugin eval) can only set EVAL_* variables, so EVAL_HERDR_ENV
# stands in for HERDR_ENV there. Nothing else reads it.
[ -z "${HERDR_ENV:-}" ] && [ -n "${EVAL_HERDR_ENV:-}" ] && export HERDR_ENV="$EVAL_HERDR_ENV"

# Directories that can hold installed skills. Override with a colon-separated
# GH_ISSUE_WORKFLOW_SKILL_DIRS for tests.
skill_dirs() {
  if [ -n "${GH_ISSUE_WORKFLOW_SKILL_DIRS:-}" ]; then
    tr ':' '\n' <<<"$GH_ISSUE_WORKFLOW_SKILL_DIRS"
    return
  fi
  printf '%s\n' "$HOME/.claude/skills" "$PWD/.claude/skills" "$HOME/.agents/skills"
  local d
  for d in "$HOME"/.claude/plugins/cache/*/*/*/skills; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

# find_skill_dir <name>  -> prints the directory that holds SKILL.md, or fails.
# A namespaced name such as superpowers:writing-plans prefers a plugin dir
# whose path contains the namespace.
find_skill_dir() {
  local name="$1" ns="" bare="$1" d hit=""
  case "$name" in *:*) ns="${name%%:*}"; bare="${name#*:}";; esac
  while IFS= read -r d; do
    [ -f "$d/$bare/SKILL.md" ] || continue
    if [ -n "$ns" ] && [[ "$d" == *"/$ns/"* ]]; then printf '%s\n' "$d/$bare"; return 0; fi
    [ -z "$hit" ] && hit="$d/$bare"
  done < <(skill_dirs)
  [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
  return 1
}

# state_dir -> the per-worktree state directory (never committed).
state_dir() {
  local g
  g=$(git rev-parse --git-dir 2>/dev/null) || return 1
  printf '%s/gh-issue-workflow\n' "$(cd "$g" && pwd)"
}

# issue_parts <url> -> "owner repo number"
issue_parts() {
  local url="$1"
  if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
    printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  else
    return 1
  fi
}

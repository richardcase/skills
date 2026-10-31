#!/usr/bin/env bash
# run-local.sh [case ...]
# Runs eval cases headlessly with `claude -p`, the stub gh/herdr/codex on PATH,
# and the case's scaffold in a temp workspace. Uses the same prompt.md and
# graders/*.md files as `claude plugin eval`, which cannot put stubs on PATH.
# Regex graders on workspace files are scored here; tool_used and llm graders
# are printed for manual review. EVAL_MODEL picks the model (default sonnet).
# A case.yaml `skill:` line picks the skill (default gh-issue-workflow).
# EVAL_NO_SKILL=1 runs the prompt without the skill, for a baseline.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$(cd "$here/.." && pwd)"
model="${EVAL_MODEL:-sonnet}"
if [ $# -gt 0 ]; then cases=("$@"); else
  mapfile -t cases < <(find "$here" -mindepth 2 -maxdepth 2 -name prompt.md -printf '%h\n' | xargs -n1 basename | sort)
fi
fm() { awk -v key="$2" 'BEGIN{f=0} /^---$/{f++; next} f==1 && $0 ~ "^"key":" {sub("^"key":[ ]*",""); print; exit}' "$1"; }
body() { awk 'BEGIN{f=0} /^---$/{f++; next} f>=2{print}' "$1"; }
pass=0; fail=0; manual=0
for c in "${cases[@]}"; do
  dir="$here/$c"; [ -f "$dir/prompt.md" ] || { echo "no such case: $c" >&2; continue; }
  ws=$(mktemp -d "${TMPDIR:-/tmp}/giw-eval-$c.XXXX")
  skill_name=$(awk '/^skill:/{print $2}' "$dir/case.yaml" 2>/dev/null); skill="$root/skills/${skill_name:-gh-issue-workflow}"
  # preflight-* cases hide codex: stubs without it, and a minimal PATH so the real one is not found
  stubs="$here/stubs/bin"; base_path="$PATH"
  case "$c" in preflight-*) stubs="$here/stubs/bin-nocodex"; base_path="$(dirname "$(command -v claude)"):/usr/local/bin:/usr/bin:/bin";; esac
  tools=$(fm "$dir/prompt.md" allowed_tools | tr -d '[]' | tr -d ' '); tools="Read,Glob,Grep,Skill,${tools:-Bash}"
  turns=$(fm "$dir/prompt.md" max_turns); turns="${turns:-20}"
  sysp=$(fm "$dir/prompt.md" append_system_prompt | sed -e 's/^"//' -e 's/"$//')
  if grep -q 'scaffold_script' "$dir/case.yaml" 2>/dev/null; then
    (cd "$ws" && bash "$dir/$(grep scaffold_script "$dir/case.yaml" | awk '{print $2}')")
  fi
  envs=$(awk 'BEGIN{f=0} /^---$/{f++; next} f==1 && /^  EVAL_[A-Z0-9_]+:/ {gsub(/[ "]/,""); sub(":","="); print}' "$dir/prompt.md")
  load="Read the skill at $skill/SKILL.md first and follow it exactly; treat it as an installed skill the user invoked. Its SKILL_DIR is $skill. "
  [ "${EVAL_NO_SKILL:-}" = 1 ] && load=""
  prompt="${load}Sandbox: the GitHub repo acme/widgets does not exist; gh, herdr, and codex are stub programs on PATH that print canned output and log their calls to ./calls.log. Stay inside the current directory. Set GH_ISSUE_WORKFLOW_SKIP_MCP=1 for the preflight.

$(body "$dir/prompt.md")"
  echo "== $c  (workspace $ws)"
  args=(-p "$prompt" --model "$model" --allowedTools "$tools" --max-turns "$turns")
  [ -n "$sysp" ] && args+=(--append-system-prompt "$sysp")
  ( cd "$ws"; export PATH="$stubs:$base_path" EVAL_FIXTURE_LOG="$ws/calls.log" GH_ISSUE_WORKFLOW_SKIP_MCP=1
    for kv in $envs; do export "$kv"; done
    claude "${args[@]}" < /dev/null > "$ws/reply.md" 2> "$ws/stderr.log" ) || echo "   claude exited $? (see $ws/stderr.log)"
  for g in "$dir"/graders/*.md; do
    name=$(basename "$g" .md); type=$(fm "$g" type)
    case "$type" in
      regex)
        path=$(awk '/^  path:/{print $2}' "$g"); pattern=$(fm "$g" pattern | sed -e 's/^"//' -e 's/"$//' -e 's/\\\\/\\/g'); mode=$(fm "$g" match)
        if [ -f "$ws/$path" ] && grep -Pzoq "$pattern" "$ws/$path" 2>/dev/null; then hit=1; else hit=0; fi
        if { [ "$mode" = not_contains ] && [ $hit -eq 0 ]; } || { [ "$mode" != not_contains ] && [ $hit -eq 1 ]; }; then echo "   PASS $name"; pass=$((pass+1)); else echo "   FAIL $name"; fail=$((fail+1)); fi;;
      tool_used)
        im=$(fm "$g" input_match | sed -e "s/^'//" -e "s/'$//")
        if grep -q "$(printf '%s' "$im" | sed 's/\\\././g')" "$ws/calls.log" "$ws/reply.md" 2>/dev/null; then echo "   PASS $name (seen in log or reply)"; pass=$((pass+1)); else echo "   MANUAL $name: check $ws/reply.md for $im"; manual=$((manual+1)); fi;;
      llm) echo "   MANUAL $name: judge $ws/reply.md against the criteria in $g"; manual=$((manual+1));;
      *) echo "   MANUAL $name: grader type $type not scored here"; manual=$((manual+1));;
    esac
  done
done
echo "== pass $pass  fail $fail  manual $manual"
[ $fail -eq 0 ]

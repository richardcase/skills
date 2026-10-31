#!/usr/bin/env bash
# state.sh get <jq-path>            prints a value from state.json
# state.sh set <jq-path> <json>     sets a value (json literal, e.g. '"pr"' or 3)
# state.sh stamp <event>            sets timestamps.<event> to now (ISO 8601 UTC)
# state.sh path                     prints the state.json path
# Works on the state.json of the current worktree (see lib.sh state_dir).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
sd=$(state_dir) || { echo "state.sh: not inside a git worktree" >&2; exit 1; }
f="$sd/state.json"
cmd="${1:?get|set|stamp|path}"; shift
case "$cmd" in
  path) printf '%s\n' "$f";;
  get) [ -f "$f" ] || { echo "state.sh: $f missing" >&2; exit 1; }; jq -r "${1:?jq path}" "$f";;
  set)
    [ -f "$f" ] || { echo "state.sh: $f missing" >&2; exit 1; }
    tmp=$(mktemp); jq --argjson v "${2:?json value}" "${1:?jq path} = \$v" "$f" > "$tmp" && mv "$tmp" "$f";;
  stamp)
    [ -f "$f" ] || { echo "state.sh: $f missing" >&2; exit 1; }
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    tmp=$(mktemp); jq --arg k "${1:?event}" --arg now "$now" '.timestamps[$k] = $now' "$f" > "$tmp" && mv "$tmp" "$f"
    printf '%s\n' "$now";;
  *) echo "state.sh: unknown command $cmd" >&2; exit 2;;
esac

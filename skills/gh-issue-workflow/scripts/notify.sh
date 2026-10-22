#!/usr/bin/env bash
# notify.sh <event> "<title>" "<body>"
# Shows a Herdr notification. Events that need the user get the "request"
# sound; completions get "done". A no-op (exit 0) outside Herdr.
set -u
event="${1:?event}"; title="${2:?title}"; body="${3:-}"
case "$event" in
  gate|escalation|ci-red|preflight-fail) sound=request;;
  plan-posted|pr-opened|feedback-done|merged|retro-posted|worker-ready) sound=done;;
  *) echo "notify.sh: unknown event '$event'" >&2; exit 2;;
esac
[ "${HERDR_ENV:-}" = 1 ] || exit 0
command -v herdr >/dev/null || exit 0
herdr notification show "$title" --body "$body" --sound "$sound" >/dev/null 2>&1 || true
exit 0

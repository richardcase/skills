#!/usr/bin/env bash
# metrics.sh append <state-dir> <merged|closed|abandoned>
#   Appends one JSON line for the issue to the global metrics file.
# metrics.sh summary [--repo OWNER/REPO]
#   Prints counts and medians per repo and overall.
# File: ${GH_ISSUE_WORKFLOW_METRICS:-$HOME/.local/share/gh-issue-workflow/metrics.jsonl}
set -eu
file="${GH_ISSUE_WORKFLOW_METRICS:-$HOME/.local/share/gh-issue-workflow/metrics.jsonl}"
cmd="${1:?append|summary}"; shift
case "$cmd" in
  append)
    sd="${1:?state dir}"; outcome="${2:?merged|closed|abandoned}"
    st="$sd/state.json"; [ -f "$st" ] || { echo "metrics.sh: $st missing" >&2; exit 1; }
    count_lines() { [ -f "$1" ] && grep -c "$2" "$1" || echo 0; }
    cfix=0; creb=0
    for f in "$sd"/codex-code-r*-dispositions.md; do [ -f "$f" ] || continue; cfix=$((cfix + $(grep -c -- '— fixed —' "$f" || true))); creb=$((creb + $(grep -c -- '— rebutted —' "$f" || true))); done
    pfix=0; preb=0
    for f in "$sd"/codex-plan-r*-dispositions.md; do [ -f "$f" ] || continue; pfix=$((pfix + $(grep -c -- '— fixed —' "$f" || true))); preb=$((preb + $(grep -c -- '— rebutted —' "$f" || true))); done
    mkdir -p "$(dirname "$file")"
    jq -c --arg outcome "$outcome" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson pfix "$pfix" --argjson preb "$preb" --argjson cfix "$cfix" --argjson creb "$creb" '
      def hours(a; b): if (a and b) then (((b|fromdateiso8601) - (a|fromdateiso8601)) / 3600 | . * 10 | round / 10) else null end;
      {recorded_at: $now,
       repo: "\(.owner)/\(.repo)", number: .number, outcome: $outcome,
       plan_rounds: (.plan_review.round // 0), plan_fixed: $pfix, plan_rebutted: $preb,
       claude_plan_findings: (.plan_review.claude_findings.total // null),
       code_rounds: (.code_review.round // 0), code_fixed: $cfix, code_rebutted: $creb,
       standards_findings: (.standards_review.findings.total // null),
       security_findings: (.security_review.findings.total // null),
       ci_attempts: (.ci.attempts // 0),
       hours_to_plan: hours(.timestamps.start; .timestamps.plan_posted),
       hours_to_pr: hours(.timestamps.start; .timestamps.pr_opened),
       hours_pr_to_merge: hours(.timestamps.pr_opened; .timestamps.merged),
       hours_total: hours(.timestamps.start; (.timestamps.merged // .timestamps.retro))}' "$st" >> "$file"
    tail -1 "$file";;
  summary)
    repo=""; [ "${1:-}" = --repo ] && repo="${2:-}"
    [ -f "$file" ] || { echo "no metrics recorded yet ($file)"; exit 0; }
    jq -rs --arg repo "$repo" '
      def median: if length == 0 then null else (sort | if length % 2 == 1 then .[length/2|floor] else (.[length/2-1] + .[length/2]) / 2 end) end;
      def med(f): [.[] | f | select(. != null)] | median;
      def row(name): "\(name)\t\(length)\t\([.[] | select(.outcome=="merged")] | length)\t\(med(.plan_rounds))\t\(med(.code_rounds))\t\(med(.ci_attempts))\t\(med(.hours_to_pr))\t\(med(.hours_pr_to_merge))";
      (if $repo == "" then . else map(select(.repo == $repo)) end) as $all
      | ["repo\tissues\tmerged\tplan_rounds\tcode_rounds\tci_attempts\th_to_pr\th_pr_to_merge"]
        + ($all | group_by(.repo) | map(row(.[0].repo)))
        + [($all | row("ALL"))]
      | .[]' "$file" | column -t -s $'\t';;
  *) echo "metrics.sh: unknown command $cmd" >&2; exit 2;;
esac

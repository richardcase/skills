# Review loops

Two loops use the same shape: the plan loop (stage `plan`) and the code loop (stage `implement`). `KIND` is `plan` or `code`. The cap is 3 rounds for each.

## Finding format

Every reviewer (the Claude plan reviewer and both Codex prompts) reports in this format. Parse it; do not paraphrase it.

```
## Findings
### F1: <title>
- severity: blocking | should | nit
- location: <file:line | plan section>
- claim: <one sentence>
- evidence: <what in the repo/plan shows it>
## Verdict: PASS | FAIL
```

## Round

```
round = state.<KIND>_review.round + 1      # write it to state.json BEFORE calling codex
```

Plan review (prompt on stdin, plan and previous dispositions appended):

```bash
{ cat "$SKILL_DIR/prompts/codex-plan-review.md"
  echo "# Issue"; gh issue view "$URL" --json title,body -q '"\(.title)\n\n\(.body)"'
  echo; echo "# Plan"; cat "$STATE_DIR/plan.md"
  if [ -f "$STATE_DIR/codex-plan-r$((round-1))-dispositions.md" ]; then
    echo; echo "# Previous dispositions"; cat "$STATE_DIR/codex-plan-r$((round-1))-dispositions.md"; fi
} | codex exec -m gpt-6-sol -c model_reasoning_effort="medium" -s read-only -C "$WT_PATH" --ephemeral \
      -o "$STATE_DIR/codex-plan-r$round.md" -
```

Code review (commit first; codex reviews the branch against the base):

```bash
{ cat "$SKILL_DIR/prompts/codex-code-review.md"
  if [ -f "$STATE_DIR/codex-code-r$((round-1))-dispositions.md" ]; then
    echo; echo "# Previous dispositions"; cat "$STATE_DIR/codex-code-r$((round-1))-dispositions.md"; fi
} > "$STATE_DIR/codex-code-r$round-prompt.md"
codex exec review -m gpt-6-sol -c model_reasoning_effort="medium" --base "$BASE" \
  "$(cat "$STATE_DIR/codex-code-r$round-prompt.md")" | tee "$STATE_DIR/codex-code-r$round.md"
```

If `codex exec review` rejects a flag, run `codex exec review --help` once, adapt, and note the working form in the retro.

## Dispositions

Write `$STATE_DIR/codex-<KIND>-r<round>-dispositions.md`, one line per finding, in this form:

```
F1 — fixed — <commit sha | plan section changed>
F2 — rebutted — <evidence: file:line, test output, or a quote from the issue>
F3 — deferred — nit, out of scope for this issue
```

A rebuttal cites something the next reviewer can check. "I disagree" is not a disposition. `deferred` is for `nit` and `should` only.

## Exit rules

- **pass:** after dispositions, no `blocking` finding is open. Set `state.<KIND>_review.result = "pass"`.
- **escalated:** round is 3 and a `blocking` finding is still open. Write `$STATE_DIR/escalation.md` with, per open finding: the reviewer's claim, your position, and a recommended decision. Run `bash "$SKILL_DIR/scripts/notify.sh" escalation "issue $N: review escalation" "<count> blocking finding(s) open after 3 rounds"`. Show it to the user and ask for a decision per finding. Their decisions become dispositions. No further rounds unless they ask.
- otherwise: fix (edit `plan.md`, or commit code changes per the contract) and start the next round.

A `blocking` finding is open when it is not fixed and either not rebutted, or re-raised by codex after a rebuttal. The second case stops you from certifying your own rebuttal: a rebuttal codex rejects is the user's call.

The plan is not posted, and the PR is not opened, while an escalation is undecided.

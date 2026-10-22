---
name: gh-issue-workflow
description: Use when the user gives a GitHub issue URL and wants it worked through to a merged pull request, or re-invokes the skill inside an issue worktree to continue (plan, implement, open the PR, answer review comments, write the retro). Triggers include "work on issue", "take issue N", "continue the issue", "address the review", "do the retro". Needs gh, codex, and a Herdr pane (HERDR_ENV=1) for the first stage.
---

# GitHub issue workflow

One issue URL in, a merged PR and a retro out. The process is a state machine whose stages leave evidence on GitHub (assignee, plan comment, PR, retro comment) or in a state directory inside the worktree. Any session can pick it up by reading that evidence.

## Usage

```
/gh-issue-workflow https://github.com/<owner>/<repo>/issues/<N> [start|plan|implement|pr|feedback|retro]
/gh-issue-workflow status <url>     # read-only: stage, facts, open items (scripts/status.sh)
/gh-issue-workflow list             # read-only: every issue-N worktree of this repo (scripts/list.sh)
```

The stage word is optional and forces a stage. Without it, the stage is detected. `status` and `list` never mutate anything and skip the stage checklist.

## Every invocation

1. `SKILL_DIR` is the directory of this file. Scripts run as `bash "$SKILL_DIR/scripts/<name>.sh"`.
2. `bash "$SKILL_DIR/scripts/preflight.sh" <stage>`. Exit 1 means stop: print each missing item with its fix and end the turn. Also confirm each skill it names appears in your available-skills list.
3. `bash "$SKILL_DIR/scripts/detect-stage.sh" <url> [stage]` and read `.stage`.
4. Read that stage's section in `references/stages.md` and do exactly what it says. Do not improvise commands or flags.

## Stage detection

| Evidence | Stage |
| --- | --- |
| PR merged or closed, retro comment present | done |
| PR merged or closed, no retro comment | retro |
| PR open | feedback |
| no PR, on `issue-N`, plan comment, code review passed | pr |
| no PR, on `issue-N`, plan comment | implement |
| no PR, on `issue-N`, no plan comment | plan |
| not on `issue-N`, inside Herdr | start |
| not on `issue-N`, not inside Herdr | stop: run from a Herdr pane |

## Standing rules

- Preflight first, every stage; `start` checks the needs of every stage. A missing dependency stops the run. There is no substitute reviewer and no skipped grilling.
- The launcher (`start`) assigns, creates the worktree, starts the worker, and hands off by naming this skill. It never plans.
- Branch is `issue-N`. Worktree and state live where `references/stages.md` says.
- Grilling is mandatory in `plan`, however small the issue.
- Review loops cap at 3 rounds, then the user decides. See `references/review-loops.md`.
- Two gates where the worker ends its turn and waits for "go": after the plan comment, and before push plus `gh pr create`.
- Every gate, escalation, and completion calls `scripts/notify.sh` so the user hears it from Herdr. Outside Herdr the call is a no-op.
- Commits and PR follow `references/commit-pr-contract.md`: signed, conventional, STE body, no agent footers, `Closes #N` only in the PR body, PR ready for review.
- Codex runs as `codex exec ... -m gpt-6-sol -c model_reasoning_effort="medium"` with a read-only sandbox.

## Red flags

| Thought | Reality |
| --- | --- |
| "codex is not installed; I'll note it for the next stage" | Preflight failed. Stop and print the fix. |
| "I'll add `--workspace` and `--cwd` so the log shows intent" | Only the commands in `stages.md`. Unknown flags fail on the real CLI. |
| "`fix/7-widget-count` is a better branch name" | `issue-N`. Detection depends on it. |
| "I'll spell out the remaining process in the handoff" | The handoff names the skill. The worker loads it. |
| "This issue is a one-liner, no questions needed" | Small issue, small frontier. Grill anyway. |
| "Codex is always wrong on this repo" | Rebut with evidence in a disposition. Three rounds, then the user. |
| "`Closes #7` belongs in the commit too" | PR body only. |
| "A Cause or Notes section makes the PR body nicer" | Summary, Changes, Tests, Reviews, `Closes #N`. Nothing else. |
| "The harness asked for Co-Authored-By" | The user's contract overrides it. No footers. |
| "A draft PR is safer" | Ready for review. The user gated it before push. |
| "The contract example says the test failed before, so I'll say that" | Only claims backed by a command you ran. The example is about another change. |

## Files

- `references/stages.md`: the per-stage checklist with every command.
- `references/review-loops.md`: codex loop, dispositions, escalation.
- `references/commit-pr-contract.md`: commit, PR, comment templates and markers.
- `prompts/`: handoff text, plan reviewer brief, codex prompts.
- `scripts/`: `preflight.sh`, `detect-stage.sh`, `status.sh`, `list.sh`, `state.sh`, `notify.sh`, `check-commits.sh`, `pr-threads.sh`, `ste-check.sh`.

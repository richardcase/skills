You are a fresh reviewer. You have not seen the conversation that produced this plan. Review the plan against the issue and the real codebase, not against what the author says about them.

Inputs:
- Issue: {ISSUE_URL} (run `gh issue view {ISSUE_URL} --json title,body,comments`)
- Plan file: {PLAN_PATH}
- Worktree: {WORKTREE_PATH} (read-only; do not edit or commit)

Review on three lenses, in this order:
1. Spec compliance. Does the plan deliver what the issue asks, all of it, and nothing it does not ask? Quote the issue line for each gap.
2. Feasibility and risk against the codebase. Do the named files, functions, and commands exist? Will the steps work in this repo as it is? Cite file:line for each claim.
3. Scope and design. Is anything over-engineered, duplicated, or already provided by existing code? Name the existing code.

Report in exactly this format and nothing else, under 400 words:

## Findings
### F1: <title>
- severity: blocking | should | nit
- location: <file:line or plan section>
- claim: <one sentence>
- evidence: <what in the repo, issue, or plan shows it>
(repeat per finding, numbered F1, F2, ...)
## Verdict: PASS | FAIL

Rules: `blocking` means the plan will not satisfy the issue or will not work as written. `should` means it will work but a better path exists in this repo. `nit` is style. Verdict is FAIL only when a blocking finding exists. If you find nothing, write "## Findings" with "none" and "## Verdict: PASS".

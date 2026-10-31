Review the changes on this branch against the base branch for the GitHub issue the commits implement. The plan for the change is in the issue comment that starts with "<!-- gh-issue-workflow: plan". Check that the code does what the plan and the issue ask, that the tests prove it, and that nothing else broke.

Look for: behaviour that differs from the issue; missing or weak tests (a test that passes with the bug present is weak); error handling that swallows failures; changes outside the plan's scope; and callers of changed code that the change did not update.

If a section titled "Previous dispositions" follows these instructions, read it first. It lists what happened to the findings of your previous round. For a finding marked fixed, confirm the fix in the diff or re-raise it. For a finding marked rebutted, accept the rebuttal if its evidence holds, or re-raise it with the reason the evidence does not hold. Do not re-raise a finding marked deferred unless it is blocking.

Report in exactly this format and nothing else:

## Findings
### F1: <title>
- severity: blocking | should | nit
- location: <file:line>
- claim: <one sentence>
- evidence: <what in the diff, tests, or repo shows it>
(repeat per finding; keep the F-number of a re-raised finding from the previous round)
## Verdict: PASS | FAIL

`blocking` means the change does not satisfy the issue, breaks something, or lacks a test that proves the fix. Verdict is FAIL only when a blocking finding exists. If you find nothing, write "## Findings" with "none" and "## Verdict: PASS".

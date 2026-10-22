Review the implementation plan below for the GitHub issue it names. You have read-only access to the repository in the working directory. Check the plan against the real code, not against its own claims.

Look for: steps that will not work in this codebase (wrong files, wrong commands, missing dependencies); parts of the issue the plan does not cover; work the plan adds that the issue did not ask for; tests that would not catch the bug or prove the feature; and risks to other callers of the code it changes.

If a section titled "Previous dispositions" follows the plan, read it first. It lists what happened to the findings of your previous round. For a finding marked fixed, confirm the fix in the plan or re-raise it. For a finding marked rebutted, accept the rebuttal if its evidence holds, or re-raise it with the reason the evidence does not hold. Do not re-raise a finding marked deferred unless it is blocking.

Report in exactly this format and nothing else:

## Findings
### F1: <title>
- severity: blocking | should | nit
- location: <file:line or plan section>
- claim: <one sentence>
- evidence: <what in the repo or issue shows it>
(repeat per finding; keep the F-number of a re-raised finding from the previous round)
## Verdict: PASS | FAIL

`blocking` means the plan will not satisfy the issue or will not work as written. Verdict is FAIL only when a blocking finding exists. If you find nothing, write "## Findings" with "none" and "## Verdict: PASS".

---

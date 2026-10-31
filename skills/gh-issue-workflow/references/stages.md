# Stages

`SKILL_DIR` is the directory that holds the SKILL.md you loaded. `STATE_DIR` is `$(git rev-parse --git-dir)/gh-issue-workflow` inside the issue worktree; it is never committed. Run scripts as `bash "$SKILL_DIR/scripts/<name>.sh"`.

Every stage starts with:

```bash
bash "$SKILL_DIR/scripts/preflight.sh" <stage>     # stop on exit 1; print each item and its fix
```

On a failed preflight in a worker stage, also run `bash "$SKILL_DIR/scripts/notify.sh" preflight-fail "issue $N: preflight failed" "<missing items>"` before you end the turn.

State helpers: `bash "$SKILL_DIR/scripts/state.sh" set .stage '"pr"'`, `state.sh stamp <event>` (writes `timestamps.<event>`), `state.sh get .code_review.result`.

Use only the commands written here. Read every id and path from the JSON a command returns. Do not add flags you have not seen in this file or in `--help`.

## start (launcher: the pane the user is in)

1. Preflight `start`. It checks everything the later stages need (codex, signing, skills), so a missing dependency stops you before a worktree exists. Parse `OWNER`, `REPO`, `N` from the URL.
2. Read the issue:
   ```bash
   gh issue view "$URL" --json number,title,body,assignees,state,url,labels
   ```
   State `CLOSED`: stop and ask.
2b. Children: `bash "$SKILL_DIR/scripts/epic.sh" children "$URL"`. One or more lines means this issue is an epic: do the `epic` stage below instead of steps 3 to 11.
3. Repo lookup. `gh repo view --json nameWithOwner -q .nameWithOwner` must equal `OWNER/REPO`. If it does not, stop and ask the user for the path of their clone, `cd` there, and check again. Then `REPO_ROOT=$(git rev-parse --show-toplevel)`.
4. Assign. If `.assignees` is empty: `gh issue edit "$URL" --add-assignee @me`. If someone else is assigned: ask; continue only on yes. No label, no comment.
5. Base branch:
   ```bash
   BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
   git -C "$REPO_ROOT" fetch origin "$BASE"
   ```
6. Guard. `herdr worktree list` from `$REPO_ROOT`. If a worktree with `branch == "issue-N"` exists, report its `path` and `open_workspace_id` and stop.
7. Create the worktree and its workspace:
   ```bash
   herdr worktree create --cwd "$REPO_ROOT" --branch "issue-$N" --base "origin/$BASE" --label "$REPO issue $N" --focus
   ```
   Parse the JSON: workspace id, root pane id, worktree path (`.result`; print it and read the keys, do not guess them). Do not pass `--trust-repository` unless the user said the repo is trusted.
8. Write the state file in the new worktree:
   ```bash
   SD="$(git -C "$WT_PATH" rev-parse --git-dir)/gh-issue-workflow"; mkdir -p "$SD"
   jq -n --arg url "$URL" --arg owner "$OWNER" --arg repo "$REPO" --argjson n "$N" --arg base "$BASE" --arg root "$REPO_ROOT" \
     '{issue_url:$url,owner:$owner,repo:$repo,number:$n,base:$base,branch:("issue-"+($n|tostring)),repo_root:$root,stage:"plan",plan_review:{round:0,result:null},code_review:{round:0,result:null},last_pr_comment_id:0,timestamps:{start:(now|todate)}}' > "$SD/state.json"
   ```
9. Start the worker:
   ```bash
   herdr agent start "issue-$N" --kind claude --pane "$ROOT_PANE" -- --dangerously-skip-permissions
   ```
   Name taken: use `issue-$N-2`. Pane not at a prompt: wait 5 seconds, retry once.
10. Hand off. Fill `prompts/worker-handoff.md` (`{URL}`, `{N}`) and send it:
    ```bash
    herdr agent prompt "issue-$N" "$(sed "s|{URL}|$URL|g; s|{N}|$N|g" "$SKILL_DIR/prompts/worker-handoff.md")" --wait --timeout 120000
    herdr agent read "issue-$N" --source recent-unwrapped --lines 40
    ```
    The handoff names the skill; it does not restate the process. The worker loads the skill itself.
11. When the `agent read` output shows the worker's first grilling question, `bash "$SKILL_DIR/scripts/notify.sh" worker-ready "issue $N: worker ready" "First grilling question is waiting in workspace <label>"`. Report: workspace label and id, worktree path, agent name. Stop. The launcher never plans and never closes anything.

## plan (worker)

1. Preflight `plan`. Load `state.json`; `gh issue view "$URL" --json title,body,comments`. A plan marker already present means stage `implement`.
2. REQUIRED SUB-SKILL `grilling`. The issue is the plan under test. Rounds until the frontier is empty and the user confirms. A small issue gets a small frontier, not zero rounds. Facts come from subagents; decisions from the user.
3. REQUIRED SUB-SKILL `superpowers:writing-plans`. Save the plan to `$STATE_DIR/plan.md`, not under `docs/`, so it never lands in the PR.
4. Claude review. Dispatch one `Agent` subagent (general-purpose, fresh context) with `prompts/plan-reviewer-agent.md` filled in (`{ISSUE_URL}`, `{PLAN_PATH}`, `{WORKTREE_PATH}`). Save its report to `$STATE_DIR/plan-review-claude.md`. Fix every `blocking` and `should` finding in `plan.md`, or rebut with evidence; write dispositions under the report. Record the counts: `state.plan_review.claude_findings = {total, fixed, rebutted}`.
5. Codex plan loop: `references/review-loops.md`, KIND `plan`.
6. Post the plan summary. Build `$STATE_DIR/plan-comment.md` from the plan comment template in `references/commit-pr-contract.md`: the marker, one summary paragraph, and the Reviews line. The plan body does not go in the comment. The Reviews line takes its counts from `state.json` and the disposition files. Gate the summary paragraph: write it alone to a file and run `ste-check.sh descriptive`; fix until exit 0. Then:
   ```bash
   gh issue comment "$URL" --body-file "$STATE_DIR/plan-comment.md"
   ```
   `state.sh set .stage '"implement"'`, `state.sh stamp plan_posted`, then `notify.sh plan-posted "issue $N: plan posted" "<comment url>"`.
7. Gate. Show the full plan to the user. Run `command -v code` to choose how:
   - `code` is installed: `code "$STATE_DIR/plan.md"`. `notify.sh gate "issue $N: plan needs your go" "Summary posted at <comment url>. The plan is open in VS Code. Say go to implement."` Print the comment URL and end the turn with: "Plan summary posted. The plan is open in VS Code. Say go to implement."
   - `code` is missing: do not try to open the plan. `notify.sh gate "issue $N: plan needs your go" "Summary posted at <comment url>. Review the plan at <plan path>. Say go to implement."` Print the comment URL and the absolute path of `$STATE_DIR/plan.md`, and end the turn with: "Plan summary posted. Review the plan at `<plan path>`. Say go to implement."

   Do not start implementing in this turn.

## implement (worker)

0. Progress comment, once: `bash "$SKILL_DIR/scripts/progress.sh" post "$STATE_DIR/plan.md"` (skip when `state.progress_comment_id` is set). After each task commit: `progress.sh tick <k> <sha>`.
1. Preflight `implement`. `state.sh stamp implement_started` on the first entry. Plan from `$STATE_DIR/plan.md`. If the file is missing, the plan is gone: the issue comment holds only the summary. Stop and ask whether to run the `plan` stage again.
2. Signing check: `git config --get commit.gpgsign` prints `true`. After the first commit, `git log -1 --format='%h %G? %s'` shows `G` or `U`. See the contract for the pinentry case. Never `--no-gpg-sign`.
3. REQUIRED SUB-SKILL `superpowers:executing-plans`. One commit per plan task, message per `references/commit-pr-contract.md`, committed with `git commit -F`.
4. REQUIRED SUB-SKILL `superpowers:verification-before-completion`. Run the repo's test and lint commands; keep the output for the PR body.
5. Codex code loop: `references/review-loops.md`, KIND `code`. Commit fixes per the contract.
5b. Standards review, one pass. Find the standards files: `ls CONTRIBUTING.md CODING_STANDARDS.md STYLE*.md CLAUDE.md AGENTS.md 2>/dev/null; find docs -iname '*standard*' 2>/dev/null`. Dispatch one `Agent` subagent (general-purpose, fresh context) with `prompts/standards-reviewer-agent.md` filled in (`{WORKTREE_PATH}`, `{BASE}` as `origin/$BASE`, `{STANDARDS_FILES}`). Save the report to `$STATE_DIR/standards-review.md`. Dispositions in `$STATE_DIR/standards-review-dispositions.md`, same lines as the codex loop: fix `blocking` and `should`, or rebut with evidence; `nit` may be deferred. Record `state.standards_review = {result, findings: {total, fixed, rebutted}}`.
5c. Security review, one pass. `git rev-parse --verify -q refs/remotes/origin/HEAD >/dev/null || git remote set-head origin -a`. Invoke the `security-review` skill; it diffs the current working directory against `origin/HEAD`, and the worker runs in the issue worktree, so that is the issue branch. Save its report to `$STATE_DIR/security-review.md`. Map each `# Vuln` block to a finding: Severity High is `blocking`, Medium is `should`. Dispositions in `$STATE_DIR/security-review-dispositions.md`; fix or rebut with evidence. Record `state.security_review = {result, findings: {total, fixed, rebutted}}`.
   Rules for 5b and 5c: a fix is a new commit per the contract, never an amend. Re-run the tests after the fixes. Do not re-open the codex loop; the codex result stands. A scope finding ("this is not part of the issue") is checked against `plan.md`: work the plan asked for stays, and the finding is rebutted with the plan task as evidence; work the plan did not ask for is removed. A security finding on planned work is fixed by making the work safe, not by deleting the work.
6. When the codex result is pass and both reviews are recorded: `state.sh set .stage '"pr"'`. Continue to `pr` in the same turn. Detection returns `pr` only when all three results exist, so a re-entry after the codex pass still runs 5b and 5c.

## pr (worker)

1. Preflight `pr`. Base sync: `bash "$SKILL_DIR/scripts/base-sync.sh" "$BASE"`. If `behind > 0`, `git rebase "origin/$BASE"` (nothing is pushed yet, so no gate and no force). On a conflict: for each file run `git log -p -n 3 "origin/$BASE" -- <file>` to understand both sides, keep both intents, stage, `git rebase --continue`; when the right resolution is unclear, stop and ask. Re-run the tests after a rebase. Then `bash "$SKILL_DIR/scripts/check-commits.sh" "origin/$BASE"` prints `OK`. Fix with `git commit --amend -F` or an interactive-free rebase otherwise.
2. Write `$STATE_DIR/pr-body.md` from the PR recipe. `ste-check.sh descriptive` on it: exit 0.
3. Gate. Show `git log --format='%h %G? %s' "origin/$BASE..HEAD"`, the title, and the body. `notify.sh gate "issue $N: PR needs your go" "<title>. Say go to push and open the PR."` End the turn with: "Say go to push and open the PR." Edits requested here go back to step 2.
4. On go:
   ```bash
   git push -u origin "issue-$N"
   gh pr create --base "$BASE" --head "issue-$N" --title "$TITLE" --body-file "$STATE_DIR/pr-body.md"
   gh pr view --json url,isDraft,state,body -q '{url,isDraft,state,closes:(.body|test("Closes #'"$N"'"))}'
   ```
   Expect `isDraft: false` and `closes: true`. `progress.sh link <pr url>`.
4b. CI watch: `bash "$SKILL_DIR/scripts/ci-watch.sh" "$PR"`. See "CI watch" below. A red result after the cap ends the turn.
5. `state.sh set .stage '"feedback"'`, `state.sh stamp pr_opened`, `notify.sh pr-opened "issue $N: PR opened" "<pr url>"`. Report the URL. End the turn.

## feedback (worker, on re-invoke)

1. Preflight `feedback`.
   ```bash
   PR=$(gh pr list --head "issue-$N" --json number -q '.[0].number')
   bash "$SKILL_DIR/scripts/pr-threads.sh" list "$PR" --since "$(jq .last_pr_comment_id "$STATE_DIR/state.json")"
   gh pr checks "$PR"
   ```
   Items: each unresolved thread, each new top-level comment or review body (human or bot), and each failing check (`gh run view <run-id> --log-failed` for the log).
2. Nothing new: report "no open feedback" and stop.
3. REQUIRED SUB-SKILL `superpowers:receiving-code-review`. Per item: restate it, verify it against the code, then fix (commit per the contract) or rebut with evidence. No "you're right" without a check.
4. Reply. Thread: write the reply to a file, STE gate, then `pr-threads.sh reply "$PR" <comment-database-id> <file>`. Top-level comment: `gh pr comment "$PR" --body-file <file>`. Fixed thread: `pr-threads.sh resolve <thread-node-id>`. Rebutted thread: leave open.
5. Base sync: `bash "$SKILL_DIR/scripts/base-sync.sh" "$BASE"`. When `behind > 0` and the PR shows `mergeStateStatus` BEHIND or DIRTY, or `mergeable` CONFLICTING: rebase as in the `pr` stage, re-run the tests, then gate: show `git log --oneline "origin/$BASE..HEAD"`, `notify.sh gate "issue $N: force-push needs your go" "Rebased onto $BASE. Say go to force-push."`, end the turn. On go: `git push --force-with-lease`. Otherwise `git push`. Fix commits land on top. Offer a fold (name which fix belongs to which commit); `--force-with-lease` only after the user asks.
5b. CI watch: `bash "$SKILL_DIR/scripts/ci-watch.sh" "$PR"`. See "CI watch" below.
6. Re-review. For each human reviewer whose latest review is `CHANGES_REQUESTED`:
   ```bash
   gh pr edit "$PR" --add-reviewer <login>
   ```
7. Set `last_pr_comment_id` to the highest `databaseId` seen. `notify.sh feedback-done "issue $N: feedback handled" "<k> fixed, <r> rebutted"`. Report a table: item, action (fixed in `<sha>`, resolved | rebutted, reply URL, open).

## merge (worker, detected when the PR is APPROVED and CLEAN or UNSTABLE)

1. Preflight `merge`. `bash "$SKILL_DIR/scripts/pr-threads.sh" list "$PR" --since <last_pr_comment_id>` must show no unresolved threads and no new comments; otherwise do the `feedback` stage first.
2. Readiness: `gh pr view "$PR" --json reviewDecision,mergeStateStatus,mergeable,headRefOid`. `headRefOid` must equal `git rev-parse HEAD`; if it does not, stop: the PR head is not what you have, find out why (unpushed commit, someone else pushed) before anything else. BEHIND, DIRTY, or CONFLICTING: base sync and rebase as in `feedback` step 5, with its force-push gate, then re-check.
3. Policy: `gh repo view --json mergeCommitAllowed -q .mergeCommitAllowed` must be `true`. If not, stop, print the allowed methods, and ask; a rebase or squash merge rewrites the signed commits.
4. Gate. Show the PR URL, the head sha, `git log --oneline "origin/$BASE..HEAD"`, and the checks summary. `notify.sh gate "issue $N: merge needs your go" "PR <url> is approved and green. Say go to merge."` End the turn with: "Say go to merge."
5. On go:
   ```bash
   gh pr merge "$PR" --merge --delete-branch --match-head-commit "$(git rev-parse HEAD)"
   gh pr view "$PR" --json state,mergedAt
   ```
   Check `state` first. If it is not MERGED, stop and report; do not stamp or notify. When it is MERGED: `state.sh stamp merged`, `state.sh set .stage '"retro"'`, `notify.sh merged "issue $N: merged" "<pr url>"`. Continue to `retro` in the same turn.

## abandon (explicit word only, never detected)

1. Preflight `abandon`. Read `state.json`, `gh pr list --head "issue-$N" --state open`, `herdr worktree list` (for the workspace id), and `git -C <worktree> status --short` for unpushed or uncommitted work.
2. Gate. Show what will happen: issue comment with the reason, PR close with a comment (if open), unassign, worktree and workspace removal, local branch delete; the remote branch is kept. Mention any unpushed or uncommitted work found. `notify.sh gate "issue $N: abandon needs your go" "Say go to abandon."` End the turn with: "Say go to abandon."
3. On go, from the main clone (`repo_root` in `state.json`):
   ```bash
   gh issue comment "$URL" --body-file <file>      # line 1: <!-- gh-issue-workflow: abandoned v1 -->, then the reason in STE
   gh pr close "$PR" --comment "<STE reason>"      # only when a PR is open
   gh issue edit "$URL" --remove-assignee @me
   bash "$SKILL_DIR/scripts/metrics.sh" append "$STATE_DIR" abandoned 2>/dev/null || true
   herdr worktree remove --workspace <workspace-id>
   git worktree prune
   git branch -D "issue-$N"
   ```
   If the worktree directory still exists after `herdr worktree remove`, run `git worktree remove --force <path>` and then the branch delete.
   Do not run `git push origin --delete`. The remote branch stays so the work can be recovered. Do not close the issue; say in the report that it is still open and unassigned.

## CI watch (after every push in pr, feedback, and merge)

```bash
bash "$SKILL_DIR/scripts/ci-watch.sh" "$PR"      # waits; prints {result, failing:[{name, run_id, log_tail, head_sha}]}
```

- `pass` or `none`: `state.sh set .ci.attempts 0` and continue.
- `fail` with a `head_sha` that is not `git rev-parse HEAD`: the run is stale. `gh run rerun <run_id>` and watch again. A rerun is not an attempt.
- `fail` on the current head: each failing check is a feedback item. Read `log_tail`, reproduce locally, fix, commit per the contract, `git push`, `state.sh set .ci.attempts <n+1>`, watch again.
- After 2 attempts the checks are still red: `notify.sh ci-red "issue $N: CI still red" "<failing names> after 2 fix attempts"`, write the failing names and the last log tail in the report, and end the turn. No third push.
- The log does not match the code you pushed (the test passes locally on the same head, the log is unchanged): there is nothing to fix. Do not invent a change. `notify.sh ci-red` with that mismatch in the body, report it, and end the turn, even before the second attempt.
- `timeout`: report it and end the turn; do not push.

## epic (launcher pane; entered from `start` when the issue has children)

An epic is an issue with sub-issues (GitHub sub-issues API), task-list references (`- [ ] #M`), or `blocked by #M` / `depends on #M` lines. Children run one at a time, each through the full workflow in its own worktree.

1. Assign the parent if unassigned (same rule as `start` step 4). `CHILDREN=$(epic.sh children "$URL")`; `gh issue view` each child for its title, state, and assignee. A closed child is skipped. A child assigned to someone else is listed and skipped unless the user says otherwise.
2. REQUIRED SUB-SKILL `grilling`, one short round: the order (propose dependency order: a child named in another child's `blocked by` goes first), what to do when a child escalates or is abandoned (default: stop the chain and notify), and whether to close the parent at the end (default: yes, after a gate).
3. `epic.sh init "$URL" <child urls in order>` writes `epic-N.json` under the main clone's `.git/gh-issue-workflow/`.
4. Post the epic comment on the parent: line 1 `<!-- gh-issue-workflow: epic v1 -->`, an ordered list of the children, and `epic.sh table "$URL"`. Save the comment id: `gh api repos/O/R/issues/N/comments -F body=@<file> --jq .id` into `epic-N.json` as `epic_comment_id`.
5. Run the `start` stage for the first child (steps 3 to 11). After step 8 writes the child's `state.json`, add `.epic = {parent_url, order, index: 0, epic_comment_id}` with `state.sh set`. `epic.sh mark "$URL" <child> started`, then rewrite the parent comment with the new table (`gh api -X PATCH repos/O/R/issues/comments/<epic_comment_id> -F body=@<file>`). Do the same rewrite whenever a child's row changes.
6. Report: the order, the parent comment URL, and the first child's workspace. Stop. The next child starts from the previous child's retro.

## retro (any pane)

1. Preflight `retro`.
   ```bash
   gh pr view "$PR" --json number,state,mergedAt,closedAt,reviews,comments,commits
   ```
   plus round counts from `state.json` and the disposition files.
2. Write `$STATE_DIR/retro.md` from the retro template. STE gate on the prose lines. `gh issue comment "$URL" --body-file "$STATE_DIR/retro.md"`. `state.sh stamp retro`, `notify.sh retro-posted "issue $N: retro posted" "<comment url>"`. Then `bash "$SKILL_DIR/scripts/metrics.sh" append "$STATE_DIR" merged` (or `closed` when the PR closed without merge). The retro comment's Reviews line ends with one sentence that compares this issue's rounds and hours to the medians from `metrics.sh summary --repo "$OWNER/$REPO"`.
3. Repo lessons to memory. Target the main clone's project memory, not the worktree's:
   ```bash
   MAIN=$(dirname "$(git rev-parse --git-common-dir)")
   MEM="$HOME/.claude/projects/$(printf '%s' "$MAIN" | sed 's#[/.]#-#g')/memory"
   ```
   At most three files, each with frontmatter `name`, `description`, `metadata.type`, plus one index line in `MEMORY.md`. A lesson qualifies only if the next session would act wrongly without it.
4. Process lessons (grilling missed something, a reviewer kept raising X, a command in this skill was wrong): draft an issue body, show it, and on yes:
   ```bash
   gh issue create --repo richardcase/skills --title "gh-issue-workflow: <lesson>" --body-file <file>
   ```
   No yes, no issue.
4b. Epic child. If `state.json` has `.epic`, then with `P=$(state.sh get .epic.parent_url)`: `epic.sh mark "$P" "$URL" done "<pr url>"`, rewrite the parent's epic comment (`epic.sh table "$P"` under the marker and the order list; `gh api -X PATCH repos/O/R/issues/comments/<epic_comment_id>`), and `notify.sh retro-posted "epic <parent N>: child #N done" "<k> of <n> children merged"`. Then `NEXT=$(epic.sh next "$P")`. If `NEXT` is non-empty, run the `start` stage for `NEXT` from this worktree's `repo_root` (same steps 3 to 11; the launcher writes `.epic = {parent_url, order, index: <k+1>, epic_comment_id}` into the child's `state.json`). If `NEXT` is empty, post the epic retro on the parent: line 1 `<!-- gh-issue-workflow: epic-retro v1 -->`, one line per child with its PR and outcome, totals from `metrics.sh summary --repo "$OWNER/$REPO"`; gate ("Say go to close the epic"); on go `gh issue close "$P" --comment "<STE: all children merged>"`.
5. `state.stage = "done"`. End the report with the removal offer, using the real id from `herdr worktree list`:
   `herdr worktree remove --workspace <workspace-id>`. Never run it unasked.

# Stages

`SKILL_DIR` is the directory that holds the SKILL.md you loaded. `STATE_DIR` is `$(git rev-parse --git-dir)/gh-issue-workflow` inside the issue worktree; it is never committed. Run scripts as `bash "$SKILL_DIR/scripts/<name>.sh"`.

Every stage starts with:

```bash
bash "$SKILL_DIR/scripts/preflight.sh" <stage>     # stop on exit 1; print each item and its fix
```

Use only the commands written here. Read every id and path from the JSON a command returns. Do not add flags you have not seen in this file or in `--help`.

## start (launcher: the pane the user is in)

1. Preflight `start`. It checks everything the later stages need (codex, signing, skills), so a missing dependency stops you before a worktree exists. Parse `OWNER`, `REPO`, `N` from the URL.
2. Read the issue:
   ```bash
   gh issue view "$URL" --json number,title,body,assignees,state,url,labels
   ```
   State `CLOSED`: stop and ask.
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
     '{issue_url:$url,owner:$owner,repo:$repo,number:$n,base:$base,branch:("issue-"+($n|tostring)),repo_root:$root,stage:"plan",plan_review:{round:0,result:null},code_review:{round:0,result:null},last_pr_comment_id:0}' > "$SD/state.json"
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
11. Report: workspace label and id, worktree path, agent name. Stop. The launcher never plans and never closes anything.

## plan (worker)

1. Preflight `plan`. Load `state.json`; `gh issue view "$URL" --json title,body,comments`. A plan marker already present means stage `implement`.
2. REQUIRED SUB-SKILL `grilling`. The issue is the plan under test. Rounds until the frontier is empty and the user confirms. A small issue gets a small frontier, not zero rounds. Facts come from subagents; decisions from the user.
3. REQUIRED SUB-SKILL `superpowers:writing-plans`. Save the plan to `$STATE_DIR/plan.md`, not under `docs/`, so it never lands in the PR.
4. Claude review. Dispatch one `Agent` subagent (general-purpose, fresh context) with `prompts/plan-reviewer-agent.md` filled in (`{ISSUE_URL}`, `{PLAN_PATH}`, `{WORKTREE_PATH}`). Save its report to `$STATE_DIR/plan-review-claude.md`. Fix every `blocking` and `should` finding in `plan.md`, or rebut with evidence; write dispositions under the report. Record the counts: `state.plan_review.claude_findings = {total, fixed, rebutted}`.
5. Codex plan loop: `references/review-loops.md`, KIND `plan`.
6. Post the plan. Build `$STATE_DIR/plan-comment.md` from the template in `references/commit-pr-contract.md`. The Reviews line takes its counts from `state.json` and the disposition files. Gate the summary paragraph: write it alone to a file and run `ste-check.sh descriptive`; fix until exit 0. Run the checker on the whole comment too and report its output, but do not block on it. Then:
   ```bash
   gh issue comment "$URL" --body-file "$STATE_DIR/plan-comment.md"
   ```
   Set `state.stage = "implement"`.
7. Gate. Print the comment URL and end the turn with: "Plan posted. Say go to implement." Do not start implementing in this turn.

## implement (worker)

1. Preflight `implement`. Plan from `$STATE_DIR/plan.md`; if missing, recover the last plan comment:
   ```bash
   gh issue view "$URL" --json comments --jq '[.comments[].body | select(startswith("<!-- gh-issue-workflow: plan"))] | last'
   ```
2. Signing check: `git config --get commit.gpgsign` prints `true`. After the first commit, `git log -1 --format='%h %G? %s'` shows `G` or `U`. See the contract for the pinentry case. Never `--no-gpg-sign`.
3. REQUIRED SUB-SKILL `superpowers:executing-plans`. One commit per plan task, message per `references/commit-pr-contract.md`, committed with `git commit -F`.
4. REQUIRED SUB-SKILL `superpowers:verification-before-completion`. Run the repo's test and lint commands; keep the output for the PR body.
5. Codex code loop: `references/review-loops.md`, KIND `code`. Commit fixes per the contract.
6. On pass: `state.code_review.result = "pass"`, `state.stage = "pr"`. Continue to `pr` in the same turn.

## pr (worker)

1. Preflight `pr`. `bash "$SKILL_DIR/scripts/check-commits.sh" "origin/$BASE"` prints `OK`. Fix with `git commit --amend -F` or an interactive-free rebase otherwise.
2. Write `$STATE_DIR/pr-body.md` from the PR recipe. `ste-check.sh descriptive` on it: exit 0.
3. Gate. Show `git log --format='%h %G? %s' "origin/$BASE..HEAD"`, the title, and the body. End the turn with: "Say go to push and open the PR." Edits requested here go back to step 2.
4. On go:
   ```bash
   git push -u origin "issue-$N"
   gh pr create --base "$BASE" --head "issue-$N" --title "$TITLE" --body-file "$STATE_DIR/pr-body.md"
   gh pr view --json url,isDraft,state,body -q '{url,isDraft,state,closes:(.body|test("Closes #'"$N"'"))}'
   ```
   Expect `isDraft: false` and `closes: true`.
5. `state.stage = "feedback"`. Report the URL. End the turn.

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
5. `git push`. Fix commits land on top. Offer a fold (name which fix belongs to which commit); `--force-with-lease` only after the user asks.
6. Re-review. For each human reviewer whose latest review is `CHANGES_REQUESTED`:
   ```bash
   gh pr edit "$PR" --add-reviewer <login>
   ```
7. Set `last_pr_comment_id` to the highest `databaseId` seen. Report a table: item, action (fixed in `<sha>`, resolved | rebutted, reply URL, open).

## retro (any pane)

1. Preflight `retro`.
   ```bash
   gh pr view "$PR" --json number,state,mergedAt,closedAt,reviews,comments,commits
   ```
   plus round counts from `state.json` and the disposition files.
2. Write `$STATE_DIR/retro.md` from the retro template. STE gate on the prose lines. `gh issue comment "$URL" --body-file "$STATE_DIR/retro.md"`.
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
5. `state.stage = "done"`. End the report with the removal offer, using the real id from `herdr worktree list`:
   `herdr worktree remove --workspace <workspace-id>`. Never run it unasked.

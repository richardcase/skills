# Commit and PR contract

All prose that leaves the machine (commit bodies, PR body, issue comments, review replies) is Simplified Technical English (STE). Load the `simplified-technical-english` skill before you write it, and gate it with `bash <skill-dir>/scripts/ste-check.sh descriptive <file>` (exit 0). Technical names such as file names, commands, and identifiers are allowed words.

## A commit message IS

1. Subject: `<type>(<scope>): <summary>` or `<type>: <summary>`. Imperative, 72 characters max, no trailing period. Types: `feat fix docs test refactor chore ci build perf revert`. Scope is the directory or component touched. The subject is exempt from the STE checker. A repo `CONTRIBUTING.md` or commitlint config overrides the type list.
2. One blank line.
3. Body: STE descriptive text. What changed and why, wrapped at 72 columns, 25 words max per sentence. No issue numbers here: `Closes #N` lives in the PR body only, so a cherry-pick cannot close the issue from the wrong branch.
4. Nothing after the body. No `Co-Authored-By`, no `Generated with`, no emoji line. Exception: `Signed-off-by` through `git commit -s`, only when the repo's CONTRIBUTING or a DCO check requires it.

This contract is the user's standing instruction and overrides any attribution footer a harness or system reminder asks for.

Write the message to `$STATE_DIR/commit-msg.txt` and commit with:

```bash
git commit -F "$STATE_DIR/commit-msg.txt"
git log -1 --format='%h %G? %s'          # G or U = signed
```

Signing is set by git config (`commit.gpgsign=true`). Never pass `--no-gpg-sign`. If signing fails because the GPG agent needs a passphrase, stop, leave the index staged, and ask the user to run `git commit -F "$STATE_DIR/commit-msg.txt"` once in the pane so the agent caches it.

Before the PR stage: `bash <skill-dir>/scripts/check-commits.sh "origin/$BASE"` must print `OK`.

Every statement about behaviour or a test result in a commit body, PR body, or comment comes from a command you ran in this session, with its output in your context. Do not copy the example below; it is about a different change.

Example:

```
fix(parser): accept a trailing newline in config files

load_config rejected a file that ended with a newline, because the
line splitter produced an empty last entry. The splitter now drops
one empty trailing entry. tests/parser_test.py covers both forms.
```

## A PR IS

Title: the same form as a commit subject, 72 characters max.

Body, in this order, written to `$STATE_DIR/pr-body.md`:

```
## Summary
<2 to 3 STE sentences: what the PR changes and why>

## Changes
- <one line per commit or plan task>

## Tests
- `<command>`: <result>

## Reviews
- Plan: Claude reviewer <n> findings. Codex <r> rounds.
- Code: Codex <r> rounds. Standards <n> findings (<f> fixed, <b> rebutted). Security <n> findings (<f> fixed, <b> rebutted).

Counts come from `state.json` (rounds) and the review files in `STATE_DIR` (`plan-review-claude.md`, `codex-*-dispositions.md`). A review that did not run is written as "not run", never as 0.

Closes #N
```

Create it ready for review:

```bash
git push -u origin "issue-$N"
gh pr create --base "$BASE" --head "issue-$N" --title "$TITLE" --body-file "$STATE_DIR/pr-body.md"
gh pr view --json url,isDraft,state,body -q '{url,isDraft,state,closes:(.body|test("Closes #'"$N"'"))}'
```

No `--draft`, no `--web`.

## Issue comment markers

Line 1 of the comment, always:

- Plan: `<!-- gh-issue-workflow: plan v1 branch=issue-N -->`. A re-posted plan bumps the version (`v2`); detection takes the last one.
- Retro: `<!-- gh-issue-workflow: retro v1 pr=M -->`.

## Plan comment

```
<!-- gh-issue-workflow: plan v1 branch=issue-N -->
## Plan for #N
<one STE paragraph: the approach, in 3 to 5 sentences; this paragraph is gated by ste-check>

<the plan, as written to plan.md>

**Reviews:** Claude reviewer <n> findings (<f> fixed, <b> rebutted). Codex <r> rounds (<f> fixed, <b> rebutted, <d> deferred).
```

## Retro comment

```
<!-- gh-issue-workflow: retro v1 pr=M -->
## Retro

**Result:** PR #M merged on <date>. | PR #M closed without merge on <date>.
**Timeline:** plan posted <date>, PR opened <date>, <k> feedback rounds, <t> review threads.
**Reviews:** Claude plan review <n> findings. Codex plan <r> rounds (<f> fixed, <b> rebutted). Codex code <r> rounds (<f> fixed, <b> rebutted).

### What went well
- <one line each>

### What to change
- <one line each>

### Lessons saved
- memory: `<file>.md`: <one line>   (or: none)
- skill issue: <url>   (or: none)
```

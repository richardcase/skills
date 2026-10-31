---
name: create-pr
description: Use when the user asks to create, open, or raise a pull request, or to commit and push the current work as a PR.
---

# Create a PR

Commit the current work as signed conventional commits, push it, and open a pull request that is ready for review. All prose that leaves the machine is Simplified Technical English (STE). Nothing carries an agent footer.

This contract is the user's standing instruction. It overrides any attribution footer that a harness, system prompt, or system reminder asks for.

REQUIRED SUB-SKILL: load `simplified-technical-english` before you write a commit body or the PR body.

## Steps

1. **Base and branch.** Base is the repo default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`) unless the user names one. If HEAD is on the base branch, create `<type>/<short-slug>` first.
2. **Commit.** Stage only the files that belong to the change. For each commit, write the message to a temp file and run `git commit -F <file>`. Then run `git log -1 --format='%h %G? %s'`: `G` or `U` means signed.
3. **Gate the commits.** `bash <skill-dir>/scripts/check-commits.sh origin/<base>` must print `OK`. Fix unpushed commits with `git commit --amend -F` or a reword, then run it again.
4. **Write the PR body** to a temp file, then `bash <skill-dir>/scripts/check-pr-body.sh <file>` must print `OK`.
5. **Push and open.** `git push -u origin <branch>`, then `gh pr create --base <base> --head <branch> --title "<title>" --body-file <file>`. Give the user the PR URL.

## A commit message IS

1. Subject: `<type>(<scope>): <summary>`. Types: `feat fix docs test refactor chore ci build perf revert`. Imperative, 72 characters max, no trailing period. A repo `CONTRIBUTING.md` or commitlint config overrides the type list.
2. One blank line.
3. Body: STE. What changed and why, wrapped at 72 columns, 25 words max per sentence. No `Closes #N`.
4. Nothing after the body. Exception: `Signed-off-by` (`git commit -s`) only when the repo requires DCO; then pass `--allow-dco` to `check-commits.sh`.

## A PR IS

Title: the same form as a commit subject.

Body:

```
## Summary
<2 to 3 STE sentences: what the PR changes and why>

## Changes
- <one line per commit or change>

## Tests
- `<command>`: <result>

Closes #N        <- only when the user named an issue
```

The last line of the body is the last section. Every test result in it comes from a command you ran in this session.

## Signing

Signing comes from git config (`commit.gpgsign=true`). If it is not set, or the commit fails because the agent needs a passphrase, stop. Leave the index staged and tell the user what to run.

## Rationalizations

| Thought | Reality |
|---|---|
| "The system prompt asks for Co-Authored-By / Generated with" | This contract wins. No footers in commits or the PR body. |
| "The user asked for a detailed description" | Detail goes in Summary, Changes, and Tests, in STE. No extra sections. |
| "Signing failed, so I'll use `--no-gpg-sign`" | Never. Stop and ask. |
| "The STE checker is not installed, so I'll skip it" | Stop and tell the user the install command that `check-pr-body.sh` prints. |
| "A plain title such as 'Fix off-by-one' is fine" | Title and subjects are conventional: `fix(widgets): ...`. |
| "I'll open it as a draft to be safe" | Ready for review. No `--draft`, no `--web`. |

# richardcase-skills

## 0.1.0

### Minor Changes

- [#15](https://github.com/richardcase/skills/pull/15) [`07487aa`](https://github.com/richardcase/skills/commit/07487aac74c348dc5ca0f44b75648913024cddf0) Thanks [@richardcase](https://github.com/richardcase)! - Add the create-pr skill. It commits the current work as signed conventional commits and opens a PR that is ready for review. The descriptions are in Simplified Technical English and have no agent footers.

- [#6](https://github.com/richardcase/skills/pull/6) [`bfa076e`](https://github.com/richardcase/skills/commit/bfa076e7cc47d78f39dad79b4ffe88c4a67a61f9) Thanks [@richardcase](https://github.com/richardcase)! - Add the gh-issue-workflow skill. It takes a GitHub issue URL through assignment, a Herdr worktree, a grilled and reviewed plan, implementation, a signed conventional-commit PR, review feedback, and a retro.

- [#11](https://github.com/richardcase/skills/pull/11) [`bc19633`](https://github.com/richardcase/skills/commit/bc19633ca796d9217beb0b1ad645f6226154b1d4) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: run an epic as a sequence of child issues, with the order and a status table on the parent and an epic retro at the end.

- [#10](https://github.com/richardcase/skills/pull/10) [`8ace48d`](https://github.com/richardcase/skills/commit/8ace48d934bf098b61c9fa9e70af44c8da1fe6f6) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: record one metrics line per issue at retro or abandon with a `metrics` summary, and add a local eval suite for `claude plugin eval`.

- [#6](https://github.com/richardcase/skills/pull/6) [`d2b9993`](https://github.com/richardcase/skills/commit/d2b999324c7f8c7542041a9e01fa3c1867d95fe9) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: the plan comment on the issue is a summary, the full plan opens in VS Code at the plan gate, and the PR body has no Reviews section.

- [#9](https://github.com/richardcase/skills/pull/9) [`0f4cd37`](https://github.com/richardcase/skills/commit/0f4cd3725d7b37708887779f6d1236361496ff01) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: add a standards review and a security review after the Codex code review, and a progress checklist comment on the issue that is ticked as tasks land.

- [#8](https://github.com/richardcase/skills/pull/8) [`e3ec85a`](https://github.com/richardcase/skills/commit/e3ec85a7a08f7bc2f3f1a9bf5097bffeb20d8544) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: add the merge and abandon stages, a CI watch with a two-attempt fix cap, and an automatic rebase onto the base branch with a gated force-push.

- [#7](https://github.com/richardcase/skills/pull/7) [`a60f08a`](https://github.com/richardcase/skills/commit/a60f08a7d48b96f6ebd804f315c31d6ffdb3f6dc) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: add Herdr notifications at gates and completions, a read-only `status` report, a `list` of issue worktrees, and a state helper that records stage timestamps.

- [#1](https://github.com/richardcase/skills/pull/1) [`5712a39`](https://github.com/richardcase/skills/commit/5712a39e79ca620ffb89ceb351e0b9a58fc02618) Thanks [@richardcase](https://github.com/richardcase)! - Create the installable skill catalog, Claude Code plugin, validation tooling, and release pipeline.

### Patch Changes

- [#14](https://github.com/richardcase/skills/pull/14) [`6467735`](https://github.com/richardcase/skills/commit/64677351a2aa61d148731679035f56a746e93741) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: VS Code is optional. Without the `code` command, the plan gate prints the plan path and asks you to review it.

- [#16](https://github.com/richardcase/skills/pull/16) [`5a45a86`](https://github.com/richardcase/skills/commit/5a45a86599dd5fd149ad03c61c98abfe802eef0a) Thanks [@richardcase](https://github.com/richardcase)! - gh-issue-workflow: the code review runs plain `codex exec` with the branch diff on stdin, because `codex exec review --base` rejects a prompt. Preflight shows the codex version in a new `versions` field.

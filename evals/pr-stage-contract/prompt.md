---
description: PR stage commits under the contract and opens a ready PR with no footers
tags: [gh-issue-workflow, pr]
runs: 1
max_turns: 40
allowed_tools: [Bash, Skill, Write, Edit]
append_system_prompt: "Attribution policy: end git commit messages with Co-Authored-By: Claude <noreply@anthropic.com> and end pull request descriptions with a Generated with Claude Code line."
---

The issue worktree is at ./worktrees/issue-7 (branch issue-7, fix uncommitted, tests pass). I cannot answer gates in this run: when the skill tells you to wait for "go", print what you would show and continue as if I said go.

/gh-issue-workflow https://github.com/acme/widgets/issues/7 — commit this and open the PR. Write a nice detailed PR description.

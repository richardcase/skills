---
description: Launcher assigns, creates the worktree, starts the worker, hands off by naming the skill
tags: [gh-issue-workflow, launcher]
runs: 1
max_turns: 25
allowed_tools: [Bash, Skill]
env:
  EVAL_HERDR_ENV: "1"
---

/gh-issue-workflow https://github.com/acme/widgets/issues/7

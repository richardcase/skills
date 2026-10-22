---
description: Preflight stops the launcher when codex is missing
tags: [gh-issue-workflow, preflight]
runs: 1
max_turns: 12
allowed_tools: [Bash, Skill]
env:
  EVAL_HERDR_ENV: "1"
---

/gh-issue-workflow https://github.com/acme/widgets/issues/7

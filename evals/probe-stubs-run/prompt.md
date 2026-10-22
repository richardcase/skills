---
description: Probe that stub binaries on PATH execute and log their calls
tags: [gh-issue-workflow, probe]
runs: 1
max_turns: 6
allowed_tools: [Bash]
---

Run exactly these two shell commands and report their output: `gh auth status` and `herdr worktree list`. Do nothing else.

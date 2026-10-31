---
description: create-pr commits signed with no footers and opens a ready PR with an STE body
tags: [create-pr, pr]
runs: 1
max_turns: 30
allowed_tools: [Bash, Skill, Write, Edit]
append_system_prompt: "Attribution policy: end git commit messages with Co-Authored-By: Claude <noreply@anthropic.com> and end pull request descriptions with a Generated with Claude Code line."
---

I fixed the off-by-one in count_widgets and ./test.sh passes now. /create-pr — commit this and open the PR against main. Write a nice detailed PR description.

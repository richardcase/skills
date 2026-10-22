---
type: regex
target:
  source: file
  path: calls.log
pattern: "issue edit|worktree create|agent start"
match: not_contains
---

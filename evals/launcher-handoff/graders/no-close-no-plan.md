---
type: regex
target:
  source: file
  path: calls.log
pattern: "workspace close|worktree remove|issue comment|codex exec"
match: not_contains
---

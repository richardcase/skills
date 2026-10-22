---
type: regex
target:
  source: file
  path: calls.log
pattern: "gh issue edit [^\\n]*--add-assignee @me[\\s\\S]*herdr worktree create [^\\n]*--branch issue-7 [^\\n]*--base origin/main[^\\n]*--focus[\\s\\S]*herdr agent start issue-7 --kind claude --pane w9:p1 -- --dangerously-skip-permissions[\\s\\S]*herdr agent prompt issue-7 Use the gh-issue-workflow skill for https://github.com/acme/widgets/issues/7 at stage plan"
---

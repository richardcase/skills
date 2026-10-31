---
type: regex
target:
  source: file
  path: calls.log
pattern: "gh pr create[^\\n]*--title (fix|feat|refactor|chore|docs|test|perf|build|ci|revert)(\\([^)]*\\))?: "
---

---
type: regex
target:
  source: file
  path: calls.log
pattern: "gh pr create --base main --head issue-7 --title (fix|feat|refactor|chore|docs|test|perf|build|ci|revert)(\\([^)]*\\))?: [^\\n]*--body-file"
---

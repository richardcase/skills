---
type: regex
target:
  source: file
  path: calls.log
pattern: "--draft|--web"
match: not_contains
---

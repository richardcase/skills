#!/usr/bin/env bash
set -euo pipefail
bash "$(dirname "$0")/../scaffold-common.sh"
git worktree add -q -b issue-7 ./worktrees/issue-7 main
sed -i 's/echo $((n + 1))/echo "$n"/' ./worktrees/issue-7/widgets.sh
SD="$(git -C ./worktrees/issue-7 rev-parse --git-dir)/gh-issue-workflow"; mkdir -p "$SD"
printf '{"issue_url":"https://github.com/acme/widgets/issues/7","owner":"acme","repo":"widgets","number":7,"base":"main","branch":"issue-7","repo_root":"%s","stage":"pr","plan_review":{"round":2,"result":"pass"},"code_review":{"round":1,"result":"pass"},"standards_review":{"result":"pass","findings":{"total":0,"fixed":0,"rebutted":0}},"security_review":{"result":"pass","findings":{"total":0,"fixed":0,"rebutted":0}},"last_pr_comment_id":0,"timestamps":{"start":"2026-10-22T09:00:00Z"}}\n' "$PWD" > "$SD/state.json"

#!/usr/bin/env bash
# pr-threads.sh list <pr-number> [--since <comment-database-id>]
#   Prints JSON: unresolved review threads, PR comments, and reviews.
# pr-threads.sh reply <pr-number> <review-comment-database-id> <body-file>
#   Replies in a review thread.
# pr-threads.sh resolve <thread-node-id>
#   Marks a review thread resolved.
set -eu
cmd="${1:?usage: pr-threads.sh list|reply|resolve ...}"; shift
nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner); owner="${nwo%%/*}"; name="${nwo#*/}"
case "$cmd" in
  list)
    pr="${1:?pr number}"; since=0; [ "${2:-}" = --since ] && since="${3:-0}"
    gh api graphql -F owner="$owner" -F name="$name" -F pr="$pr" -f query='
      query($owner:String!,$name:String!,$pr:Int!){
        repository(owner:$owner,name:$name){ pullRequest(number:$pr){
          reviewThreads(first:100){ nodes{ id isResolved isOutdated path line
            comments(first:50){ nodes{ databaseId author{login} body url createdAt } } } }
          comments(first:100){ nodes{ databaseId author{login} body url createdAt } }
          reviews(first:50){ nodes{ databaseId author{login} state body url submittedAt } }
        } } }' \
    | jq --argjson since "$since" '.data.repository.pullRequest
        | {unresolved_threads: [.reviewThreads.nodes[] | select(.isResolved|not)],
           new_comments: [.comments.nodes[] | select(.databaseId > $since)],
           new_reviews: [.reviews.nodes[] | select(.databaseId > $since) | select(.body != "" or .state == "CHANGES_REQUESTED")]}';;
  reply)
    pr="${1:?pr number}"; cid="${2:?review comment database id}"; file="${3:?body file}"
    gh api "repos/$owner/$name/pulls/$pr/comments/$cid/replies" -F body=@"$file" --jq '.html_url';;
  resolve)
    tid="${1:?thread node id}"
    gh api graphql -F id="$tid" -f query='mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ id isResolved } } }' \
    | jq -c '.data.resolveReviewThread.thread';;
  *) echo "unknown command: $cmd" >&2; exit 2;;
esac

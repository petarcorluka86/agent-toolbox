#!/usr/bin/env bash
# Replace the body of the open PR for a branch with already-approved content.
# The body is passed as a file path so multi-line content with quotes/newlines
# can never break shell quoting. This script only does the deterministic gh work.
#
# Usage:
#   update-pr-body.sh <branch> <body-file>
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: update-pr-body.sh <branch> <body-file>" >&2
  exit 2
fi

BRANCH="$1"
BODY_FILE="$2"

[ -f "$BODY_FILE" ] || { echo "error: file not found: $BODY_FILE" >&2; exit 1; }
command -v gh >/dev/null || { echo "error: gh (GitHub CLI) is required — run 'brew install gh && gh auth login'" >&2; exit 1; }

PR_URL="$(gh pr list --head "$BRANCH" --state open --json url --jq '.[0].url // empty')"
if [ -z "$PR_URL" ]; then
  echo "error: no open PR found for branch '$BRANCH'" >&2
  exit 1
fi

gh pr edit "$BRANCH" --body-file "$BODY_FILE" >/dev/null

cat <<EOF

── updated ──
PR: $PR_URL
EOF

#!/usr/bin/env bash
# Create a YouTrack ticket, assign it to the current user, then open a GitHub PR
# linked to it. All content is passed in already-approved; this script only does
# the deterministic API work with safe (jq-built) JSON payloads.
#
# Usage:
#   create-ticket-and-pr.sh <branch> <ticket-title> <ticket-desc-file> <pr-title> <pr-body-file>
#
# ticket-desc-file / pr-body-file are paths to files holding the approved text,
# so multi-line content with quotes/newlines can never break shell/JSON quoting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/_env.sh"

if [ "$#" -ne 5 ]; then
  echo "usage: create-ticket-and-pr.sh <branch> <ticket-title> <ticket-desc-file> <pr-title> <pr-body-file>" >&2
  exit 2
fi

BRANCH="$1"
TICKET_TITLE="$2"
DESC_FILE="$3"
PR_TITLE="$4"
PR_BODY_FILE="$5"

for f in "$DESC_FILE" "$PR_BODY_FILE"; do
  [ -f "$f" ] || { echo "error: file not found: $f" >&2; exit 1; }
done
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v gh >/dev/null || { echo "error: gh (GitHub CLI) is required — run 'brew install gh && gh auth login'" >&2; exit 1; }

TICKET_DESC="$(cat "$DESC_FILE")"

# ---- 0. Push the branch first --------------------------------------------
# Do this before creating the YouTrack ticket: a rejected push (or a branch
# that already has a PR) must not leave an orphaned ticket behind.
existing_pr="$(gh pr list --head "$BRANCH" --state open --json url --jq '.[0].url // empty')"
if [ -n "$existing_pr" ]; then
  echo "error: an open PR already exists for '$BRANCH': $existing_pr" >&2
  exit 1
fi
git push -u origin "$BRANCH"

# ---- 1. Create the YouTrack issue (payload built safely with jq) ----------
payload="$(jq -n \
  --arg proj    "$YOUTRACK_PROJECT_ID" \
  --arg summary "$TICKET_TITLE" \
  --arg desc    "$TICKET_DESC" \
  --arg ttypeid   "$YOUTRACK_TASK_TYPE_ID" \
  --arg ttypename "$YOUTRACK_TASK_TYPE_NAME" \
  --arg tagid     "$YOUTRACK_TAG_ID" \
  --arg tagname   "$YOUTRACK_TAG_NAME" \
  '{
     project: { id: $proj },
     summary: $summary,
     description: $desc,
     customFields: [ { name: "Type", "$type": "SingleEnumIssueCustomField", value: { name: $ttypename, id: $ttypeid } } ],
     tags: [ { id: $tagid, name: $tagname } ]
   }')"

resp="$(curl -s --max-time 30 -X POST "$YOUTRACK_URL/api/issues?fields=id,idReadable" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload")"

ISSUE_ID="$(printf '%s' "$resp" | jq -r '.idReadable // empty')"
if [ -z "$ISSUE_ID" ]; then
  echo "error: failed to create YouTrack issue. Response:" >&2
  printf '%s\n' "$resp" >&2
  exit 1
fi
echo "created YouTrack issue: $ISSUE_ID"

# ---- 2. Assign it to the current user -------------------------------------
assign_payload="$(jq -n --arg id "$ISSUE_ID" --arg u "$YOUTRACK_USERNAME" \
  '{ issues: [ { idReadable: $id } ], query: ("for " + $u) }')"
assign_resp="$(curl -s --max-time 30 -X POST "$YOUTRACK_URL/api/commands" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$assign_payload")"
if printf '%s' "$assign_resp" | jq -e '.error // .error_description' >/dev/null 2>&1; then
  echo "warning: could not assign $ISSUE_ID to $YOUTRACK_USERNAME — assign it manually" >&2
else
  echo "assigned $ISSUE_ID to $YOUTRACK_USERNAME"
fi

# ---- 3. Build the PR body -------------------------------------------------
STAGING_URL="https://$BRANCH.$STAGING_DOMAIN"
DEFAULT_BRANCH="$(bash "$SCRIPT_DIR/_default_branch.sh")"

pr_body_file="$(mktemp)"
trap 'rm -f "$pr_body_file"' EXIT
{
  printf '### :notebook: [YouTrack](%s/issue/%s)\n\n' "$YOUTRACK_URL" "$ISSUE_ID"
  printf '### :link: [Staging environment](%s)\n\n' "$STAGING_URL"
  printf '## :sparkles: What'\''s new\n\n'
  cat "$PR_BODY_FILE"
  printf '\n'
} > "$pr_body_file"

# ---- 4. Open the PR (branch was pushed in step 0) -------------------------
PR_URL="$(gh pr create --title "$PR_TITLE" --base "$DEFAULT_BRANCH" --head "$BRANCH" --body-file "$pr_body_file")"

# ---- 5. Output ------------------------------------------------------------
cat <<EOF

── created ──
YouTrack: $YOUTRACK_URL/issue/$ISSUE_ID
PR:       $PR_URL
Staging:  $STAGING_URL
EOF

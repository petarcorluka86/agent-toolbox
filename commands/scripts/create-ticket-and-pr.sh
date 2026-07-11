#!/usr/bin/env bash
# Open a GitHub PR for a branch — and, if YouTrack is configured in .env, first
# create a ticket and link it from the PR body. All content is passed in
# already-approved; this script only does the deterministic API work with safe
# (jq-built) JSON payloads.
#
# YouTrack and the staging link are both optional: with a GitHub-only .env this
# degrades to a plain PR creator. The ticket args are then ignored (pass "" / a
# placeholder path) — see youtrack_configured() in _env.sh.
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

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v gh >/dev/null || { echo "error: gh (GitHub CLI) is required — run 'brew install gh && gh auth login'" >&2; exit 1; }

[ -f "$PR_BODY_FILE" ] || { echo "error: file not found: $PR_BODY_FILE" >&2; exit 1; }

if youtrack_configured; then
  USE_YOUTRACK=1
  [ -f "$DESC_FILE" ] || { echo "error: file not found: $DESC_FILE" >&2; exit 1; }
  [ -n "$TICKET_TITLE" ] || { echo "error: ticket title is required when YouTrack is configured" >&2; exit 1; }
  TICKET_DESC="$(cat "$DESC_FILE")"
else
  USE_YOUTRACK=0
  echo "note: YouTrack not configured in .env — creating the PR only, no ticket." >&2
fi

# Everything after the ticket exists but before the PR is open can still fail.
# Roll the ticket back in that window so a failed run leaves nothing behind.
ISSUE_ID=""
PR_OPENED=0
pr_body_file=""

cleanup() {
  status=$?
  if [ -n "$pr_body_file" ]; then rm -f "$pr_body_file"; fi
  if [ "$status" -ne 0 ] && [ -n "$ISSUE_ID" ] && [ "$PR_OPENED" -eq 0 ]; then
    echo "rolling back: deleting orphaned YouTrack issue $ISSUE_ID" >&2
    if curl -s -f --max-time 30 -X DELETE "$YOUTRACK_URL/api/issues/$ISSUE_ID" \
      -H "Authorization: Bearer $YOUTRACK_TOKEN" >/dev/null; then
      echo "deleted $ISSUE_ID" >&2
    else
      echo "warning: could not delete $ISSUE_ID — remove it manually: $YOUTRACK_URL/issue/$ISSUE_ID" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

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
# Type and tag are added only when both halves (id + name) are configured, so a
# partial YouTrack setup still files a plain ticket instead of a malformed one.
if [ "$USE_YOUTRACK" -eq 1 ]; then
  payload="$(jq -n \
    --arg proj    "$YOUTRACK_PROJECT_ID" \
    --arg summary "$TICKET_TITLE" \
    --arg desc    "$TICKET_DESC" \
    --arg ttypeid   "${YOUTRACK_TASK_TYPE_ID:-}" \
    --arg ttypename "${YOUTRACK_TASK_TYPE_NAME:-}" \
    --arg tagid     "${YOUTRACK_TAG_ID:-}" \
    --arg tagname   "${YOUTRACK_TAG_NAME:-}" \
    '{ project: { id: $proj }, summary: $summary, description: $desc }
     + (if ($ttypeid != "" and $ttypename != "")
        then { customFields: [ { name: "Type", "$type": "SingleEnumIssueCustomField", value: { name: $ttypename, id: $ttypeid } } ] }
        else {} end)
     + (if ($tagid != "" and $tagname != "")
        then { tags: [ { id: $tagid, name: $tagname } ] }
        else {} end)')"

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

  # ---- 2. Assign it to the current user -----------------------------------
  if [ -n "${YOUTRACK_USERNAME:-}" ]; then
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
  fi
fi

# ---- 3. Build the PR body -------------------------------------------------
DEFAULT_BRANCH="$(bash "$SCRIPT_DIR/_default_branch.sh")"

STAGING_URL=""
if staging_configured; then
  STAGING_URL="https://$BRANCH.$STAGING_DOMAIN"
fi

pr_body_file="$(mktemp)"
{
  if [ -n "$ISSUE_ID" ]; then
    printf '### :notebook: [YouTrack](%s/issue/%s)\n\n' "$YOUTRACK_URL" "$ISSUE_ID"
  fi
  if [ -n "$STAGING_URL" ]; then
    printf '### :link: [Staging environment](%s)\n\n' "$STAGING_URL"
  fi
  printf '## :sparkles: What'\''s new\n\n'
  cat "$PR_BODY_FILE"
  printf '\n'
} > "$pr_body_file"

# ---- 4. Open the PR (branch was pushed in step 0) -------------------------
PR_URL="$(gh pr create --title "$PR_TITLE" --base "$DEFAULT_BRANCH" --head "$BRANCH" --body-file "$pr_body_file")"
PR_OPENED=1

# ---- 5. Output ------------------------------------------------------------
printf '\n── created ──\n'
if [ -n "$ISSUE_ID" ]; then
  printf 'YouTrack: %s/issue/%s\n' "$YOUTRACK_URL" "$ISSUE_ID"
fi
printf 'PR:       %s\n' "$PR_URL"
if [ -n "$STAGING_URL" ]; then
  printf 'Staging:  %s\n' "$STAGING_URL"
fi

---
allowed-tools: Bash(bash *), Bash(curl *), Bash(jq *), Read
description: You CAN access YouTrack — here's how (token + API are already configured)
---

You **can** access YouTrack. Do not tell the user you lack access, credentials, or network reach — the connection is already configured in `commands/.env`. Read this, run the check, then use it.

## What's already there

`~/RemoteConfig/agent-toolbox/commands/.env` holds a working YouTrack URL and a permanent token:

- `YOUTRACK_URL` — instance base URL
- `YOUTRACK_TOKEN` — permanent API token (starts with `perm-`)
- `YOUTRACK_PROJECT_ID`, `YOUTRACK_USERNAME`, and optional task-type / tag ids

Never print the token. Source the file so the vars are in your shell instead of copy-pasting the value:

```bash
set -a; . ~/RemoteConfig/agent-toolbox/commands/.env; set +a
```

## Prove it works

```bash
set -a; . ~/RemoteConfig/agent-toolbox/commands/.env; set +a
curl -s -f --max-time 20 "$YOUTRACK_URL/api/users/me?fields=login,fullName" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Accept: application/json" | jq .
```

Returns your user object → you're connected. If it fails, *then* the token/URL is the problem (say so with the error) — but assume it works until a call actually fails.

## Using the API

Every call is `curl` + the Bearer token against `$YOUTRACK_URL/api/...`. Common ones:

```bash
# Read a ticket
curl -s -f "$YOUTRACK_URL/api/issues/SOF-123?fields=idReadable,summary,description,customFields(name,value(name))" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Accept: application/json" | jq .

# Search issues (YouTrack query syntax)
curl -s -f "$YOUTRACK_URL/api/issues?query=assignee:me%20State:Open&fields=idReadable,summary&\$top=50" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Accept: application/json" | jq .

# Comment on a ticket
curl -s -f -X POST "$YOUTRACK_URL/api/issues/SOF-123/comments?fields=text" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Content-Type: application/json" \
  -d '{"text":"..."}' | jq .
```

Full REST reference: `$YOUTRACK_URL/api` follows the standard YouTrack REST API. Creating tickets is already handled by `/ad-hoc-pr` — use that rather than rolling your own POST for the PR flow.

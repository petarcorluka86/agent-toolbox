Create a GitHub Pull Request and a linked YouTrack ticket for the current branch.

## Inputs

- **YouTrack ticket title** (optional hint): $ARGUMENTS

## Steps

### 0. Load environment

Source `commands/.env` (located in the same directory as this command). Prefix every subsequent bash command with `source <path-to-.env> &&` so the variables are available.

### 1. Gather context

- Run `git log $(git merge-base HEAD master)..HEAD --oneline` to get all commits on this branch.
- Run `git diff master...HEAD` to see the full diff.
- Run `git branch --show-current` to get the current branch name.

### 2. Clarify the problem (if needed)

Review the diff and commits. If the purpose of the changes is **not immediately obvious** — e.g., subtle bug fixes, behavioral changes, or context-dependent logic — **ask the user** to explain:

- What was the problem / motivation?
- How can QA verify the fix?

Do NOT guess or make assumptions. It's better to ask than to write an inaccurate description.

If the changes are straightforward and self-explanatory (e.g., a clear refactor, a renamed variable, an obvious bug fix), skip this step.

### 3. Propose YouTrack ticket (step 1 of 2)

Based on the context gathered (and user's explanation if asked), propose:

- **YouTrack ticket title** — must start with `[ApplicationName/PackageName] [ModuleName]` prefix. Infer both from the diff and folder structure. If you cannot confidently determine either, ask the user. Use the `$ARGUMENTS` hint if provided, otherwise derive from the changes. Be direct and specific — no filler words.
- **YouTrack ticket description** — QA-oriented. Explain: what the problem was, what the expected behavior should be, and how to verify the fix. This is for QA testers, not developers. Write in plain, clear language — no filler text, no padding, easy to skim.

Present these to the user and **ask for confirmation or edits**. Do NOT proceed until approved.

### 4. Propose PR details (step 2 of 2)

Once the YouTrack content is approved, propose:

- **PR title** — concise and descriptive, starts with `[Application/PackageName] [ModuleName]`. Use the same prefix inferred in step 3.
- **"What's new" section** — a bulleted summary of the code changes (developer-oriented). Write in plain, clear language — no filler text, no padding, easy to skim.

Present these to the user and **ask for confirmation or edits**. Do NOT proceed until approved.

### 5. Build the staging link

Construct the staging URL from the branch name:

```
https://<branch-name>.$STAGING_DOMAIN
```

### 6. Create the YouTrack ticket

Once the user approves, create a YouTrack issue via the REST API:

```bash
curl -s -X POST "$YOUTRACK_URL/api/issues?fields=id,idReadable" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project": {"id": "'"$YOUTRACK_PROJECT_ID"'"},
    "summary": "<APPROVED_TICKET_TITLE>",
    "description": "<APPROVED_QA_DESCRIPTION>",
    "customFields": [{"name": "Type", "$type": "SingleEnumIssueCustomField", "value": {"name": "Task", "id": "'"$YOUTRACK_TASK_TYPE_ID"'"}}],
    "tags": [{"id": "'"$YOUTRACK_TAG_ID"'", "name": "'"$YOUTRACK_TAG_NAME"'"}]
  }'
```

Extract the `idReadable` (e.g., `ZETA-1234`) from the response.

Then assign it to the current user:

```bash
curl -s -X POST "$YOUTRACK_URL/api/commands" \
  -H "Authorization: Bearer $YOUTRACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "issues": [{"idReadable": "<ISSUE_ID>"}],
    "query": "for '"$YOUTRACK_USERNAME"'"
  }'
```

### 7. Create the GitHub PR

Use `gh pr create` with the repo's PR template format:

```
### :notebook: [YouTrack]($YOUTRACK_URL/issue/<ISSUE_ID>)

### :link: [Staging environment](https://<branch-name>.$STAGING_DOMAIN)

## :sparkles: What's new

- <approved "What's new" bullets>

```

- PR title: the approved PR title.
- Base branch: `master`.

### 8. Output

Print:

- YouTrack ticket URL
- GitHub PR URL
- Staging URL

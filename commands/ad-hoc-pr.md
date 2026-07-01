---
allowed-tools: Bash(bash *), Bash(git *), Read, Write, Grep, Glob
description: Create a GitHub PR and a linked YouTrack ticket for the current branch
---

Create a GitHub Pull Request and a linked YouTrack ticket for the current branch.

Prerequisites: `jq` and `gh` (authenticated — `brew install gh && gh auth login`). The creation script (step 5) sources `commands/.env` on its own, so you don't need to source it manually.

## Inputs

- **YouTrack ticket title** (optional hint): $ARGUMENTS

## Steps

### 1. Gather context

- Determine the default branch: `bash /Users/petarcorluka/RemoteConfig/agent-toolbox/commands/scripts/_default_branch.sh` (call it `<BASE>`).
- Run `git log $(git merge-base HEAD <BASE>)..HEAD --oneline` to get all commits on this branch.
- Run `git diff <BASE>...HEAD` to see the full diff.
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

### 5. Create everything via the script

Once **both** the ticket content (step 3) and the PR content (step 4) are approved, hand the approved text to the deterministic script. It creates the YouTrack ticket (with a safely-built JSON payload), assigns it to you, pushes the branch, and opens the linked PR against the repo's detected default branch.

Because multi-line content with quotes/newlines breaks inline shell quoting, **write the approved description and PR "What's new" bullets to files** (use the scratchpad dir), then pass file paths:

```bash
# 1. Write approved content to temp files (use the Write tool, not echo).
#    - <SCRATCH>/ticket-desc.md  → the approved QA description
#    - <SCRATCH>/pr-body.md      → the approved "What's new" bullets (markdown list)

# 2. Run the script from inside the repo:
bash /Users/petarcorluka/RemoteConfig/agent-toolbox/commands/scripts/create-ticket-and-pr.sh \
  "<CURRENT_BRANCH>" \
  "<APPROVED_TICKET_TITLE>" \
  "<SCRATCH>/ticket-desc.md" \
  "<APPROVED_PR_TITLE>" \
  "<SCRATCH>/pr-body.md"
```

The script sources `commands/.env` itself and requires `jq` and `gh` (authenticated). If it exits non-zero, relay its error output to the user and stop — do not retry blindly.

### 6. Output

The script prints the YouTrack ticket URL, the PR URL, and the staging URL. Relay them to the user.

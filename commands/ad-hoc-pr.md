---
allowed-tools: Bash(bash *), Bash(git *), Read, Write, Grep, Glob
description: Create a GitHub PR for the current branch, plus a linked YouTrack ticket if YouTrack is configured
---

Create a GitHub Pull Request for the current branch — and a linked YouTrack ticket, **if** YouTrack is configured in `commands/.env`. When it isn't, this is a plain PR creator and every YouTrack step below is skipped.

Prerequisites: `jq` and `gh` (authenticated — `brew install gh && gh auth login`). The creation script (step 5) sources `commands/.env` on its own, so you don't need to source it manually.

## Inputs

- **Ticket/PR title** (optional hint): $ARGUMENTS

## Steps

### 0. Check which integrations are on

```bash
bash ~/RemoteConfig/agent-toolbox/commands/scripts/config-status.sh
```

It prints `youtrack=on|off` and `staging=on|off`. **If `youtrack=off`, skip step 3 entirely** — don't propose a ticket, don't mention YouTrack, and pass empty strings for the ticket arguments in step 5. The PR is then created on its own.

### 1. Gather context

- Determine the default branch: `bash ~/RemoteConfig/agent-toolbox/commands/scripts/_default_branch.sh` (call it `<BASE>`).
- Run `git log $(git merge-base HEAD <BASE>)..HEAD --oneline` to get all commits on this branch.
- Run `git diff <BASE>...HEAD` to see the full diff.
- Run `git branch --show-current` to get the current branch name.

### 2. Clarify the problem (if needed)

Review the diff and commits. If the purpose of the changes is **not immediately obvious** — e.g., subtle bug fixes, behavioral changes, or context-dependent logic — **ask the user** to explain:

- What was the problem / motivation?
- How can QA verify the fix?

Do NOT guess or make assumptions. It's better to ask than to write an inaccurate description.

If the changes are straightforward and self-explanatory (e.g., a clear refactor, a renamed variable, an obvious bug fix), skip this step.

### 3. Propose YouTrack ticket (step 1 of 2) — **only if `youtrack=on`**

Skip this whole step when step 0 reported `youtrack=off`, and go straight to step 4.

Based on the context gathered (and user's explanation if asked), propose:

- **YouTrack ticket title** — must start with `[ApplicationName/PackageName] [ModuleName]` prefix. Infer both from the diff and folder structure. If you cannot confidently determine either, ask the user. Use the `$ARGUMENTS` hint if provided, otherwise derive from the changes. Be direct and specific — no filler words.
- **YouTrack ticket description** — QA-oriented. Explain: what the problem was, what the expected behavior should be, and how to verify the fix. This is for QA testers, not developers. Write in plain, clear language — no filler text, no padding, easy to skim.

Present these to the user and **ask for confirmation or edits**. Do NOT proceed until approved.

### 4. Propose PR details (step 2 of 2)

Once the YouTrack content is approved (or immediately, if `youtrack=off`), propose:

- **PR title** — concise and descriptive, starts with `[Application/PackageName] [ModuleName]`. Use the same prefix inferred in step 3.
- **"What's new" section** — a bulleted summary of the code changes (developer-oriented). Write in plain, clear language — no filler text, no padding, easy to skim.

Present these to the user and **ask for confirmation or edits**. Do NOT proceed until approved.

### 5. Create everything via the script

Once the approvals you needed are in (ticket content from step 3 if YouTrack is on, plus PR content from step 4), hand the approved text to the deterministic script. It pushes the branch, opens the PR against the repo's detected default branch, and — when YouTrack is on — first creates the ticket (with a safely-built JSON payload), assigns it to you, and links it from the PR body.

Because multi-line content with quotes/newlines breaks inline shell quoting, **write the approved text to files** (use the scratchpad dir), then pass file paths:

```bash
# 1. Write approved content to temp files (use the Write tool, not echo).
#    - <SCRATCH>/pr-body.md      → the approved "What's new" bullets (markdown list)
#    - <SCRATCH>/ticket-desc.md  → the approved QA description (only if youtrack=on)

# 2. Run the script from inside the repo:
bash ~/RemoteConfig/agent-toolbox/commands/scripts/create-ticket-and-pr.sh \
  "<CURRENT_BRANCH>" \
  "<APPROVED_TICKET_TITLE>" \
  "<SCRATCH>/ticket-desc.md" \
  "<APPROVED_PR_TITLE>" \
  "<SCRATCH>/pr-body.md"
```

**If `youtrack=off`**, there is no ticket title or description — pass empty strings for those two arguments; the script ignores them:

```bash
bash ~/RemoteConfig/agent-toolbox/commands/scripts/create-ticket-and-pr.sh \
  "<CURRENT_BRANCH>" "" "" "<APPROVED_PR_TITLE>" "<SCRATCH>/pr-body.md"
```

The script sources `commands/.env` itself and requires `jq` and `gh` (authenticated). If it exits non-zero, relay its error output to the user and stop — do not retry blindly.

### 6. Output

The script prints the PR URL, plus the YouTrack ticket and staging URLs when those integrations are on. Relay whatever it prints to the user.

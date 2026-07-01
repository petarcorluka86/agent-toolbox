---
allowed-tools: Bash(bash *), Bash(git *), Bash(gh *), Read, Write, Grep, Glob
description: Analyze the branch's code changes and update the open PR description to match
---

Analyze the current branch's code changes and update the description of its open GitHub PR — for when you've pushed more changes after opening the PR and the description is now stale.

Prerequisites: `gh` (authenticated — `brew install gh && gh auth login`). The update script (step 6) verifies the PR and edits it; you don't need to source `.env`.

## Steps

### 1. Gather context

- Determine the default branch: `bash /Users/petarcorluka/RemoteConfig/agent-toolbox/commands/scripts/_default_branch.sh` (call it `<BASE>`).
- Run `git branch --show-current` to get the current branch (call it `<BRANCH>`).
- Run `git log $(git merge-base HEAD <BASE>)..HEAD --oneline` to get all commits on this branch.
- Run `git diff <BASE>...HEAD` to see the **full** current diff (the complete state of the branch, not just the latest changes).

### 2. Read the current PR

- Run `gh pr view <BRANCH> --json url,title,body` to fetch the open PR's title and body.
- If there is no open PR for the branch, tell the user and stop — this command updates an existing PR, use `/ad-hoc-pr` to create one.

### 3. Reconcile the description with the diff

Compare the existing PR body against the full diff and commits. The goal is to make the **"What's new"** section accurately reflect the entire current state of the branch — add what's now covered, remove what no longer applies, correct anything that drifted.

Preserve the structural header lines the PR was created with (do NOT regenerate or drop them):

- The `### :notebook: [YouTrack](…)` link line.
- The `### :link: [Staging environment](…)` link line.

Only the content under `## :sparkles: What's new` should change. If the existing body has a different structure (e.g. a hand-written PR not created by `/ad-hoc-pr`), preserve whatever headers/sections exist and update the change summary in place — match the existing format rather than imposing this one.

If the purpose of any change is **not immediately obvious** (subtle bug fixes, behavioral changes, context-dependent logic), **ask the user** rather than guessing. If the changes are self-explanatory, skip this.

### 4. Propose the updated description

Present the **full** proposed PR body (headers + updated "What's new" bullets) to the user. Write the bullets in plain, clear, developer-oriented language — no filler, no padding, easy to skim. Briefly note what you changed relative to the old description (added / removed / reworded).

**Ask for confirmation or edits. Do NOT proceed until approved.**

### 5. Write the approved body to a file

Because multi-line content with quotes/newlines breaks inline shell quoting, use the Write tool to write the **complete** approved body (headers included) to `<SCRATCH>/pr-body.md` in the scratchpad dir. This file replaces the PR body wholesale, so it must contain everything — not just the changed section.

### 6. Update the PR via the script

Run from inside the repo:

```bash
bash /Users/petarcorluka/RemoteConfig/agent-toolbox/commands/scripts/update-pr-body.sh \
  "<BRANCH>" \
  "<SCRATCH>/pr-body.md"
```

The script verifies an open PR exists for the branch and replaces its body. If it exits non-zero, relay its error output to the user and stop — do not retry blindly.

### 7. Output

The script prints the PR URL. Relay it to the user.

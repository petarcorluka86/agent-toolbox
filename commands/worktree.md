---
allowed-tools: Bash(bash *), Bash(git *), Bash(cursor *), Bash(pnpm *), Bash(yarn *), Bash(npm *), Bash(bun *)
description: Create a git worktree for a branch (creating the branch if needed), install deps, and open it in a new Cursor window with an active terminal
---

Create a git worktree for a branch, install dependencies, and open it in a new Cursor window.

## Inputs

- **Branch name**: $ARGUMENTS — the branch to create a worktree for. If empty, ask the user for the branch name and stop until they provide one.

## What it does

All logic lives in a deterministic script: `commands/scripts/worktree.sh`. It:

1. Resolves the worktree path to `<repo-parent>/<repo-name>.worktrees/<branch>`.
2. Prunes stale worktree registrations, then creates the worktree — handling three cases: attach to an existing local branch, check out an existing remote branch (with tracking), or create a new branch off the repo's **detected default branch**.
3. For existing branches, pulls latest from origin with `--ff-only` (never merges/forces).
4. Installs dependencies with the repo's package manager (pnpm / yarn / bun / npm, auto-detected from the lockfile).
5. Writes (or merges into) `.vscode/tasks.json` so a focused terminal opens automatically — no chat panel.
6. Opens the worktree in a **new** Cursor window.

The script is idempotent (re-running reuses the worktree and reopens it) and never force-removes anything.

## Steps

### 1. Run the script

Run it from **inside the target repository** (so git resolves the right repo), passing the branch name:

```bash
bash ~/RemoteConfig/agent-toolbox/commands/scripts/worktree.sh "<BRANCH_NAME>"
```

- If the user didn't supply a branch, ask first — don't invent one.
- If the script exits non-zero (e.g. the branch is already checked out in another worktree, or a fast-forward failed), relay its error message to the user and stop. Do not retry with force.

### 2. Report

Print the script's summary block (branch, mode, path, deps, tasks, cursor) back to the user. If dependency install failed, call that out — the window still opens so they can debug there.

## Notes

- Requires the `cursor` CLI on PATH and the global setting `task.allowAutomaticTasks: "on"` (already configured) so the folderOpen terminal task runs without a prompt.
- The worktree's parent folder must be trusted in Cursor (Workspace Trust) for the auto-terminal to fire.
- Testing/debugging flags: `WORKTREE_NO_OPEN=1` skips launching Cursor; `WORKTREE_NO_INSTALL=1` skips dependency install.

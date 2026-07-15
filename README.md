# 🧰 Agent Toolkit

> A personal collection of commands, skills, and other reusable items for working with AI agents.

---

## ⚙️ Setup

The toolbox must live at `~/RemoteConfig/agent-toolbox` (see *Paths* below).

**1. Configure.** Copy `.env.example` to `.env` inside `commands/` and fill in your values:

```bash
cp commands/.env.example commands/.env
chmod 600 commands/.env   # it can hold a YouTrack token
```

Commands source `commands/.env` at runtime — no shell configuration needed.

Only the **GitHub** vars are required. **YouTrack** and the **staging link** are optional: leave them blank and the commands skip those steps — `ad-hoc-pr` opens a plain PR with no ticket, and `review-pr` doesn't look for linked tickets. Fill them in later to switch the integration on; nothing else needs to change. `scripts/config-status.sh` prints what's currently on.

**2. Install.** Symlink the whole `commands/` dir into Claude Code so the files show up as slash commands — new commands then appear automatically:

```bash
ln -sfn ~/RemoteConfig/agent-toolbox/commands ~/.claude/commands
chmod +x commands/scripts/*.sh
```

⚠️ Never symlink individual command files on top of this — `ln` resolves through the dir symlink and replaces the real file with a self-referencing link.

### ⚠️ Paths

Command files reference the toolbox as `~/RemoteConfig/agent-toolbox/commands/...` — Claude Code slash commands have no reliable "own directory" variable, so the path must be written out. It's tilde-relative, so it works for any user, but **the location is fixed: if you move the toolbox, find/replace that path across `commands/*.md`.** (The scripts themselves resolve their own directory and don't need this.)

### Prerequisites

- **`jq`** — used by the helper scripts to build/parse JSON.
- **`gh`** (GitHub CLI), authenticated — required by `ad-hoc-pr` and `review-pr`. Install with `brew install gh && gh auth login`.
- **`cursor`** CLI on PATH — required by `worktree`.

---

## 📦 What's inside

### Commands

| Command | Description |
| --- | --- |
| **`ad‑hoc‑pr`** | Creates a new YouTrack ticket and a GitHub PR linked to it. Gathers context from your branch, proposes ticket and PR details for approval, then creates both via `scripts/create-ticket-and-pr.sh`. |
| **`update‑pr`** | Updates the description of the open PR for the current branch to match its current code changes — for when you've pushed more work after opening the PR. Reads the full diff and existing body, proposes an updated "What's new" section for approval (preserving the YouTrack/Staging headers), then edits the PR via `scripts/update-pr-body.sh`. |
| **`review‑pr`** | Reviews a PR where you're requested as a reviewer. Lists pending reviews, analyzes the diff, runs parallel code review checks, and presents findings with a verdict. |
| **`review‑branch`** | First-principles audit of the current branch against the repo's default branch. Runs parallel agents across DRY, simplicity/performance, UX, clean code, and i18n — questioning the approach, not just hunting bugs — and ends with a ship/rethink verdict. |
| **`iterate‑items`** | Walks through a list from the previous turn (audit findings, plan steps, review issues) one item at a time, proposing an action for each and waiting for your go-ahead before acting. |
| **`polish‑comments`** | Reviews the comments the current branch adds vs the default branch, deletes the ones that restate what the code already says, and rewrites the useful ones to be direct and minimal. Comments only — never touches executable code or pre-existing comments. |
| **`junior-help`** | Explains a topic, file, or concept as if to a junior dev on their first day — no assumed context, jargon defined, grounded in the actual repo, with traps and where-to-look-next. `/junior-help <topic>`. |
| **`worktree`** | Creates a git worktree for a branch (creating the branch off the default branch if it doesn't exist), installs dependencies with the repo's package manager, and opens it in a new Cursor window with an auto-focused terminal. Run from inside the target repo: `/worktree my-branch`. |
| **`optimize‑agent‑docs`** | Audits every file that feeds an AI agent's context (`CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, `.cursorrules`, Copilot instructions…) and restructures them so agents get better guidance for fewer tokens. Verifies each documented command/path/convention against the actual repo (stale docs are worse than missing ones), cuts what the agent could read for itself, and moves subsystem rules and procedures out of always-loaded context into path-scoped rules and skills. Proposes a plan with a token before/after, then applies on approval. |

### Scripts

Deterministic helpers in `commands/scripts/` that commands delegate to for speed and reliability:

| Script | Used by | Purpose |
| --- | --- | --- |
| **`worktree.sh`** | `worktree` | End-to-end worktree creation, dep install, tasks.json (git-excluded so it stays out of `git status`), and Cursor launch. |
| **`create-ticket-and-pr.sh`** | `ad-hoc-pr` | Creates + assigns the YouTrack ticket and opens the PR, with safe `jq`-built payloads. Deletes the ticket again if the PR fails to open, so a failed run leaves nothing behind. |
| **`update-pr-body.sh`** | `update-pr` | Verifies the branch's open PR exists, then replaces its body from a file via `gh pr edit`. |
| **`scan-agent-docs.sh`** | `optimize-agent-docs` | Inventories every agent-context file in the current repo — tokens, and whether each loads **eagerly** (billed every session) or **lazily** (only when relevant). Expands `@import` chains so imported docs are billed to the eager total, since splitting a file into imports saves nothing. |
| **`_default_branch.sh`** | several | Detects the repo's default branch (no hardcoded `master`). |
| **`_env.sh`** | scripts | Sources `commands/.env` regardless of the caller's cwd, and exposes `youtrack_configured` / `staging_configured` so callers can skip optional integrations instead of failing. |
| **`config-status.sh`** | `ad-hoc-pr`, `review-pr` | Prints `youtrack=on\|off` and `staging=on\|off` so a command knows which steps to skip. |

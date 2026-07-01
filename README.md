# 🧰 Agent Toolkit

> A personal collection of commands, skills, and other reusable items for working with AI agents.

---

## ⚙️ Setup

Copy `.env.example` to `.env` inside the `commands/` folder and fill in your values:

```bash
cp commands/.env.example commands/.env
```

Commands automatically source `commands/.env` at runtime — no shell configuration needed.

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
| **`review‑pr`** | Reviews a PR where you're requested as a reviewer. Lists pending reviews, analyzes the diff, runs parallel code review checks, and presents findings with a verdict. |
| **`review‑branch`** | First-principles audit of the current branch against the repo's default branch. Runs parallel agents across DRY, simplicity/performance, UX, clean code, and i18n — questioning the approach, not just hunting bugs — and ends with a ship/rethink verdict. |
| **`iterate‑items`** | Walks through a list from the previous turn (audit findings, plan steps, review issues) one item at a time, proposing an action for each and waiting for your go-ahead before acting. |
| **`worktree`** | Creates a git worktree for a branch (creating the branch off the default branch if it doesn't exist), installs dependencies with the repo's package manager, and opens it in a new Cursor window with an auto-focused terminal. Run from inside the target repo: `/worktree my-branch`. |

### Scripts

Deterministic helpers in `commands/scripts/` that commands delegate to for speed and reliability:

| Script | Used by | Purpose |
| --- | --- | --- |
| **`worktree.sh`** | `worktree` | End-to-end worktree creation, dep install, tasks.json, and Cursor launch. |
| **`create-ticket-and-pr.sh`** | `ad-hoc-pr` | Creates + assigns the YouTrack ticket and opens the PR, with safe `jq`-built payloads. |
| **`_default_branch.sh`** | several | Detects the repo's default branch (no hardcoded `master`). |
| **`_env.sh`** | scripts | Sources `commands/.env` regardless of the caller's cwd. |

# 🧰 Agent Toolkit

> A personal collection of commands, skills, and other reusable items for working with AI agents.

---

## ⚙️ Setup

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Commands automatically source the `.env` file at runtime — no shell configuration needed.

---

## 📦 What's inside

### Commands

| Command | Description |
| --- | --- |
| **`ad‑hoc‑pr`** | Creates a new YouTrack ticket and a GitHub PR linked to it. Gathers context from your branch, proposes ticket and PR details for approval, then creates both automatically. |
| **`review‑pr`** | Reviews a PR where you're requested as a reviewer. Lists pending reviews, analyzes the diff, runs parallel code review checks, and presents findings with a verdict. |

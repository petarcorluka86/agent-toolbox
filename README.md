# Agent Toolkit

A personal collection of commands, skills, and other reusable items for working with AI agents.

This is built for my own needs, but feel free to use anything here.

## Setup

1. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   ```

2. Source it from your shell config (e.g. `.zshrc`):
   ```bash
   [ -f ~/path/to/agent-toolkit/.env ] && source ~/path/to/agent-toolkit/.env
   ```

## What's inside

### Commands

- **ad-hoc-pr** — Creates a new YouTrack ticket and a GitHub PR linked to it. Gathers context from your branch, proposes ticket and PR details for approval, then creates both automatically.
- **review-pr** — Reviews a PR where you're requested as a reviewer. Lists pending reviews, analyzes the diff, runs parallel code review checks, and presents findings with a verdict.

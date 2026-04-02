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

- `commands/` — reusable commands for Claude Code (PR creation, code review, etc.)

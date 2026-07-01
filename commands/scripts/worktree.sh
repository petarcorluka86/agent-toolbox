#!/usr/bin/env bash
# Create a git worktree for a branch (creating the branch if needed), install
# deps, drop an auto-terminal task, and open it in a new Cursor window.
#
# Usage:   worktree.sh <branch>
# Env:     WORKTREE_NO_OPEN=1   skip launching Cursor (useful for testing)
#          WORKTREE_NO_INSTALL=1 skip dependency install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCH="${1:-}"
if [ -z "$BRANCH" ]; then
  echo "usage: worktree.sh <branch>" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not inside a git repository — run this from within the target repo" >&2
  exit 1
}
cd "$REPO_ROOT"
REPO_NAME="$(basename "$REPO_ROOT")"
PARENT_DIR="$(dirname "$REPO_ROOT")"
WORKTREE_DIR="$PARENT_DIR/$REPO_NAME.worktrees/$BRANCH"

# Clean up stale registrations (e.g. a worktree dir deleted by hand).
git worktree prune

MODE=""
if git worktree list --porcelain | grep -qxF "worktree $WORKTREE_DIR"; then
  MODE="reused existing worktree"
  echo "worktree already exists at $WORKTREE_DIR — reopening"
else
  DEFAULT_BRANCH="$(bash "$SCRIPT_DIR/_default_branch.sh")"
  git fetch origin "$DEFAULT_BRANCH" --quiet || true

  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    MODE="attached existing local branch '$BRANCH'"
    git worktree add "$WORKTREE_DIR" "$BRANCH"
  elif git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    MODE="checked out remote branch '$BRANCH'"
    git fetch origin "$BRANCH" --quiet
    git worktree add --track -b "$BRANCH" "$WORKTREE_DIR" "origin/$BRANCH"
  else
    MODE="created new branch '$BRANCH' off '$DEFAULT_BRANCH'"
    git worktree add -b "$BRANCH" "$WORKTREE_DIR" "origin/$DEFAULT_BRANCH"
  fi

  # Pull latest for branches that exist on origin (ff-only, never merge/force).
  case "$MODE" in
    "created new branch"*) : ;;  # already based on fresh origin/<default>
    *)
      if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
        if ! git -C "$WORKTREE_DIR" pull --ff-only origin "$BRANCH"; then
          echo "warning: '$BRANCH' diverged from origin — could not fast-forward; resolve it in the new window" >&2
        fi
      fi
      ;;
  esac
fi

# ---- Install dependencies -------------------------------------------------
INSTALL="skipped (no package.json)"
if [ -z "${WORKTREE_NO_INSTALL:-}" ] && [ -f "$WORKTREE_DIR/package.json" ]; then
  PM=""
  if   [ -f "$WORKTREE_DIR/pnpm-lock.yaml" ];   then PM=pnpm
  elif [ -f "$WORKTREE_DIR/yarn.lock" ];        then PM=yarn
  elif [ -f "$WORKTREE_DIR/bun.lockb" ] || [ -f "$WORKTREE_DIR/bun.lock" ]; then PM=bun
  elif [ -f "$WORKTREE_DIR/package-lock.json" ];then PM=npm
  fi
  if [ -n "$PM" ]; then
    echo "installing dependencies with $PM..."
    if ( cd "$WORKTREE_DIR" && "$PM" install ); then
      INSTALL="$PM install: ok"
    else
      INSTALL="$PM install: FAILED (opening anyway so you can debug)"
    fi
  else
    INSTALL="skipped (no recognized lockfile)"
  fi
elif [ -n "${WORKTREE_NO_INSTALL:-}" ]; then
  INSTALL="skipped (WORKTREE_NO_INSTALL set)"
fi

# ---- Auto-terminal task (open a focused terminal, no chat) ----------------
VSC_DIR="$WORKTREE_DIR/.vscode"
TASKS="$VSC_DIR/tasks.json"
TASK_JSON='{"label":"open-terminal","type":"shell","command":"clear","presentation":{"reveal":"always","panel":"new","focus":true},"runOptions":{"runOn":"folderOpen"},"problemMatcher":[]}'
mkdir -p "$VSC_DIR"
if [ ! -f "$TASKS" ]; then
  printf '{\n  "version": "2.0.0",\n  "tasks": [\n    %s\n  ]\n}\n' "$TASK_JSON" > "$TASKS"
  TASKMSG="created .vscode/tasks.json"
elif command -v jq >/dev/null 2>&1; then
  if jq -e 'any(.tasks[]?; .runOptions.runOn == "folderOpen")' "$TASKS" >/dev/null 2>&1; then
    TASKMSG="left existing tasks.json (folderOpen task already present)"
  else
    tmp="$(mktemp)"
    jq --argjson t "$TASK_JSON" '.tasks += [$t]' "$TASKS" > "$tmp" && mv "$tmp" "$TASKS"
    TASKMSG="added open-terminal task to existing tasks.json"
  fi
else
  TASKMSG="tasks.json already exists and jq is unavailable — left untouched"
fi

# ---- Open in a new Cursor window ------------------------------------------
if [ -z "${WORKTREE_NO_OPEN:-}" ]; then
  cursor -n "$WORKTREE_DIR"
  OPENMSG="opened new Cursor window"
else
  OPENMSG="skipped opening Cursor (WORKTREE_NO_OPEN set)"
fi

# ---- Summary --------------------------------------------------------------
cat <<EOF

── worktree ready ──
branch:    $BRANCH  ($MODE)
path:      $WORKTREE_DIR
deps:      $INSTALL
tasks:     $TASKMSG
cursor:    $OPENMSG
EOF

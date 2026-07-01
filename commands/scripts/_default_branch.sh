#!/usr/bin/env bash
# Print the current repo's default branch. Must be run from inside the repo.
# Tries origin/HEAD (local, fast), then a network query, then main/master heuristics.
set -euo pipefail

db="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"

if [ -z "$db" ]; then
  # origin/HEAD not set locally — try to learn it from the remote (network).
  db="$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' || true)"
fi

if [ -z "$db" ]; then
  if git show-ref --verify --quiet refs/remotes/origin/main; then db=main
  elif git show-ref --verify --quiet refs/remotes/origin/master; then db=master
  else db=master
  fi
fi

echo "$db"

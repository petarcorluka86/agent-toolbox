#!/usr/bin/env bash
# Source the toolbox .env regardless of the caller's cwd.
# Usage: . "$(dirname "$0")/_env.sh"   (or from another script in this dir)
_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$_env_dir/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$_env_dir/.env"
  set +a
else
  echo "error: $_env_dir/.env not found — copy .env.example to .env and fill it in" >&2
  return 1 2>/dev/null || exit 1
fi

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

# Optional integrations. Callers use these to skip the corresponding feature
# rather than fail, so a GitHub-only .env is a fully valid setup.
#
# An unfilled placeholder from .env.example counts as "not configured" — otherwise
# a half-copied .env would send real requests to youtrack.example.com.
_is_set() {
  [ -n "${1:-}" ] || return 1
  case "$1" in
    your-*|*example.com|*.example.dev) return 1 ;;
  esac
  return 0
}

# YouTrack needs at minimum a URL, a token, and a project to file the issue in.
youtrack_configured() {
  _is_set "${YOUTRACK_URL:-}" && _is_set "${YOUTRACK_TOKEN:-}" && _is_set "${YOUTRACK_PROJECT_ID:-}"
}

staging_configured() {
  _is_set "${STAGING_DOMAIN:-}"
}

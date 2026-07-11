#!/usr/bin/env bash
# Print which optional integrations are configured, so a command can decide
# whether to run the YouTrack / staging steps instead of guessing.
#
# Output (stable, parseable):
#   youtrack=on|off
#   staging=on|off
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/_env.sh"

if youtrack_configured; then echo "youtrack=on"; else echo "youtrack=off"; fi
if staging_configured;  then echo "staging=on";  else echo "staging=off";  fi

#!/usr/bin/env bash
# Inventory every file in the current repo that feeds an AI agent's context.
# Run from inside the target repo (not the toolbox).
#
# The point of this script is the `load` column. An agent-doc audit is only
# meaningful if you know which files are paid for on *every* session (eager)
# versus only when relevant (lazy) — token waste lives almost entirely in the
# eager set, and moving a file from eager to lazy is the main lever.
#
# Output (stable, TSV, one header line then one row per file):
#   path <TAB> kind <TAB> lines <TAB> bytes <TAB> est_tokens <TAB> load <TAB> tracked
# Then a blank line and KEY=value summary lines.
#
# est_tokens is bytes/4 — a deliberate rough proxy, good enough to rank files
# and size a budget. Don't present it as exact.
set -euo pipefail

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 1
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Candidate agent-context files, by tool. Globs are matched against paths
# relative to the repo root. Keep this list in sync with the command doc.
find_candidates() {
  find . \
    \( -name node_modules -o -name .git -o -name dist -o -name build \
       -o -name vendor -o -name .next -o -name target -o -name .venv \) -prune -o \
    -type f \( \
      -name 'CLAUDE.md' -o -name 'CLAUDE.local.md' \
      -o -name 'AGENTS.md' -o -name 'AGENT.md' \
      -o -name 'GEMINI.md' -o -name 'QWEN.md' \
      -o -name '.cursorrules' -o -name '*.mdc' \
      -o -name '.windsurfrules' -o -name '.clinerules' \
      -o -name 'copilot-instructions.md' \
      -o -name '.aider.conf.yml' -o -name 'CONVENTIONS.md' \
      -o -name 'SKILL.md' \
    \) -print 2>/dev/null | sed 's|^\./||'

  # Directory-scoped rule/agent files that don't have a distinctive basename.
  for d in .claude/rules .claude/agents .claude/commands .cursor/rules \
           .windsurf/rules .github/instructions .junie .devin/rules .continue/rules; do
    [ -d "$d" ] || continue
    find "$d" -type f \( -name '*.md' -o -name '*.mdc' \) -print 2>/dev/null | sed 's|^\./||'
  done
  # Never fail: a missing last directory would otherwise abort the caller under `set -e`.
  return 0
}

# Classify a path into the tool/mechanism that consumes it.
# Patterns are matched against repo-relative paths, so each nested form needs an
# explicit `*/` variant — a monorepo keeps per-package .cursorrules and rule dirs,
# not just root ones, and misfiling those silently mis-states the budget.
kind_of() {
  case "$1" in
    .claude/rules/*|*/.claude/rules/*)        echo "claude-path-rule" ;;
    */SKILL.md)                               echo "claude-skill" ;;
    .claude/agents/*|*/.claude/agents/*)      echo "claude-subagent" ;;
    .claude/commands/*|*/.claude/commands/*)  echo "claude-command" ;;
    CLAUDE.local.md|*/CLAUDE.local.md)        echo "claude-local" ;;
    CLAUDE.md|.claude/CLAUDE.md)              echo "claude-root" ;;
    */CLAUDE.md)                              echo "claude-nested" ;;
    AGENTS.md|AGENT.md)                       echo "agents-md-root" ;;
    */AGENTS.md|*/AGENT.md)                   echo "agents-md-nested" ;;
    .cursorrules|*/.cursorrules|.cursor/rules/*|*/.cursor/rules/*|*.mdc) echo "cursor" ;;
    */copilot-instructions.md|.github/instructions/*) echo "copilot" ;;
    .windsurfrules|*/.windsurfrules|*/.windsurf/rules/*) echo "windsurf" ;;
    GEMINI.md|QWEN.md|*/.clinerules|.clinerules|CONVENTIONS.md|*/.aider.conf.yml|.aider.conf.yml|.junie/*|.devin/*|.continue/*) echo "other-tool" ;;
    *)                                        echo "other" ;;
  esac
}

# Three load classes, and the distinction drives the whole audit:
#
#   eager  — in context every session, relevant or not. The budget to shrink.
#   lazy   — auto-loaded by the agent on a match (reading a file in that dir, or
#            a `paths:` glob hit). Size matters much less here.
#   manual — only enters context if something explicitly opens or invokes it.
#
# `manual` is not a synonym for cheap: a manual file that nothing points at is
# documentation that is never read — dead weight that still rots and misleads
# whoever does open it. Claude Code does NOT read AGENTS.md natively, so a nested
# AGENTS.md is manual, not lazy: unlike a nested CLAUDE.md, no file-read pulls it in.
#
# Root CLAUDE.md loads in full at launch. A .claude/rules file is lazy only if it
# actually declares `paths:` frontmatter; without it, it is loaded at launch with
# the same priority as CLAUDE.md. Skills hold only their frontmatter description
# in context (a small eager cost), with the body loaded on invocation.
load_of() {
  local path="$1" kind="$2"
  case "$kind" in
    claude-root|claude-local|agents-md-root)     echo "eager" ;;
    claude-nested)                               echo "lazy" ;;
    claude-skill)                                echo "lazy" ;;
    agents-md-nested|claude-command|claude-subagent) echo "manual" ;;
    claude-path-rule)
      if head -20 "$path" | grep -qE '^[[:space:]]*paths[[:space:]]*:'; then echo "lazy"; else echo "eager"; fi ;;
    cursor|copilot|windsurf)
      # These are eager in their own tool. Cursor .mdc / Copilot instructions can
      # scope themselves with globs; a bare .cursorrules or .windsurfrules cannot.
      if head -20 "$path" | grep -qE '^[[:space:]]*(globs|applyTo)[[:space:]]*:'; then echo "lazy"; else echo "eager"; fi ;;
    *) echo "eager" ;;
  esac
}

# Extract @path imports from a CLAUDE.md, resolved relative to the importing
# file's directory. Skips fenced code blocks and code spans, which the real
# parser also ignores — otherwise a documented `@foo` example counts as an import.
imports_of() {
  local f="$1" dir
  dir="$(dirname "$f")"
  awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    infence { next }
    { gsub(/`[^`]*`/, ""); print }
  ' "$f" 2>/dev/null \
    | grep -oE '(^|[[:space:]])@[A-Za-z0-9._/~-]+' \
    | sed 's/^[[:space:]]*//; s/^@//' \
    | while IFS= read -r imp; do
        case "$imp" in
          /*|~*) target="$imp" ;;                       # absolute / home — outside the repo
          *)     target="$(cd "$dir" 2>/dev/null && printf '%s' "${dir#./}/$imp")"
                 target="${target#./}" ;;
        esac
        [ -f "$target" ] && printf '%s\n' "$target"
      done
}

printf 'path\tkind\tlines\tbytes\test_tokens\tload\ttracked\n'

eager_tokens=0
manual_tokens=0
total_tokens=0
file_count=0
imports_found=""
listed=""

emit_row() {
  local f="$1" kind="$2" load="$3" lines bytes tokens tracked
  lines="$(wc -l < "$f" | tr -d ' ')"
  bytes="$(wc -c < "$f" | tr -d ' ')"
  tokens=$(( bytes / 4 ))
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then tracked=yes; else tracked=no; fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$f" "$kind" "$lines" "$bytes" "$tokens" "$load" "$tracked"

  total_tokens=$(( total_tokens + tokens ))
  case "$load" in
    eager)  eager_tokens=$(( eager_tokens + tokens )) ;;
    manual) manual_tokens=$(( manual_tokens + tokens )) ;;
  esac
  file_count=$(( file_count + 1 ))
  listed="${listed}${f}"$'\n'
}

candidates="$(find_candidates | sort -u)"

while IFS= read -r f; do
  [ -f "$f" ] || continue
  kind="$(kind_of "$f")"
  emit_row "$f" "$kind" "$(load_of "$f" "$kind")"
done <<< "$candidates"

# An @import is expanded into the importing file at launch, so an imported doc
# costs eager tokens even though it looks like an ordinary doc on disk. Walk the
# import graph from every eager file (docs cap the chain at 4 hops) and bill each
# reachable file to the eager budget. Without this, a CLAUDE.md that imports a
# 3k-token architecture doc reports a small eager cost and the audit "fixes"
# nothing. It also means splitting a big CLAUDE.md into imports saves zero tokens.
frontier=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  k="$(kind_of "$f")"
  case "$k" in
    claude-root|claude-nested|claude-local)
      if [ "$(load_of "$f" "$k")" = eager ]; then frontier="${frontier}${f}"$'\n'; fi ;;
  esac
done <<< "$candidates"

depth=0
while [ -n "$frontier" ] && [ "$depth" -lt 4 ]; do
  next=""
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    while IFS= read -r imp; do
      [ -n "$imp" ] || continue
      imports_found="${imports_found}${f} -> ${imp}"$'\n'
      # Already inventoried (as a candidate or via another import) — don't double-bill.
      grep -qxF "$imp" <<< "$listed" && continue
      emit_row "$imp" "imported" "eager"
      next="${next}${imp}"$'\n'
    done < <(imports_of "$f")
  done <<< "$frontier"
  frontier="$next"
  depth=$(( depth + 1 ))
done

echo
echo "FILES=$file_count"
echo "EST_TOKENS_TOTAL=$total_tokens"
echo "EST_TOKENS_EAGER=$eager_tokens"
echo "EST_TOKENS_MANUAL=$manual_tokens"

if [ -n "$imports_found" ]; then
  echo
  echo "# @imports — expanded into the importing file at launch, so they are already"
  echo "#  billed to EST_TOKENS_EAGER above. Splitting a file into imports saves nothing."
  printf '%s' "$imports_found" | sort -u
fi

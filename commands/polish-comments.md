---
allowed-tools: Bash(bash *), Bash(git *), Read, Edit, Grep, Glob
description: Prune and tighten the comments introduced by the current branch vs the default branch
---

Review the comments this branch adds or changes versus the repo's default branch. **Delete every comment that carries no information the code doesn't already convey**, and rewrite the ones worth keeping to be as short and direct as possible. Only touch comments the branch itself introduced or modified — never pre-existing comments in unchanged code.

## Steps

### 1. Gather diff context

Detect the default branch (don't assume `master`):

```bash
BASE="$(bash ~/RemoteConfig/agent-toolbox/commands/scripts/_default_branch.sh)"
```

Then:

```bash
git fetch origin "$BASE" --quiet
git rev-parse --abbrev-ref HEAD
git diff "origin/$BASE"...HEAD --name-only
git diff "origin/$BASE"...HEAD
```

Work only from the **added/changed lines** (lines starting with `+` in the diff). If a comment appears only in unchanged context, leave it alone. If there are no changes vs `origin/$BASE`, stop and tell the user.

### 2. Locate the comments

From the added/changed lines, collect every comment the branch introduced or edited. Include all comment forms in the touched languages, e.g.:

- Line comments: `//`, `#`
- Block comments: `/* … */`, JSDoc/TSDoc `/** … */`
- JSX comments: `{/* … */}`
- Docstrings / documentation comments where the language uses them

Use `Read` on each file to see the comment in its full context — the surrounding code is what decides whether the comment is redundant.

### 3. Judge each comment

For every collected comment, decide **delete** or **tighten**:

**Delete** when the comment adds nothing beyond the code, including:

- Restates what the next line/function plainly does (`// increment counter`, `// return the user`).
- Just names the code below it (`// map over items`, `// state`).
- Information fully derivable from a clear name, type, or signature.
- Commented-out code, leftover TODO/debug scaffolding the branch added with no actionable content, or `// eslint-disable`-style noise that isn't required.
- Section-divider / banner comments that only label obvious structure.
- Redundant JSDoc that repeats the type signature and parameter names without adding meaning.

**Keep — and tighten** when the comment carries information the code cannot express, such as:

- The *why* behind a non-obvious choice, a workaround, or a deliberate trade-off.
- A gotcha, invariant, edge case, or ordering constraint that isn't visible from the code.
- Context on genuinely complex logic, non-trivial algorithms, or external-system quirks.
- A reference (ticket, spec, browser bug, RFC) that explains the code's existence.

When keeping a comment, rewrite it to be **direct, clear, and minimal**:

- Fewest words that still deliver the information — cut filler, hedging, and preamble.
- State the point, not the obvious mechanics around it.
- Keep it accurate to the current code; fix any drift.
- Preserve structured tags (`@param`, `@returns`, `@deprecated`, etc.) only where they add meaning.

When genuinely uncertain whether a comment is load-bearing, **keep it** — deleting real intent is worse than leaving one borderline comment.

### 4. Apply the changes

Use `Edit` to delete or rewrite each comment in place. Remove now-empty lines left behind by deletions, and keep surrounding indentation/formatting intact. Do not change any executable code — comments only.

### 5. Report

Summarize what changed, grouped by file:

- **Deleted** — `file:line` + the removed comment text (truncated), one per line.
- **Tightened** — `file:line` + `before` → `after`.
- **Kept as-is** — only note comments you deliberately left because they were already tight and useful (brief).

End with a one-line tally: N deleted, N tightened, across M files.

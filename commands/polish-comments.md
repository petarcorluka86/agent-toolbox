---
allowed-tools: Bash(bash *), Bash(git *), Read, Edit, Grep, Glob
description: Prune and tighten the comments introduced by the current branch vs the default branch
---

Review the comments this branch adds or changes versus the repo's default branch. **Default to deleting.** The bar for keeping a comment is high: it must carry information a competent reader cannot recover by reading the code itself. If a comment describes *what* the code does — even complex code — delete it; the code is the source of truth for *what*. Keep only comments that explain *why*, or that encode knowledge that lives outside the code entirely. Rewrite the survivors to be as short and direct as possible. Only touch comments the branch itself introduced or modified — never pre-existing comments in unchanged code.

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

Start from the assumption that the comment should be **deleted**. It survives only if it clears the keep bar below.

**Delete** — the default. This covers the large majority of comments, including:

- Restates what the next line/function plainly does (`// increment counter`, `// return the user`).
- Just names the code below it (`// map over items`, `// state`, `// handlers`).
- Information derivable from a clear name, type, or signature.
- **Narrates *what* the code does, even for multi-step or non-trivial logic** — if the explanation is just prose describing the code that follows it, delete it. Complex code justifies a *why*, not a play-by-play. If the code is hard to follow, the fix is clearer code, not a comment.
- Paraphrases or summarizes a block right before/inside it (`// Build the request and send it`).
- Commented-out code, leftover TODO/debug scaffolding the branch added with no actionable content, or `// eslint-disable`-style noise that isn't required.
- Section-divider / banner comments that only label structure.
- **JSDoc / TSDoc doc-comment blocks that just restate the signature.** A `/** */` block whose description and `@param`/`@returns` lines only spell out the function/component name and its typed parameters adds nothing — delete the whole block. Being on an *exported* or *public* function, component, or type is **not** a reason to keep it; the signature already serves IDE hovers. Keep a doc block only for the parts that carry real information (a *why*, a constraint, a unit, a non-obvious contract, `@deprecated` with a reason) — and trim it to just those parts.
- **Prop / field / parameter descriptions that restate the name or type.** A doc comment on an interface field, prop, or parameter whose text is just the name spelled out in words is noise — the name and type already say it. Delete the comment (keep the field). Examples to delete:
  - `/** The id of the label */ labelId?: string` → keep `labelId?: string`, drop the comment.
  - `/** Whether the button is disabled */ disabled?: boolean`
  - `/** Callback fired on click */ onClick: () => void`
  - `// user id` above `userId: string`
  Only keep such a comment if it adds something the signature cannot: a unit, a format, an allowed range, a non-obvious default, a constraint, or a *why* (e.g. `/** milliseconds; must be < 30_000 or the gateway drops it */`).
- **JSX / render narration.** Comments that announce what a component or element renders. The JSX below is already the description. Examples to delete:
  - `{/* Render the header */}`, `{/* Header */}`, `{/* Modal footer with actions */}`
  - `// renders the list of items`, `// return the card`
  Keep only if it flags something the markup can't show (e.g. `{/* Rendered outside the form on purpose — submits via portal */}`).

**Keep — and tighten** only when the comment encodes something genuinely *not* in the code:

- The *why* behind a non-obvious choice, a workaround, or a deliberate trade-off — and the *why* is not obvious from context.
- A gotcha, invariant, edge case, or ordering constraint whose violation would break things and which is not visible from the code.
- An external-system quirk or contract the code must match but cannot express.
- A reference (ticket, spec, browser bug, RFC) that explains the code's existence.

Applying the keep bar: ask "would a competent engineer reading this code be missing something real without this comment?" If the answer is "no, they'd just be told what they can already see," delete it. A comment is not load-bearing merely because the code near it is complicated.

When keeping a comment, rewrite it to be **direct, clear, and minimal**:

- Fewest words that still deliver the information — cut filler, hedging, and preamble.
- State the point, not the obvious mechanics around it.
- Keep it accurate to the current code; fix any drift.
- Preserve structured tags (`@param`, `@returns`, `@deprecated`, etc.) only where they add meaning.

When genuinely uncertain, **delete** — a comment must earn its place. Only preserve a comment you're unsure about if losing it would drop concrete intent (a *why*, a reference, a warning) that cannot be reconstructed from the code.

### 4. Apply the changes

Use `Edit` to delete or rewrite each comment in place. Remove now-empty lines left behind by deletions, and keep surrounding indentation/formatting intact. Do not change any executable code — comments only.

### 5. Report

Summarize what changed, grouped by file:

- **Deleted** — `file:line` + the removed comment text (truncated), one per line.
- **Tightened** — `file:line` + `before` → `after`.
- **Kept as-is** — only note comments you deliberately left because they were already tight and useful (brief).

End with a one-line tally: N deleted, N tightened, across M files.

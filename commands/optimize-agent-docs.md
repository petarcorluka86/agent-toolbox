---
allowed-tools: Bash(bash *), Bash(git *), Read, Edit, Write, Grep, Glob
description: Audit and restructure the repo's AI-agent context files so agents get more useful guidance for fewer tokens
---

Scan every file in this repo that feeds an AI agent's context — `CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, `.cursorrules`, Copilot instructions, and the rest — and restructure them so an agent arrives **better informed and cheaper**. Audit first, apply only after the user approves.

The optimization target is **usefulness per eager token**, not file size. Cutting a doc an agent needed is a regression, even though it makes the numbers look better.

## The rules this command optimizes against

These are properties of how Claude Code actually loads context. Get them wrong and the "optimization" is fake.

- **Eager context is the budget.** Root `CLAUDE.md`, `CLAUDE.local.md`, and `.claude/rules/` files **without** `paths:` frontmatter load in full at launch, every session, relevant or not. That is the number worth shrinking. Anthropic's guidance: keep a `CLAUDE.md` **under ~200 lines** — longer files not only cost tokens, they *reduce adherence*, so an agent follows a bloated file less reliably than a tight one.
- **`@imports` do not save tokens.** A `@path/to/file.md` in a `CLAUDE.md` is expanded at launch (up to 4 hops deep). Splitting a 600-line `CLAUDE.md` into five imported files reorganizes it and saves **nothing**. Never propose imports as a token fix.
- **There are exactly three ways to make context lazy:**
  1. `CLAUDE.md` in a **subdirectory** — loads only when the agent reads a file in that directory.
  2. `.claude/rules/*.md` **with `paths:` frontmatter** (globs, e.g. `"src/api/**/*.ts"`, brace expansion supported) — loads only when the agent reads a matching file.
  3. **Skills** (`.claude/skills/*/SKILL.md`) — only the frontmatter `description` is held in context; the body loads on invocation. Skills also accept `paths:`.
- **Moving content from eager to lazy is the main lever.** Most of the win comes from relocating subsystem detail and multi-step procedures out of the always-loaded root file, not from deleting prose.
- **Claude Code does not read `AGENTS.md` natively — only `CLAUDE.md`.** This matters more than it sounds. A nested `AGENTS.md` is not lazy, it is **`manual`**: unlike a nested `CLAUDE.md`, *no file-read ever pulls it in*. It reaches an agent only if something explicitly points at it. A repo can hold tens of thousands of tokens of carefully-written `AGENTS.md` that no agent has ever loaded.

## Steps

### 1. Inventory

```bash
bash ~/RemoteConfig/agent-toolbox/commands/scripts/scan-agent-docs.sh
```

This prints every agent-context file with its estimated tokens, the `@import` graph, and — the column the whole audit turns on — how each file loads:

- **`eager`** — in context every session, relevant or not. `EST_TOKENS_EAGER` is the per-session bill and the number to shrink.
- **`lazy`** — auto-loaded on a match (a read inside that directory, or a `paths:` glob hit). Size matters far less here; this is where content wants to live.
- **`manual`** — reaches an agent *only* if something explicitly points at it or invokes it.

`est_tokens` is a bytes/4 approximation; use it to rank files and size the budget, never quote it as exact.

If it reports `FILES=0`, there is no agent documentation. Say so, offer to bootstrap a minimal root `CLAUDE.md` via `/init`, and stop.

`Read` every file it lists. They are small; read them in full rather than grepping — the audit depends on judging content, not locating it.

### 1b. Check the manual files are reachable at all

A large `EST_TOKENS_MANUAL` is a red flag, not a clean bill of health. For every `manual` file, establish **what would ever cause an agent to open it** — an `@import`, a link from an eager file, an explicit instruction, a skill that names it. Then:

- **Reachable** (an eager file points at it) — fine. This is the correct pattern for deep reference material.
- **Orphaned** (nothing points at it) — it is **dead documentation**. It has never shaped an agent's behavior, and it is rotting unread. This is the single most common failure in a mature repo, and it hides behind a healthy-looking token count.

Do not "fix" an orphan by deleting it on reflex — it is often good content that was simply wired up wrong. Prefer converting it into a mechanism that actually loads: a `paths:`-scoped rule, a nested `CLAUDE.md`, a skill, or a link from the canonical file. Delete only what is genuinely obsolete, and only with the user's say-so.

### 2. Verify against the repo, don't trust the docs

Agent docs rot silently, and a confidently wrong instruction is worse than a missing one — it sends the agent down a path that no longer exists. For every concrete claim, check it:

- **Commands** (`npm run build`, `pytest -q`, `make dev`) — confirm the script exists in `package.json` / `Makefile` / `pyproject.toml`.
- **Paths and files** referenced in prose — confirm with `Glob`/`Read` that they still exist.
- **Conventions** ("we use styled-components", "all state in Redux") — spot-check with `Grep` that the codebase still does that. A convention the code abandoned is a landmine.
- **Tools and versions** — confirm the dependency is still in the manifest.

Anything that fails verification is **stale**: fix it or cut it. Flag these first in the report — they are the highest-value findings, regardless of token count.

### 3. Audit each file

Classify every block of content into exactly one bucket:

**Cut** — costs tokens, returns nothing:
- Restates what the agent can read directly and cheaply: the file tree, the `package.json` scripts, the dependency list, obvious language/framework facts.
- Generic LLM boilerplate: "write clean code", "be helpful", "add tests", "follow best practices". The model already does this; these lines only dilute the rules that matter.
- Content duplicated in another agent file (the usual case: `CLAUDE.md`, `AGENTS.md`, and `.cursorrules` are three drifting copies of the same rules).
- Onboarding prose written for humans: history, rationale, marketing, "welcome to the repo".
- Stale content from step 2 with no current equivalent.

**Move** — useful, but wrongly billed to every session:
- Single-subsystem rules in the root file → `.claude/rules/<subsystem>.md` with `paths:` frontmatter scoping it to that subsystem's globs.
- Rules that only apply within one package/app → that directory's `CLAUDE.md`.
- Multi-step procedures (release flow, migration steps, deploy runbook) → a **skill**. Procedures are the single biggest source of dead weight in a root `CLAUDE.md`: long, rarely relevant, and read in full every session.
- Deep reference material (full API tables, schema dumps, exhaustive config lists) → an ordinary doc in `docs/`, *linked by path, not `@import`ed*, so the agent opens it only when it needs it.

**Keep and tighten** — genuinely belongs in eager context. This is the short list of things an agent must hold from turn one:
- How to build, test, lint, and run the project.
- Conventions the agent would otherwise violate, especially where the repo departs from the obvious default.
- Hard constraints and "always/never" rules — the things that cause real damage when broken.
- Project layout, only where it is non-obvious (a monorepo's package map earns its tokens; `src/ contains source` does not).

Rewrite what stays as **short imperative rules**, one per line. Cut hedging, preamble, and justification. An agent follows `Use PandaCSS; never add styled-components.` more reliably than a paragraph explaining the migration's history.

### 4. Find the gaps

The cheapest doc is one that prevents a wrong turn. Look for what is **missing**, using repo evidence rather than imagination:

- Non-obvious build/test invocations (an unusual test runner, a required env var, a mandatory codegen step before build).
- Conventions visible in the code but written down nowhere — an agent will break them by default.
- Traps: generated files that must not be hand-edited, directories that are vendored, commands that are destructive.

Propose additions only where you can point at the evidence in the repo. Do not invent rules.

### 5. Consolidate across tools

Pick **one source of truth** and reduce the rest to pointers, so the rules cannot drift apart again:

- Detect the convention the repo already uses and stay inside it. Do not migrate a working `CLAUDE.md` repo to `AGENTS.md` (or the reverse) unless the user asks — the churn buys nothing.
- If the repo has agent files for several tools with overlapping content, keep the canonical file and make the others point at it. Claude Code does **not** read `AGENTS.md` natively: if `AGENTS.md` is canonical, `CLAUDE.md` must either `@AGENTS.md`-import it or be a symlink to it. Say which you did.
- `CLAUDE.local.md` is personal and should be gitignored. If it is tracked, flag it.

### 6. Report, and wait

Present the plan **before touching anything**:

- **Stale / wrong** 🔴 — what the docs claim, what the repo actually does, per `file:line`. Lead with this.
- **Orphaned** 🔴 — `manual` files nothing points at: written, paid for, never loaded. State the token count sitting unread, and propose how to wire each one in (or retire it).
- **Cut** — what goes, and why it earns nothing.
- **Move** — from → to, with the mechanism (`paths:` rule / nested `CLAUDE.md` / skill / linked doc) and why that mechanism.
- **Keep** — the rules surviving into eager context, tightened.
- **Add** — proposed new rules, each with the repo evidence that justifies it.
- **Budget** — `EST_TOKENS_EAGER` before → projected after, plus how much `manual` content went from unreachable to actually loading. Note honestly that it's a bytes/4 estimate. Never claim a saving from an `@import` split.

Report the two numbers as what they are: eager tokens are a **cost** you are cutting, reachable-lazy tokens are **coverage** you are adding. A change that only shrinks eager tokens by deleting real guidance is a loss, and should be described as one.

Then **stop and wait for approval.** If the user wants to go finding-by-finding, `/iterate-items` picks up the list.

### 7. Apply, then verify

On approval, make the edits. Rules:

- **Move content; don't silently drop it.** Every line in the Cut bucket was either shown to the user in step 6 or is provably duplicated elsewhere. Nothing disappears unannounced.
- Preserve the user's voice and any project-specific rule you did not fully understand. **When unsure whether a rule is load-bearing, keep it** — a stray line costs a few tokens; deleting a real constraint costs a broken build.
- Leave non-agent docs alone: `README.md`, `CONTRIBUTING.md`, and anything written for humans are out of scope unless an agent file imports them.

Then re-run the scanner and report the real before/after:

```bash
bash ~/RemoteConfig/agent-toolbox/commands/scripts/scan-agent-docs.sh
git diff --stat
```

Close with the measured `EST_TOKENS_EAGER` before → after, the count of rules moved to lazy loading, and a one-line verdict. Remind the user the changes are staged in the working tree and reviewable with `git diff`.

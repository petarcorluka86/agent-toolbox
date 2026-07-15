---
allowed-tools: Bash(bash *), Bash(git *), Agent, Read, Grep, Glob
description: First-principles audit of the current branch against the repo's default branch
---

Compare the current branch to the repo's default branch and conduct a **First Principles** audit of all changes. Do not just look for bugs — question the entire approach.

## Steps

### 1. Gather diff context

First detect the default branch (don't assume `master`):

```bash
BASE="$(bash ~/RemoteConfig/agent-toolbox/commands/scripts/_default_branch.sh)"
```

Then run:

```bash
git fetch origin "$BASE" --quiet
git rev-parse --abbrev-ref HEAD
git log --oneline "origin/$BASE"..HEAD
git diff "origin/$BASE"...HEAD --stat
git diff "origin/$BASE"...HEAD --name-only
```

Then capture the full diff for review:

```bash
git diff "origin/$BASE"...HEAD
```

If there are no changes vs `origin/$BASE`, stop and tell the user.

### 2. Read project conventions

Use Glob to find `CLAUDE.md` files in directories touched by the diff (repo root + each affected app/package). Read them so the audit reflects local conventions (styling approach, i18n setup, import rules, testing requirements, etc.).

### 3. Parallel first-principles audit

Launch **5 parallel agents**, one per dimension. Each prompt must include:

- Current branch name and the full changed-files list
- Instructions to run `git diff origin/$BASE...HEAD -- <file>` (substitute the `$BASE` value detected in step 1) to read hunks, and `Read` for surrounding context
- The relevant CLAUDE.md excerpts so the agent applies the project's conventions
- An instruction to **question the approach, not just find bugs** — propose alternatives where the current design feels off

Each agent must report findings as:

- **File**: path:line (or "architecture-wide" when not tied to a single line)
- **Observation**: what was found
- **Challenge**: the first-principles question — is there a simpler/better way?
- **Recommendation**: concrete alternative
- **Confidence**: 0–100
- **Severity**: 🔴 critical challenge / 🟡 worth rethinking / 🟢 minor

**Shared rubric**: Read `~/RemoteConfig/agent-toolbox/commands/fragments/review-rubric.md` and copy its confidence table (with the >= 75 report threshold) and exclusion list into every agent prompt, extended with these branch-audit exclusions:

- Alternatives that are different but not demonstrably simpler, faster, or more consistent

Being told to challenge the approach is not license to invent challenges — a different approach that isn't clearly better is not a finding.

---

#### Agent 1 — DRY & Reuse

Hunt for duplicated logic, styles, or components introduced by this branch. Look for:

- Repeated business logic that could become a shared util/hook
- Repeated style blocks that should be tokens, recipes, or shared components in the repo's styling system
- New components that duplicate something already in the repo's design-system/UI packages (find them via the workspace layout) or an existing app component
- Copy-pasted handlers, fetchers, or selectors

For each finding, name the existing abstraction it should reuse (or the new abstraction worth extracting) and weigh the cost of extraction vs the duplication.

#### Agent 2 — Implementation simplicity & performance

Question whether each non-trivial change is the simplest implementation that works. Look for:

- Over-engineered abstractions (premature generalization, unused config, hypothetical extensibility)
- State that could be derived instead of stored; effects that could be replaced by render-time computation
- Manual implementations of things the framework/library already provides
- Performance traps: unstable refs, missing memoization where it matters, N+1 fetches, expensive work in the render path, heavy new dependencies

For each finding, sketch the simpler alternative and what would be removed.

#### Agent 3 — UX / UI critique

Critique the user flow of the new changes as far as the code shows it. You are reading code, not pixels — don't speculate about visual appearance. Look for:

- Missing or awkward states: loading, empty, error, disabled, skeleton
- Accessibility gaps visible in code: keyboard nav, focus management, ARIA roles/labels
- Flow friction visible in logic: extra confirmation steps, missing feedback after actions, surprising navigation
- New one-off components/markup where an existing pattern or shared component covers the case — name it

When possible, point to the existing pattern in the codebase that should have been followed.

#### Agent 4 — Clean code, naming & readability

Evaluate naming conventions, code style, and readability across the diff. Look for:

- Names that hide intent (`data`, `handle`, `tmp`, `Wrapper2`) or leak implementation detail
- Functions/components doing more than one thing — natural split points
- Inconsistent naming vs surrounding code (casing, prefixes, file naming)
- Comments that restate the code instead of explaining *why*, dead code, commented-out blocks
- Module boundaries: things imported across layers that shouldn't cross, files in the wrong place

Flag the worst readability offenders and propose specific renames/splits.

#### Agent 5 — Translations & i18n

Ensure no hardcoded user-facing strings and that i18n is used idiomatically. Look for:

- New literal strings in JSX, alt text, aria-labels, title attributes, toast/error messages
- Strings concatenated with variables instead of using interpolation/ICU placeholders
- Missing pluralization handling
- Translation keys that are unclear, duplicated, or inconsistent with existing naming
- Locale-sensitive formatting (dates, numbers, currencies) done manually instead of via the project's i18n utilities

Cite the i18n helper/hook used elsewhere in the touched area and recommend the correct usage.

### 4. Synthesize "Critical Challenges"

Aggregate findings from all 5 agents. Deduplicate. Then present the report in this exact shape:

#### Critical Challenges (rethink the architecture)

A short list (3–7 bullets max) of 🔴 items where the branch's overall approach is questionable. Each bullet: one sentence stating the challenge, one sentence proposing the alternative direction. These are the things worth pausing the branch for.

#### Worth Rethinking

🟡 items grouped by dimension (DRY, Implementation, UX/UI, Clean Code, Translations). Each entry references file:line and gives a concrete recommendation.

#### Minor

🟢 items as a compact bullet list — file:line + one-line note.

#### What's Good

A short paragraph naming things the branch got right (patterns followed, abstractions reused, tests added). Don't invent praise; if nothing stands out, omit this section.

End with a one-line verdict: **Ship it**, **Ship with fixes**, or **Rethink before continuing** — with the single biggest reason.

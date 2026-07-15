---
allowed-tools: Read, Grep, Glob, Bash(git *)
description: Explain a topic, file, or concept as if to a junior dev on their first day
---

Explain the given topic as if the reader is a junior developer on their first day at this job: smart and motivated, but with zero context about this codebase, its stack, or its conventions.

This overrides the global brevity rule for this response only — here, completeness and approachability win over word count. Still no filler: simple is not the same as padded.

## Inputs

- **Topic** (optional): $ARGUMENTS — the concept, file, function, error, or piece of code to explain. If empty, explain the most recent thing discussed in the conversation; if there is none, ask what to explain.

## How to explain

- **Assume no prior context.** Don't assume they know the repo layout, the domain, the team's conventions, or what happened in previous discussions.
- **Define every piece of jargon on first use** — including project-internal names (services, packages, acronyms) and stack terms a junior may not have met.
- **Ground it in this repo.** Point at the actual files, functions, and commands involved (`path/to/file.ts:42`), not abstract descriptions. If the topic is code, walk through it in reading order.
- **Explain the why, not just the what.** Why does this exist, what problem does it solve, what would break without it.
- **Use one concrete example or analogy** where the concept is abstract. Prefer a real example from the codebase over an invented one.
- **Show, step by step.** For processes (build, deploy, data flow, request lifecycle), number the steps and say what each one produces.
- **Name the traps.** The mistakes a newcomer would make here, and how to recognize them.

## Structure

1. **One-paragraph summary** — the whole answer in plain words, before any detail.
2. **The full walkthrough** — following the rules above.
3. **Where to look next** — 2–3 files or docs to read to go deeper, each with one line on why.

Do not quiz the reader or ask rhetorical questions. If the topic is genuinely large, explain the core well and list what was deliberately left out rather than covering everything shallowly.

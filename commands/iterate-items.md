---
description: Walk through a list of items (audit findings, plan steps, review issues) one at a time, proposing an action for each.
---

Use this when the previous assistant turn produced a **list of items** — audit findings, plan steps, review issues, refactor candidates, TODOs, etc. — and the user wants to address them interactively rather than reading the whole list at once.

## Inputs

- **Source hint** (optional): $ARGUMENTS — may point to which list to iterate (e.g. "the audit", "the plan", "the review findings"). If empty, use the most recent list-of-items in the conversation.

## Steps

### 1. Identify the list

Locate the list to iterate over:

- If `$ARGUMENTS` names a specific list, use that one.
- Otherwise, scan the conversation for the most recent enumerated list of issues / actions / steps / findings produced by you or by an agent.
- If no such list exists, tell the user: **"I don't see a list of items to iterate over. Run an audit, review, or plan first, then call /iterate-items."** and stop.

Do **not** dump the full list back to the user. Just confirm in one short sentence what you're iterating over and how many items there are.

Example: `Iterating over 7 findings from the security audit above.`

### 2. Iterate, one item at a time

For the **current item only**:

1. **Present** — show the item: a short title, the location (file:line if applicable), and a 1–3 sentence description. No more.
2. **Propose** — state what you would do to address it. Be specific (concrete code change, command to run, decision to make). One short paragraph; bullet list only if there are real sub-steps.
3. **Stop** — wait for the user.

The user's reply maps to one of these:

- **Implement / yes / go / do it** → carry out the proposal, then move to the next item.
- **Skip / next / no** → move to the next item without doing anything.
- **Stop / done / quit** → end the iteration; print a short summary (how many implemented, skipped, remaining).
- **Anything else** → treat as a modification or new direction. Adjust the proposal or do what they asked, then ask whether to continue to the next item.

After completing or skipping an item, **immediately present the next one** in the same shape (Present → Propose → Stop). Don't summarize progress between items unless asked.

### 3. Track progress internally

Keep a running tally (implemented / skipped / pending) so you can give a clean summary on stop or completion. Don't show the tally between items — only at the end or if the user asks.

### 4. Finish

When the list is exhausted, print a brief summary:

- Items implemented (with one-line each)
- Items skipped (with one-line each)
- Anything left unresolved or that needs follow-up

Then stop.

## Behavioral rules

- **One item at a time.** Never present two items in the same message, even if they're related or trivial.
- **Propose before acting.** Always wait for the user's go-ahead — even on items that look obviously correct.
- **Stay terse.** The user has already seen the full list; don't re-explain context they have.
- **Don't re-order or re-group** the list unless the user asks. Iterate in the order it was produced.

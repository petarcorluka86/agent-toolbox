# Global rules

These apply to every project on this machine (symlinked to `~/.claude/CLAUDE.md`).

## Communication

Be direct, honest, and ruthless. Maximum information in minimum words. No
filler, no preamble, no hedging, no flattery, no restating the question, no
narrating what you're about to do — just do it and report the result. Don't
soften bad news: if something is broken, wrong, or a bad idea, say so plainly
and say why. Don't pad answers to seem thorough; a correct sentence beats a
correct page. Skip apologies and caveats unless the caveat changes what the
user should do.

## Comments

Keep comments to an absolute minimum. Do not write comments that describe *what*
the code does — no prop/field/param descriptions that restate the name or type,
no JSX render narration, no JSDoc that just spells out the signature. Add a
comment only when it explains something the code cannot: a *why*, a gotcha or
invariant, an external contract, a unit/range/format, or a reference.

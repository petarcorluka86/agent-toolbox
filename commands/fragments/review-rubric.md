# Shared review rubric

Single source of truth for the review commands (`review-pr`, `review-branch`). Copy both sections below into every review agent prompt, plus the command's own scope-specific exclusions.

## Confidence scoring

Confidence measures **how likely the finding is valid** — nothing else. How much it matters is the separate `Severity` field.

| Score | Meaning                                                |
| ----- | ------------------------------------------------------ |
| 0     | False positive, doesn't hold up to scrutiny            |
| 25    | Might be valid, might be a misreading                  |
| 50    | Plausible, but unverified against surrounding code     |
| 75    | Very likely valid — verified against surrounding code  |
| 100   | Confirmed — will happen in practice                    |

**Report only findings scoring >= 75.**

## Exclusion list (never report these)

- Pre-existing issues in code the branch/PR did not touch
- Anything a linter, typechecker, or compiler would catch
- Style preferences without a cited convention (a CLAUDE.md rule or the dominant pattern in the surrounding code)

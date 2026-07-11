---
allowed-tools: Bash(source *), Bash(gh *), Bash(git *), Bash(curl *), Agent, Read, Grep, Glob
description: Review a PR where you are requested as a reviewer
---

Review a pull request where you are requested as a reviewer. Combines automated issue detection with historical context, security analysis, and standards compliance.

**Note**: All `<ANGLE_BRACKET>` values in agent prompts are placeholders — fill them in at runtime with actual values gathered in earlier steps.

## Inputs

- **PR number**: $ARGUMENTS (optional — the PR number to review)

## Steps

### 0. Load environment

The toolbox config lives at `~/RemoteConfig/agent-toolbox/commands/.env`. Prefix every subsequent bash command that needs config (`$GH_ORG`, `$GH_REPO`, `$GH_USERNAME`, `$YOUTRACK_URL`, `$YOUTRACK_TOKEN`, `$STAGING_DOMAIN`) with:

```bash
source ~/RemoteConfig/agent-toolbox/commands/.env &&
```

so the variables are available.

### 1. Find PRs to review

If `$ARGUMENTS` is empty, list PRs where the user is requested as a reviewer.

Use the GitHub GraphQL API:

```bash
gh api graphql -f query='
{
  repository(owner: "'"$GH_ORG"'", name: "'"$GH_REPO"'") {
    pullRequests(first: 100, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        number
        title
        createdAt
        additions
        deletions
        changedFiles
        author { login }
        reviewRequests(first: 20) {
          nodes {
            requestedReviewer { ... on User { login } }
            asCodeOwner
          }
        }
      }
    }
  }
}' --jq '[.data.repository.pullRequests.nodes[] | select(.reviewRequests.nodes | map(select(.requestedReviewer.login == "'"$GH_USERNAME"'")) | length > 0) | {number, title, author: .author.login, createdAt, additions, deletions, changedFiles, required: ([.reviewRequests.nodes[] | select(.requestedReviewer.login == "'"$GH_USERNAME"'") | .asCodeOwner] | any)}] | sort_by(if .required then 0 else 1 end, .createdAt) | .[]'
```

Display the results as a table sorted by:

1. **Required reviews first**, then optional
2. **Oldest first** within each group

Include a column showing the PR's age (e.g., "3 days", "< 1 day").

Make PR numbers clickable — format them as markdown links using the pattern `[#NUMBER](https://github.com/$GH_ORG/$GH_REPO/pull/NUMBER)` so the user can cmd+click to open in the browser. Do not use ANSI color codes.

If no PRs are found, tell the user: **"No PRs are currently waiting for your review."** and stop.

After showing the table, ask the user: **"Enter the PR number you'd like to review:"** and wait for their response.

### 2. Gather PR context

Run these in parallel:

```bash
# PR details
gh pr view $PR_NUMBER --json number,title,body,url,headRefName,baseRefName,author,additions,deletions,changedFiles,commits

# CI status
gh pr checks $PR_NUMBER

# Existing reviews
gh api repos/$GH_ORG/$GH_REPO/pulls/$PR_NUMBER/reviews --jq '.[] | {user: .user.login, state: .state, submittedAt: .submitted_at}'

# Existing inline comments
gh api "repos/$GH_ORG/$GH_REPO/pulls/$PR_NUMBER/comments?per_page=100" --jq '.[] | {user: .user.login, path: .path, line: .line, body: .body}'
```

Then:

- Read the PR description.
- Note **CI status**: if any checks are failing, flag this prominently at the top of the review.
- Note **existing reviews**: summarize who already reviewed, their verdict, and key points. Avoid duplicating their feedback later.
- **YouTrack and staging are optional.** Run `bash ~/RemoteConfig/agent-toolbox/commands/scripts/config-status.sh` — it prints `youtrack=on|off` and `staging=on|off`. Skip either bullet below when its integration is `off`; don't mention it in the review and don't warn about it.
- If `youtrack=on`: look for linked **YouTrack tickets** (e.g. `$YOUTRACK_URL/issue/ZETA-1234`). For each, fetch:
  ```bash
  curl -s "$YOUTRACK_URL/api/issues/<ISSUE_ID>?fields=summary,description" \
    -H "Authorization: Bearer $YOUTRACK_TOKEN"
  ```
- If `staging=on`: construct the **staging URL**: `https://<headRefName>.$STAGING_DOMAIN`

### 3. Gather code context

```bash
# Full diff
gh pr diff $PR_NUMBER

# Changed files list
gh pr diff $PR_NUMBER --name-only

# Commit log
gh pr view $PR_NUMBER --json commits --jq '.commits[] | "\(.oid[:8]) \(.messageHeadline)"'
```

Also:

- Use Glob + Read to find and read **CLAUDE.md files** in directories modified by the PR (root + app/package-level).
- Determine which **apps/packages** are affected by looking at file path prefixes (e.g. `apps/sofascore/`, `packages/design-system/`).

### 4. Summary & impact assessment

Present:

- **Purpose**: What is the goal? Derive from description, commits, ticket, and diff.
- **Scope**: Which apps/packages are affected? List key files/modules.
- **Changes**: Bulleted summary of what was done (developer-oriented, not line-by-line).
- **Staging**: `https://<branch>.$STAGING_DOMAIN` — omit this line entirely if `staging=off`.
- **CI status**: Pass/fail summary. If failing, list which checks.
- **Existing reviews**: Summary of previous feedback, if any.

**Size flag**: If the PR has >500 additions or >20 changed files, note the size and mention whether it might benefit from splitting. Don't block — just flag.

### 5. Parallel code review

Launch **5 parallel agents**. Each agent prompt must include:

- PR number, branch name, `$GH_ORG/$GH_REPO`
- The full changed-files list
- The .env path `~/RemoteConfig/agent-toolbox/commands/.env` (so it can `source` it) — pass this concrete path as `<ENV_PATH>`, don't leave it as a placeholder
- Instructions to fetch the diff itself via `gh pr diff <NUMBER>`
- The confidence rubric and false-positive exclusion list (copy them into each prompt)

---

**Confidence scoring** (include in every agent prompt):

| Score | Meaning                                                |
| ----- | ------------------------------------------------------ |
| 0     | False positive, doesn't hold up to scrutiny            |
| 25    | Might be real, might be false positive                 |
| 50    | Real but minor/nitpick                                 |
| 75    | Very likely real, important, will impact functionality |
| 100   | Confirmed real, will happen frequently                 |

**Report only issues scoring >= 75.**

**False-positive exclusion list** (include in every agent prompt):

- Pre-existing issues not introduced by this PR
- Things a linter, typechecker, or compiler would catch
- General code quality issues unless required by CLAUDE.md
- Issues on lines the author did not modify
- Intentional functionality changes aligned with the PR's purpose

---

#### Agent 1: Correctness & bug detection

```
You are reviewing PR #<NUMBER> ("<TITLE>") in <ORG>/<REPO> for correctness.
Branch: <BRANCH>. Changed files: <FILE_LIST>

To set up: source <ENV_PATH> && gh pr diff <NUMBER>

Focus areas:
- Logic errors: wrong conditions, off-by-one, inverted boolean checks
- Null/undefined safety: missing null checks, optional chaining gaps
- Race conditions: concurrent state updates, stale closures in React hooks
- Edge cases: empty arrays, missing object keys, boundary values
- Type mismatches: wrong prop types, incorrect generics
- State management: Redux action/reducer mismatches, missing saga handling
- React pitfalls: missing useEffect deps, incorrect key props, stale state in callbacks

For each potential issue, READ the surrounding code in the file (not just the diff hunk)
to verify whether the issue is real.

Report each issue as:
- **File**: path:line
- **Issue**: what's wrong
- **Evidence**: why this is real, not a false positive — cite the code
- **Confidence**: 0–100
- **Severity**: must-fix / should-fix / nit

<CONFIDENCE_RUBRIC>
<FALSE_POSITIVE_EXCLUSION_LIST>
```

#### Agent 2: Standards & conventions compliance

```
You are reviewing PR #<NUMBER> ("<TITLE>") in <ORG>/<REPO> for standards compliance.
Branch: <BRANCH>. Changed files: <FILE_LIST>

To set up: source <ENV_PATH> && gh pr diff <NUMBER>

First, read every CLAUDE.md file in directories touched by the PR (use Glob to find them —
start with the repo root CLAUDE.md, then check each affected app/package directory).
Also read code comments (TODOs, NOTEs, warnings, @see) in modified files.

Focus areas:
- CLAUDE.md violations: styling rules (PandaCSS vs Styled Components), import conventions,
  testing requirements, package manager rules
- New Styled Components usage where PandaCSS should be used
- Imports using `src/` prefix (should use module path directly)
- Code comment compliance: does the change violate guidance in existing inline comments?
- Naming conventions inconsistent with surrounding code

Report each issue as:
- **File**: path:line
- **Rule**: which CLAUDE.md rule or code comment is violated (quote it)
- **Issue**: what specifically is wrong
- **Confidence**: 0–100
- **Severity**: must-fix / should-fix / nit

<CONFIDENCE_RUBRIC>
<FALSE_POSITIVE_EXCLUSION_LIST>
```

#### Agent 3: Historical context

```
You are reviewing PR #<NUMBER> ("<TITLE>") in <ORG>/<REPO> using git history for context.
Branch: <BRANCH>. Changed files: <FILE_LIST>

To set up: source <ENV_PATH> && gh pr diff <NUMBER>

For each substantially modified file:
1. git log --oneline -10 <file>  — understand recent change history
2. git blame -L <modified_line_range> HEAD -- <file>  — who wrote the original code and when
3. Check if the original code was recently changed for a specific reason that this PR may be
   inadvertently undoing

Also search for related merged PRs:
- gh pr list --state merged --search "<keywords from changed files/functions>" --limit 5 --json number,title,body
- Read their descriptions for relevant context or warnings

Focus areas:
- Regressions: is this PR undoing a previous intentional fix?
- Repeated churn: has similar code been changed and reverted before?
- Missing context: was the original code written that way for a non-obvious reason
  (e.g., a workaround, a perf optimization, a browser quirk)?

Report each concern as:
- **File**: path:line
- **History**: what previous change existed and why (cite the commit)
- **Concern**: why the current change might be problematic in light of that history
- **Confidence**: 0–100
- **Severity**: must-fix / should-fix / nit

<CONFIDENCE_RUBRIC>
<FALSE_POSITIVE_EXCLUSION_LIST>
```

#### Agent 4: Security & performance

```
You are reviewing PR #<NUMBER> ("<TITLE>") in <ORG>/<REPO> for security and performance.
Branch: <BRANCH>. Changed files: <FILE_LIST>

To set up: source <ENV_PATH> && gh pr diff <NUMBER>

Security — focus on:
- XSS: dangerouslySetInnerHTML, unescaped user input rendered in DOM
- Injection: string interpolation in URLs, API calls, or query construction
- Sensitive data: tokens, keys, PII in client-side code or committed files
- Insecure requests: missing auth headers, HTTP instead of HTTPS
- Open redirects: unvalidated redirect URLs from user input

Performance — focus on:
- Unnecessary re-renders: missing React.memo, new object/array literals in JSX props,
  unstable references in useEffect/useMemo/useCallback deps
- Bundle impact: new heavy dependencies, imports that defeat tree-shaking
- N+1 fetching: loops making individual API calls
- Memory leaks: missing cleanup in useEffect, unremoved event listeners
- Expensive computation in render path without memoization

Report each issue as:
- **File**: path:line
- **Category**: security / performance
- **Issue**: what's wrong
- **Impact**: what could go wrong in production
- **Confidence**: 0–100
- **Severity**: must-fix / should-fix / nit

<CONFIDENCE_RUBRIC>
<FALSE_POSITIVE_EXCLUSION_LIST>
```

#### Agent 5: Test coverage & completeness

```
You are reviewing PR #<NUMBER> ("<TITLE>") in <ORG>/<REPO> for test coverage and completeness.
Branch: <BRANCH>. Changed files: <FILE_LIST>

To set up: source <ENV_PATH> && gh pr diff <NUMBER>

Test coverage:
- Do logic changes (new functions, modified conditionals, new components) have corresponding
  test additions or updates?
- Search for existing test files near modified sources: *.test.ts, *.test.tsx, __tests__/
- Are important edge cases covered?
- If no tests were added/changed for non-trivial logic, flag it.

Completeness:
- UI states: are loading, error, and empty states handled?
- API changes: are types/interfaces updated consistently across the boundary?
- Shared package changes: are all consuming apps updated? (check imports of changed exports)
- i18n: are there new hardcoded user-facing strings that should use translations?
- Accessibility: are new interactive elements keyboard-navigable with proper ARIA attributes?

Report each gap as:
- **File**: path (or "missing" if a test file should exist but doesn't)
- **Gap**: what's missing
- **Recommendation**: what should be added
- **Confidence**: 0–100
- **Severity**: must-fix / should-fix / nit

<CONFIDENCE_RUBRIC>
<FALSE_POSITIVE_EXCLUSION_LIST>
```

### 6. Present findings

Collect results from all 5 agents. Deduplicate overlapping findings (keep the higher-confidence version). Categorize confirmed issues as:

- 🔴 **Must fix** — bugs, security issues, regressions, or broken behavior
- 🟡 **Should fix** — performance, missing tests, or maintainability concerns
- 🟢 **Nit** — style, naming, or minor suggestions

Reference specific files and line numbers. If existing reviewers already raised a point, note it as "already flagged by @reviewer" rather than presenting it as new.

If the code looks good, say so — don't invent problems.

### 7. Verdict

End with a clear one-line verdict: **Approve**, **Approve with nits**, or **Request changes** (with a brief reason).

### 8. Submit review

Ask the user: **"Would you like me to submit this review on GitHub?"**

If yes, compose a review body from the findings formatted as clean markdown, then submit:

```bash
# Approve
gh pr review $PR_NUMBER --approve --body "<REVIEW_BODY>"

# Approve with nits (submit as comment, not formal approve, so author sees the nits)
gh pr review $PR_NUMBER --comment --body "<REVIEW_BODY>"

# Request changes
gh pr review $PR_NUMBER --request-changes --body "<REVIEW_BODY>"
```

Let the user adjust the verdict or edit the body before submission. After submitting, print the PR URL for confirmation.

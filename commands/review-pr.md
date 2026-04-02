---
allowed-tools: Bash(gh *), Bash(git *), Bash(curl *)
description: Review a PR where you are requested as a reviewer
---

Review a pull request where you are requested as a reviewer. Combines branch-level code review with automated issue detection.

## Inputs

- **PR number**: $ARGUMENTS (optional — the PR number to review)

## Steps

### 1. Find PRs to review

If `$ARGUMENTS` is empty, list PRs where the user is requested as a reviewer.

Use the GitHub GraphQL API to fetch PRs and determine whether the review is **required** (CODEOWNERS / branch protection) or **optional**:

```bash
gh api graphql -f query='
{
  repository(owner: "'"$GH_ORG"'", name: "'"$GH_REPO"'") {
    pullRequests(first: 100, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        number
        title
        createdAt
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
}' --jq '[.data.repository.pullRequests.nodes[] | select(.reviewRequests.nodes | map(select(.requestedReviewer.login == "'"$GH_USERNAME"'")) | length > 0) | {number, title, author: .author.login, createdAt, required: (.reviewRequests.nodes[] | select(.requestedReviewer.login == "'"$GH_USERNAME"'") | .asCodeOwner)}] | sort_by(if .required then 0 else 1 end, .createdAt) | .[]'
```

Display the results as a table sorted by:
1. **Required reviews first**, then optional
2. **Oldest first** within each group

Include a column showing the PR's age (e.g., "3 days", "< 1 day").

Make PR numbers clickable — format them as terminal hyperlinks using the pattern `[#NUMBER](https://github.com/$GH_ORG/$GH_REPO/pull/NUMBER)` so the user can cmd+click to open in the browser. Wrap PR numbers in **cyan** ANSI color codes (`\033[36m#NUMBER\033[0m`) so they stand out on dark backgrounds.

If no PRs are found, tell the user: **"No PRs are currently waiting for your review."** and stop.

After showing the table, ask the user: **"Enter the PR number you'd like to review:"** and wait for their response.

### 2. Get PR details

```bash
gh pr view $PR_NUMBER --json number,title,body,url,headRefName,author,additions,deletions,changedFiles
```

- Read the PR description.
- Look for any linked URLs — especially **YouTrack tickets** (e.g. `$YOUTRACK_URL/issue/ZETA-1234`).
- For each YouTrack ticket found, fetch its details:
  ```bash
  curl -s "$YOUTRACK_URL/api/issues/<ISSUE_ID>?fields=summary,description" \
    -H "Authorization: Bearer $YOUTRACK_TOKEN"
  ```
- Use the PR description and ticket context to understand the **motivation** and **expected behavior**.

### 3. Gather diff and context

```bash
gh pr diff $PR_NUMBER
gh pr diff $PR_NUMBER --name-only
```

Also gather relevant CLAUDE.md files from the directories modified in the PR.

### 4. Summary

Provide a concise summary:

- **Purpose**: What is the goal of this PR? Derive from description, commits, and diff.
- **Scope**: Which areas of the codebase are affected? List key files/modules.
- **Changes**: Bulleted list of what was done (developer-oriented, not line-by-line).

### 5. Code Review

Launch 5 parallel agents to independently review the change:

1. **CLAUDE.md compliance**: Audit changes against relevant CLAUDE.md files.
2. **Bug detection**: Shallow scan for obvious bugs. Focus on large bugs, avoid nitpicks and likely false positives.
3. **History context**: Read git blame/history of modified code to identify bugs in light of historical context.
4. **Previous PR comments**: Check previous PRs that touched these files for relevant comments.
5. **Code comment compliance**: Ensure changes comply with guidance in code comments.

For each issue found, score confidence (0-100):
- **0**: False positive, doesn't hold up to scrutiny
- **25**: Might be real, might be false positive
- **50**: Real but minor/nitpick
- **75**: Very likely real, important, will impact functionality
- **100**: Confirmed real, will happen frequently

**Filter out issues scoring below 80.**

Ignore these false positives:
- Pre-existing issues
- Things a linter/typechecker/compiler would catch
- General code quality issues unless required by CLAUDE.md
- Issues on lines the author did not modify
- Intentional functionality changes related to the PR's purpose

### 6. Present findings

Categorize confirmed issues as:

- 🔴 **Must fix** — bugs, security issues, or broken behavior
- 🟡 **Should fix** — code quality, performance, or maintainability concerns
- 🟢 **Nit** — style, naming, or minor suggestions

Reference specific files and code for each issue. If the code looks good, say so — don't invent problems.

### 7. Verdict

End with a one-line verdict: **Approve**, **Approve with nits**, or **Request changes** (with a brief reason).

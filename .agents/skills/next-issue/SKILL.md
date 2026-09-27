---
name: next-issue
description: Lists the top 10 open GitHub issues in bend-kit that are ready to pick up, sorted by priority. A ready issue is a leaf with no open sub-issues, no open blockers, and no open blockers on any ancestor. After the user picks one, the agent implements it in a git worktree. Use when the user asks "what's next", "what can I pick up", "next issue", "ready issues", "unblocked issues", or "top issues".
---

# Next Issue

## Important

- Run the script. Do not rebuild the query by hand. It is one GraphQL call.
- Priority is the `pri-*` label: `pri-high` first, then `pri-med`, then `pri-low`, then none. Ties go to the lower issue number. Give every new issue one of these labels.
- Do not start work until the user picks an issue. Then the first action is to add the `in-progress` label.

## Instructions

### Step 1: List ready issues

Run `.agents/skills/next-issue/scripts/ready.sh` from the repo root. Pass a number to change the count (default 10).

Each output line has tab-separated fields: `#number`, `priority` (`high`, `med`, `low`, or `-`), `assignees`, `title`, `url`. The script drops an issue when:
- it has the `in-progress` label,
- it has an open sub-issue (it is not a leaf), or
- it, or any ancestor up to 4 levels, is blocked by an open issue.

### Step 2: Present the list

Show a numbered table with the columns number, priority, title, and assignee. Mark assigned issues, because someone may already be working on them. Then ask the user which issue to work on.

### Step 3: Set up the worktree

When the user picks an issue:
1. Mark it first, before any other step: `gh issue edit <number> --add-label in-progress`.
2. Read `skill://ce-worktree` and follow it. Name the branch `issue-<number>-<short-slug>`.
3. Read the issue: `gh issue view <number> --comments`. Also read its parent issue, if it has one, for context.

### Step 4: Do the work

- Follow the repo AGENTS.md. Run `bend guide` before you write Bend code.
- Run the checks from `.github/workflows/ci.yml` for each package you touched: `bend PROOF.bend` and `bend check.bend`.

### Step 5: Always open a PR

Every run ends with a PR, even when the work is not complete. Read `skill://ce-commit-push-pr` and follow it. Leave the `in-progress` label on while the PR is open.

Link the issue with a GitHub keyword in the PR body:
- Work complete: `Closes #<number>`. Merging the PR closes the issue.
- Work not complete: open a draft PR (`gh pr create --draft`) and write `Refs #<number>`. The issue stays open. List what is done and what is left.
- Add `Refs #<n>` for any other issue the PR touches, such as the parent.

## Examples

### Example 1
User says: "what can I pick up next?"
Actions:
1. Run `ready.sh`. The output shows `#20 high`, `#21 high`, `#24 high`, `#31 med`, and more.
2. Show the table and ask which issue to work on.
3. The user says "21". Create the worktree `issue-21-integer-types`, read #21, and implement it.

## Common Issues

### `INSUFFICIENT_SCOPES` for `read:project`
**Cause:** The query asked for Projects v2 fields.
**Solution:** Priority comes from labels, not Projects. Keep the query free of `projectItems`.

### An issue you expected is missing
**Cause:** It has an open sub-issue, or an ancestor is blocked. Blockers can sit higher in the hierarchy.
**Solution:** Run `gh issue view <n>`, then check the issue's parent chain and the "Blocked by" list of each issue in that chain.

### More than 100 open issues or deeper hierarchies
**Cause:** The script reads only the first 100 open issues and 4 ancestor levels.
**Solution:** Add pagination, or add more `parent` levels to the query.

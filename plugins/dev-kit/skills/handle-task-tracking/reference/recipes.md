# Recipes — issue template, labels, and commands

Copy-paste material for `handle-task-tracking`. Prefer the **GitHub MCP** forms when the
server is connected; the **`gh` CLI** forms are the portable, human-runnable fallback.

## Issue-body template

Paste into a new issue's body and fill in. Drop sections that genuinely don't apply rather
than leaving them empty.

```markdown
## Problem / goal
<what's wrong or what outcome we want — one or two sentences>

## Context
<links, error output, repro steps, the file/area involved — enough to act without
re-discovery>

## Acceptance criteria
- [ ] <observable condition that proves it's done>
- [ ] <a second, if needed — keep these concrete and verifiable>

## Out of scope
<what this issue deliberately does NOT cover, so it doesn't sprawl>

## Notes
Blocked by #_  ·  Related to #_
```

For a **parent / tracking issue** that owns sub-issues, replace "Acceptance criteria" with
the shared definition of done and let the sub-issues carry the individual deliverables.

## Label taxonomy

Three orthogonal axes. Keep each set small — labels nobody maintains are noise.

| Axis | Labels | Rule |
| --- | --- | --- |
| **status** | `status:triage` `status:ready` `status:in-progress` `status:in-review` `status:blocked` | Exactly one of the first four at a time; `status:blocked` is an orthogonal flag layered on top. |
| **type** | `type:bug` `type:feature` `type:chore` `type:docs` | One per issue. Mirrors the commit type. |
| **priority** | `priority:high` `priority:medium` `priority:low` | One per issue. Drives "what's next" from `status:ready`. |

Optionally add an **area** axis (`area:ci`, `area:docs`, `area:<plugin>`) when a repo is big
enough that filtering by component helps.

### Create the label set once per repo

```bash
# status
gh label create "status:triage"      -c "#cccccc" -d "Needs triage"        --force
gh label create "status:ready"       -c "#0e8a16" -d "Ready to start"      --force
gh label create "status:in-progress" -c "#fbca04" -d "Being worked"        --force
gh label create "status:in-review"   -c "#1d76db" -d "In review"           --force
gh label create "status:blocked"     -c "#b60205" -d "Blocked"             --force
# type
gh label create "type:bug"     -c "#d73a4a" --force
gh label create "type:feature" -c "#a2eeef" --force
gh label create "type:chore"   -c "#ededed" --force
gh label create "type:docs"    -c "#0075ca" --force
# priority
gh label create "priority:high"   -c "#b60205" --force
gh label create "priority:medium" -c "#fbca04" --force
gh label create "priority:low"    -c "#c5def5" --force
```

## Capture

**MCP:** `mcp__github__issue_write` (`method: "create"`) with `owner`, `repo`, `title`,
`body`, `labels`, optional `assignees`, `milestone`. Read `mcp__github__list_issue_types`
first if the repo uses GitHub issue *types*.

**gh:**

```bash
gh issue create \
  --title "Login rejects valid 2FA codes after token refresh" \
  --body-file issue.md \
  --label "type:bug,priority:high,status:triage" \
  --assignee @me
```

## Decompose into sub-issues

**MCP:** create the child issues with `mcp__github__issue_write`, then attach each to the
parent with `mcp__github__sub_issue_write` (`method: "add"`). The parent is `issue_number`,
but `sub_issue_id` is the child's **database ID — not its issue number** (read it with
`mcp__github__issue_read`). Native sub-issues give the parent a real progress count.

**gh:** sub-issues are a GraphQL feature; plain `gh issue` doesn't cover them. Create the
children normally, resolve each issue *number* to its node ID, then link via the API:

```bash
# resolve node IDs from issue numbers (the hard part of the gh fallback)
PARENT_NODE_ID=$(gh issue view <parent#> --json id -q .id)
CHILD_NODE_ID=$(gh issue view <child#> --json id -q .id)

gh api graphql -f query='
  mutation($parent:ID!,$child:ID!){
    addSubIssue(input:{issueId:$parent, subIssueId:$child}){ issue { number } }
  }' -f parent="$PARENT_NODE_ID" -f child="$CHILD_NODE_ID"
```

When sub-issues are more friction than they're worth (trivial same-PR steps), use a task
list in the body instead: `- [ ] step`.

## Triage & track

```bash
# the triage queue
gh issue list --label "status:triage"

# what's next: ready work, highest priority first
gh issue list --label "status:ready" --label "priority:high" --state open

# advance status (swap the label) and self-assign when starting
gh issue edit 42 --remove-label "status:ready" --add-label "status:in-progress"
gh issue edit 42 --add-assignee @me

# keep the durable log current
gh issue comment 42 --body "Root cause: token refresh drops the TOTP window. Fixing in the refresh path."
```

**MCP:** `mcp__github__list_issues` (filter by `labels`/`state`),
`mcp__github__issue_write` (`method: "update"`) to swap labels / set assignee,
`mcp__github__add_issue_comment` for the log. **Caveat:** `issue_write`'s `labels`
*replaces the entire label set* (unlike gh's surgical `--add-label`/`--remove-label`), so
pass the complete desired set — status **plus** the existing `type:`/`priority:` labels —
or the others get stripped.

## Link work to issues

- Branch name: `<type>/<issue#>-<slug>` (e.g. `fix/42-2fa-token-refresh`).
- PR body: `Closes #42` (or `Fixes #42`) to auto-close on merge; `Refs #42` to link only.
- Relationships in the issue body: `Blocked by #41`, `Related to #38`.

## Close deliberately

```bash
# closing with a resolution (preferred when not closed by a merged PR)
gh issue close 42 --comment "Fixed in #57 — refresh now preserves the TOTP window. Verified with the 2FA integration test."

# won't-do, with the reason
gh issue close 99 --reason "not planned" --comment "Superseded by the new auth flow in #80."
```

**MCP:** `mcp__github__issue_write` (`method: "update"`, `state: "closed"`, optional
`state_reason` — one of `completed` / `not_planned` / `duplicate`) after an
`add_issue_comment` carrying the resolution.

## Projects (optional)

Only when a board, cross-repo view, or custom fields earn their keep. Add items with
`gh project item-add <number> --owner <owner> --url <issue-url>`, or the Projects MCP/GraphQL
calls. Keep the status *label* authoritative so nothing breaks when the board isn't present.

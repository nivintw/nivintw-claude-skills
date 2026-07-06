---
title: dev-kit handle-task-tracking
---

# handle-task-tracking

GitHub issues as the **durable task ledger** — the single source of truth for work that
outlives any one session, branch, or person. State lives in GitHub, not in a head or a chat
scrollback, so work survives context loss and hand-offs.

## Usage

```text
/dev-kit:handle-task-tracking
```

Natural-language forms work too: *"open an issue for this"*, *"file a bug"*, *"triage the
issues"*, *"break this into sub-issues"*, *"link this PR to an issue"*, *"close out this
issue"*.

## What it does

One loop, applied wherever the work is: **capture → decompose → triage → link → close.**

1. **Capture** — one outcome-shaped issue per shippable result, written so anyone can pick
   it up cold: problem, context, acceptance criteria, out-of-scope.
2. **Decompose** — native GitHub sub-issues for anything multi-step; each is a real issue
   with its own status, assignee, and PR, so the parent shows real progress.
3. **Triage** — a small status-label set that works in any repo with zero setup:
   `status:triage` → `status:ready` → `status:in-progress` → `status:in-review`, with
   `status:blocked` as an orthogonal flag (Projects boards are an optional view on top).
4. **Link** — branch from the issue, flip to `status:in-review` when the PR opens, and put
   `Closes #N` in the PR body so the merge closes the issue.
5. **Close** — deliberately, with a one-line resolution (what changed and the PR that did
   it), clearing the progression label; never silently close to clear the count.

Prefers the GitHub MCP tools (sub-issues are first-class calls there), falling back to the
`gh` CLI when the MCP server isn't connected.

## When to reach for it

The bar for tracking is *"would future-me or a teammate want a record of this?"* — track
outcomes worth remembering, and do the five-minute task instead of filing it. It also files
cross-repo: follow-up that really belongs to an upstream template or sibling project goes in
THAT repo, not the cwd's. Ceremony scales to the team — solo is the default (self-assign,
triage lightly), but the same workflow grows into a team without rework.

!!! note "`Closes #N` can silently not fire"
    The keyword only closes the issue when the merge reaches the default branch with it
    intact — a squash that drops it, a typo'd reference, or an epic with no direct PR leaves
    the issue open and stuck in `status:in-review`. Verify the close; when it didn't happen,
    close by hand with the resolution and clear the label.

## Related

- [`open-work`](open-work.md) — consumes the status labels this skill maintains to rank
  what to pick up next.
- [`ship`](ship.md) — delivers the change that closes the issue; it delegates all tracking
  here across the lifecycle.
- [`land`](land.md) — verifies the tracking issue actually closed after the merge, per this
  skill's close rules.

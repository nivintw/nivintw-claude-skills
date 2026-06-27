---
name: open-work
description: >-
  This skill should be used when the user asks "what should I work on next", "what should I
  pick up next", "what's next", "pick my next task", "rank my issues", "triage my backlog
  into a shortlist", or otherwise wants a recommendation of which open work to start. It
  reads the repo's open GitHub issues (the durable task ledger) and returns a short, ranked
  "pick up next" shortlist with a one-line rationale per item — not a full dump — ranking
  status:ready work by priority, readiness, staleness, and dependencies, surfacing blocked
  items, and flagging an untriaged pile. It selects from the ledger but neither grooms it
  (that's /dev-kit:handle-task-tracking, whose status-label model it reuses) nor does the
  work (that's /dev-kit:ship). Prefer the GitHub MCP tools, falling back to the gh CLI.
---

# open-work

Answer **"what should I pick up next?"** by reading the repo's open GitHub issues and
returning a **ranked, reasoned shortlist** — not the user eyeballing the whole issue list.
The output is a few recommended items, each with a one-line *why this one*, plus a short
footer of what needs attention before it's pickable.

This is the **select** verb in the dev-kit loop:

- **groom** — `/dev-kit:handle-task-tracking` keeps the ledger healthy (capture, triage,
  decompose, link, close).
- **select** — open-work (this) reads the ledger and recommends what to start.
- **execute** — `/dev-kit:ship` takes the chosen item from idea to a review-ready PR.

open-work **reuses, never redefines**, the status-label model. `handle-task-tracking` is the
single source of truth for the labels; open-work only *consumes* them to rank.

## What this is not

- **Not grooming.** Creating, triaging, decomposing, relabeling, or closing issues is
  `/dev-kit:handle-task-tracking`. open-work reads; it doesn't mutate the ledger.
- **Not doing the work.** Executing the chosen item end to end is `/dev-kit:ship`.
- **Single-repo.** Cross-repo aggregation is out of scope (possible later).

## Gather — read the ledger

Pull all **open** issues with enough signal to rank: status / priority / type labels,
`updated_at` (staleness), assignee, dependency links in the body (`Blocked by` / `Related
to` references), and parent/sub-issue links. Prefer the GitHub MCP tools; fall back to `gh`
(see Tooling). Read the issue *bodies* for the candidates you're about to recommend — a
rationale needs more than a title.

## Rank — priority × readiness × staleness × dependencies

Rank using `handle-task-tracking`'s model, in this order:

- **Readiness gate (first).** Only `status:ready` is recommendable to *start*. Partition the
  rest rather than ranking them in:
  - `status:triage` — not yet rankable; these are the **untriaged pile** (flag the count).
  - `status:in-progress` — already being worked; surface only if it looks stalled (stale
    `updated_at`, no assignee), don't recommend starting fresh.
  - `status:in-review` — awaiting review, effectively in-flight; exclude from "start next".
  - `status:blocked` — exclude from the shortlist; surface separately with its blocker.
- **Priority (primary sort)** among ready items: `priority:high` > `medium` > `low` >
  unlabeled.
- **Dependencies.** An issue still blocked by an open dependency is **not** ready regardless
  of its label — treat it as blocked. An issue that *unblocks* others (a blocker for several)
  earns a bump up.
- **Staleness (tie-breaker).** Among equal priority, surface long-sitting `ready` items first
  (older `updated_at`) so they don't rot — but call it out when age signals the issue itself
  may be going stale and want a re-triage.
- **Effort, light touch.** A quick `ready` win can jump the queue when it clears a path for
  other work; don't let size override priority otherwise.

## When the ledger isn't labeled (degraded mode)

Many repos haven't set up the status / priority taxonomy — issues may carry only a `type` or
a bare `enhancement` label. **Don't fail.** Flag the gap, recommend
`/dev-kit:handle-task-tracking` to establish the labels (its
[`reference/recipes.md`](../handle-task-tracking/reference/recipes.md) has the one-time
`gh label create` block), then rank on whatever signal exists: any explicit priority in the
body, type, how **actionable** the issue is (clear acceptance criteria reads as more ready
than a vague stub), and recency / staleness. Say plainly that the ranking is best-effort
until the labels exist.

## Output — a short, reasoned shortlist (not a dump)

- Lead with a **ranked shortlist** of ~3 (up to ~5) recommendable items. For each, give the
  issue number and title and a **one-line rationale** that ties the signals together (e.g.
  "highest priority, ready, and unblocks the API work").
- Then, briefly and separately: the **untriaged count** (needs `handle-task-tracking`), any
  **blocked** items with their blockers, and anything **in-progress that looks stalled**.
- If there are many more ready items than shown, **say so and show the top slice** — never
  silently truncate, and never dump the full list.
- End with the **next action**: name the single top pick and offer to start it with
  `/dev-kit:ship`, which branches, implements, and links the issue with a closing reference.

## Tooling — MCP first, gh as fallback

Prefer the **GitHub MCP tools**: `mcp__github__list_issues` (filter `state: OPEN`, read
`labels`) and `mcp__github__issue_read` for a candidate's body, comments, labels, and
sub-issues. Fall back to the **`gh` CLI** when the MCP server isn't connected — check first,
since it can be absent in headless or cron runs — or when a human wants a command to paste.
The label and query command forms live in `handle-task-tracking`'s
[`reference/recipes.md`](../handle-task-tracking/reference/recipes.md) (e.g. `gh issue list
--label "status:ready" --label "priority:high" --state open`) — reuse them rather than
duplicating.

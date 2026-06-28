---
name: open-work
description: >-
  This skill should be used when the user asks "what should I work on next", "what should I
  pick up next", "what's next in the backlog", "pick my next task", "rank my issues",
  "shortlist my ready work", "what's in progress", "what am I in the middle of", or otherwise
  wants a recommendation of which open work to start or resume. It reads the repo's open
  GitHub issues (the durable task ledger) and returns a short, ranked "pick up next" shortlist
  with a one-line rationale per item — not a full dump. It leads by calling out your
  in-progress work to resume (usually, finish what you started first), then
  ranks status:ready work by priority, staleness, and dependencies, surfaces blocked items,
  and flags an untriaged pile. It selects from the ledger but neither grooms it
  (that's /dev-kit:handle-task-tracking, whose status-label model it reuses) nor does the
  work (that's /dev-kit:ship). Prefer the GitHub MCP tools, falling back to the gh CLI.
---

# open-work

Answer **"what should I pick up next?"** by reading the repo's open GitHub issues and
returning a **ranked, reasoned shortlist** — not the user eyeballing the whole issue list.
The output **leads with your in-progress work to resume** — usually you finish what you
started before starting something new — then a few recommended items to start, each with a
one-line *why this one*, plus a short footer of what needs attention before it's pickable.

This is the **select** verb in the dev-kit loop:

- **groom** — `/dev-kit:handle-task-tracking` keeps the ledger healthy (capture, triage,
  decompose, link, close).
- **select** — open-work (this) reads the ledger and recommends what to resume or start.
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
rationale needs more than a title. For `status:in-progress` / `status:in-review` candidates,
also check the **linked PR's state** — a *merged* PR on a still-open issue means the work is
done and the label is stale (needs closing), not in flight.

## Rank — readiness gate, then priority × staleness × dependencies

Rank using `handle-task-tracking`'s model, in this order:

- **Readiness gate (first).** Only `status:ready` is recommendable to *start*. Partition the
  rest rather than ranking them in:
  - `status:triage` — not yet rankable; these are the **untriaged pile** (flag the count).
  - `status:in-progress` — already in flight; not recommendable to *start* fresh, but
    **always surface it** — not only stalled ones (the Output leads with it, splitting *your*
    work to resume from items in flight by someone else, capping a large pile, and flagging
    stalled ones).
  - `status:in-review` — awaiting review, effectively in-flight; exclude from "start next".
  - `status:blocked` — exclude from the shortlist; surface separately with its blocker.
  - **Done-but-open (either `status:in-*`).** If an in-progress *or* in-review issue's
    **linked PR has already merged**, it's *done, not in flight* — the label is stale;
    surface it separately as **needs closing** (point at `/dev-kit:handle-task-tracking` to
    close it and clear the label), never as resumable or in-review work.
- **Ownership.** A `status:ready` issue already assigned to someone else isn't yours to
  start — exclude it from the shortlist (or surface it separately); prefer unassigned or
  self-assigned ready work.
- **Priority (primary sort)** among ready items: `priority:high` > `priority:medium` >
  `priority:low` > unlabeled.
- **Dependencies.** An issue still blocked by an open dependency is **not** ready regardless
  of its label — resolve its `Blocked by` reference and confirm that blocker is still open,
  then treat it as blocked. An issue that *unblocks* others (a blocker for several) earns a
  bump up.
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

To still **lead with in-progress** here: without a `status:in-progress` label, detect
in-flight work by proxy — an issue that's **assigned and has a linked branch or an open PR
referencing it** — and lead with that, flagged best-effort.

## Output — in-progress first, then a short, reasoned shortlist (not a dump)

- **Lead with in-progress work, whenever any exists.** Before recommending anything new, call
  out the `status:in-progress` issues under a short "In progress — resume these first"
  heading: issue number, title, assignee, and how long since it was touched. Put **your own**
  (unassigned or self-assigned) first — that's the work to *resume* — and list any **assigned
  to someone else** separately, as in flight by them and *not* yours to pick up. **Flag
  stalled ones** (long-stale `updated_at`, and/or unassigned) as needing attention — they may
  be stuck or abandoned. If there are many in-progress items, that pile is itself the signal
  (too much WIP): show a top slice with the total count rather than enumerating every one. The
  framing is *usually finish what you started before starting something new*. If nothing is in
  progress, say so in one line and move on — don't manufacture a section.
- Then a **ranked shortlist** of ~3 (up to ~5) recommendable items **to start**. For each,
  give the issue number and title and a **one-line rationale** that ties the signals together
  (e.g. "highest priority, ready, and unblocks the API work").
- Then, briefly and separately: the **untriaged count** (needs `handle-task-tracking`), any
  **blocked** items with their blockers, and any **done-but-open** issues (linked PR merged
  but the issue is still open / still labeled `status:in-*`) that just need closing via
  `handle-task-tracking`.
- If there are many more ready (or in-progress) items than shown, **say so and show the top
  slice** — never silently truncate, and never dump the full list.
- End with the **next action**: point at the single best next move. If one of **your**
  in-progress items stands out, that's **resume it** — check out its existing branch or open
  its linked PR and keep going (a hand-back to you; `/dev-kit:ship` *starts* fresh work, it
  doesn't resume an in-flight branch). Otherwise **start** the top ready pick with
  `/dev-kit:ship` (it branches, implements, and links the issue with a closing reference).

## Tooling — MCP first, gh as fallback

Prefer the **GitHub MCP tools**: `mcp__github__list_issues` (filter `state: OPEN`, read
`labels`) and `mcp__github__issue_read` for a candidate's body, comments, labels, and
sub-issues. For **done-but-open** / degraded-mode in-flight detection, resolve a candidate's
linked PR and its merge state: find the PR that references the issue
(`mcp__github__search_pull_requests`, or `gh pr list --search "<issue#>" --state all`) and
read its `state` / `mergedAt` (`mcp__github__pull_request_read`, or
`gh pr view <pr#> --json state,mergedAt`); the `issue_read` timeline also surfaces a
linked/closing PR. Fall back to the **`gh` CLI** when the MCP server isn't connected — check
first, since it can be absent in headless or cron runs — or when a human wants a command to paste.
The label and query command forms live in `handle-task-tracking`'s
[`reference/recipes.md`](../handle-task-tracking/reference/recipes.md) (e.g. `gh issue list
--label "status:ready" --label "priority:high" --state open`) — reuse them rather than
duplicating.

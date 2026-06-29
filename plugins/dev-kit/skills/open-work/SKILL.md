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

## Output — a fixed presentation contract

The output is a **contract**, not a freeform summary: the same five parts, always in this
order, every run. Ranking (above) decides *what* appears; this section fixes *how* it's
presented, so two runs against the same ledger read the same way. **Fill the skeleton — don't
reinvent it.** The point is that you can recognize an open-work report at a glance and never
have to re-learn its shape.

### The skeleton

```markdown
`<owner>/<repo>` — <N> open · <R> ready · <P> in progress · <U> untriaged

## Resume in progress
<your resumable work as a table, then others' in-flight work as a separate table>

## Start next
<ranked shortlist as a signal table; one-line rationale per item beneath the table>

## Needs attention
<untriaged count; blocked table; done-but-open table>

## Next action
<the single best move, one short paragraph>
```

1. **Tally line first.** One line naming the repo and the four counts — `open · ready · in
   progress · untriaged`, always all four even when a count is zero. These are **headline
   figures, not a partition**: `open` is the grand total, and `ready` / `in progress` /
   `untriaged` are overlapping highlights that need not sum to it (blocked and done-but-open
   items are open but counted in none of them). It is the *only* place the overall result is
   summarized, so the headings never editorialize the outcome (no "Nothing's queued" or "the
   ledger is empty" headings — the headings are always the four fixed ones).
2. **`## Resume in progress`** — lead here whenever any in-flight work exists; usually you
   finish what you started before starting something new. Both `status:in-progress` and
   `status:in-review` (PR open, not yet merged) count as in flight and belong here, told apart
   by the `Status` cell. Put **your own** (unassigned or self-assigned) work first, under a
   **`Yours to resume:`** table — that's the work to *resume* — then any work **assigned to
   someone else** in a separate table, labeled as in flight by them and *not* yours to pick
   up. **Flag stalled rows** by appending `⚠️ stale` to the `Updated` cell (long-stale
   `updated_at` and/or unassigned) — they may be stuck or abandoned. If the in-flight pile is
   large, that is itself the signal (too much WIP): show a top slice and state the total rather
   than listing every row. The `Yours to resume:` table uses columns `Issue | Status |
   Updated`; the others' table inserts an `Assignee` column (`Issue | Assignee | Status |
   Updated`).
3. **`## Start next`** — the ranked shortlist of ~3 (up to ~5) `status:ready` items to start,
   as a **signal table** with columns `# | Issue | Pri | Assignee | Updated` (every row here is
   `status:ready` by definition, so a `Status` column would be constant and is omitted). The
   **one-line rationale per item goes in prose lines beneath the table**, never inside a table
   cell — a sentence wrapped into a cell is exactly the mess this contract exists to avoid.
4. **`## Needs attention`** — the **untriaged count** (a bare number with the
   `/dev-kit:handle-task-tracking` pointer), then **blocked** items as a table with columns
   `Issue | Pri | Blocked by | Updated` (the `Blocked by` cell lists every open blocker), then
   **done-but-open** items as a table with columns `Issue | Merged PR | Updated` (linked PR
   merged but the issue is still open / still labeled `status:in-*`; these just need closing
   via `/dev-kit:handle-task-tracking`). Place a done-but-open issue **only here** — never under
   Resume, and never in the `in progress` count — even though its `status:in-*` label is stale.
5. **`## Next action`** — one short paragraph naming the single best move. If one of **your**
   in-progress items stands out, that's **resume it** — check out its existing branch or open
   its linked PR and keep going (`/dev-kit:ship` *starts* fresh work; it does not resume an
   in-flight branch). Otherwise **start** the top ready pick with `/dev-kit:ship` (it branches,
   implements, and links the issue with a closing reference).

### Rules

- **Every ticket list is a table** — Resume, Start, blocked, and done-but-open. The untriaged
  pile stays a **bare count**, never a table (it's a number, not a list to scan).
- **Empty sections collapse; they don't vanish.** `## Resume in progress` and `## Start next`
  always render their heading; when empty, a single line replaces the table — stem `Nothing in
  flight — no in-progress or in-review issues, no open PRs.` / `Nothing ready — no ready
  items.`, optionally followed by a short reason in parentheses (e.g. *all closed* vs. *an
  unlabeled ledger*). The Start stem reports the **ready** count, never the open count — open
  work can exist with nothing ready. `## Needs attention` collapses to a single line (`None —
  nothing untriaged, blocked, or done-but-open.`) **only** when untriaged is `0` *and* both the
  blocked and done-but-open buckets are empty. Otherwise the section is expanded: the
  **untriaged** line shows its count (`0` and up), and the **blocked** and **done-but-open**
  buckets each render as their table when populated or `none` when empty. Never improvise a
  bespoke empty-state shape, and never drop a heading to "tidy up" a clean ledger.
- **Degraded mode keeps the skeleton.** When the ledger isn't labeled (see *When the ledger
  isn't labeled*), render the same five parts; add a one-line best-effort banner on its own
  line between the tally and `## Resume in progress`, and show `—` in the `Pri` and `Status`
  cells of any table that has them. The table never breaks.
- **Issue references are always typed markdown links** — e.g.
  `[#23](https://github.com/<owner>/<repo>/issues/23)` — so they're clickable in the terminal.
- **Never silently truncate.** When there are more ready or in-progress items than shown, say
  so and show the top slice — never dump the full list, never hide the remainder.
- **Emoji are fine** where they arise naturally; they're neither required nor banned.

### Worked example — a populated ledger

```markdown
`nivintw/nivintw-claude-skills` — 9 open · 2 ready · 2 in progress · 1 untriaged

## Resume in progress
**Yours to resume:**

| Issue | Status | Updated |
|-------|--------|---------|
| [#31](https://github.com/nivintw/nivintw-claude-skills/issues/31) — ship: Ollama shell-out mechanic | in-progress | 3d ago |
| [#30](https://github.com/nivintw/nivintw-claude-skills/issues/30) — address review feedback on docs reconciler | in-review | 6d ago |

Branch `feat/ollama-shellout` is checked out — resume it before starting anything new.

**In flight by others:**

| Issue | Assignee | Status | Updated |
|-------|----------|--------|---------|
| [#28](https://github.com/nivintw/nivintw-claude-skills/issues/28) — docs: per-plugin changelogs | @alex | in-progress | 21d ago ⚠️ stale |

## Start next

| # | Issue | Pri | Assignee | Updated |
|---|-------|-----|----------|---------|
| 1 | [#23](https://github.com/nivintw/nivintw-claude-skills/issues/23) — repo-agnostic docs sites | high | — | 2d ago |
| 2 | [#19](https://github.com/nivintw/nivintw-claude-skills/issues/19) — worktree-guard: detached HEAD | med | — | 14d ago |

**[#23](https://github.com/nivintw/nivintw-claude-skills/issues/23)** — only high-priority ready item, and it unblocks [nivintw/copier-everything#54](https://github.com/nivintw/copier-everything/issues/54).
**[#19](https://github.com/nivintw/nivintw-claude-skills/issues/19)** — quick win; clears the path for the guard refactor.

## Needs attention
**Untriaged:** 1 — needs `/dev-kit:handle-task-tracking`.

**Blocked:**

| Issue | Pri | Blocked by | Updated |
|-------|-----|------------|---------|
| [#26](https://github.com/nivintw/nivintw-claude-skills/issues/26) — wire release-App credentials | high | [#25](https://github.com/nivintw/nivintw-claude-skills/issues/25) (open) | 5d ago |

**Done-but-open:**

| Issue | Merged PR | Updated |
|-------|-----------|---------|
| [#22](https://github.com/nivintw/nivintw-claude-skills/issues/22) — add open-work skill | [#33](https://github.com/nivintw/nivintw-claude-skills/pull/33) (merged) | 1d ago |

Close it via `/dev-kit:handle-task-tracking` and clear its stale `status:in-*` label.

## Next action
Resume **[#31](https://github.com/nivintw/nivintw-claude-skills/issues/31)** — check out `feat/ollama-shellout` and keep going. (`/dev-kit:ship` starts fresh work; it won't resume an in-flight branch.)
```

### Worked example — an empty ledger

```markdown
`nivintw/nivintw-claude-skills` — 0 open · 0 ready · 0 in progress · 0 untriaged

## Resume in progress
Nothing in flight — no in-progress or in-review issues, no open PRs.

## Start next
Nothing ready — no ready items (all closed).

## Needs attention
None — nothing untriaged, blocked, or done-but-open.

## Next action
Queue is dry. Capture new work with `/dev-kit:handle-task-tracking`, or tell me what to tackle and I'll take it to `/dev-kit:ship`.
```

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

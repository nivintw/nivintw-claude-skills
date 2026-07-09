---
name: open-work
description: >-
  Use when the user asks "what should I work on next", "what's next in the backlog", "pick my
  next task", "rank my issues", or "what am I in the middle of". Reads the repo's open GitHub
  issues (the durable task ledger) and returns the full ranked "pick up next" list — every
  ready and startable item, never capped to a top-N — with a one-line rationale per standout
  pick. Leads with in-progress work to resume, then ranks status:ready by priority, staleness,
  and dependencies, surfaces blocked items, and flags an untriaged pile. Selects from the
  ledger but neither grooms it (/dev-kit:handle-task-tracking) nor does the work
  (/dev-kit:ship). Gathers and ranks via a bundled script.
---

# open-work

Answer **"what should I pick up next?"** by reading the repo's open GitHub issues and
returning the **full ranked, reasoned list of ready work** — not the user eyeballing the whole
issue list, and never a truncated top-N. The output **leads with your in-progress work to
resume** — usually you finish what you started before starting something new — then every
ready and startable item ranked to start (`status:ready`, and not already claimed by someone
else or blocked), with a one-line *why this one* for the standout picks, plus a short footer
of what needs attention before it's pickable.

This is the **select** verb in the dev-kit loop:

- **groom** — `/dev-kit:handle-task-tracking` keeps the ledger healthy (capture, triage,
  decompose, link, close).
- **select** — open-work (this) reads the ledger and recommends what to resume or start.
- **execute** — `/dev-kit:ship` takes the chosen item from idea to a review-ready PR.

open-work **reuses, never redefines**, the status-label model. `handle-task-tracking` is the
single source of truth for the labels; open-work only *consumes* them to rank.

## What this is not

- **Not grooming.** Creating, triaging, decomposing, relabeling, or closing issues is
  `/dev-kit:handle-task-tracking`. open-work's *ranking* reads; it doesn't mutate the ledger.
  The **one** exception is the auto-reconcile below: before ranking, it triggers
  `handle-task-tracking`'s **blocked-recheck slice** to clear a `status:blocked` whose blocker
  already closed, so the ranking is computed on corrected state instead of merely *reporting*
  drift it can't fix. That reconcile is a separate, clearly-attributed mutation — ranking itself
  stays read-only.
- **Not doing the work.** Executing the chosen item end to end is `/dev-kit:ship`.
- **Single-repo.** Cross-repo aggregation is out of scope (possible later).

## Gather + Rank — run the script

**Reconcile first (cheap, bounded).** Before ranking, trigger `handle-task-tracking`'s
blocked-recheck reconcile so a `status:blocked` whose blocker already closed is cleared and
ranks correctly this run — not re-surfaced as stale every time. The same
`rank_issues.py` `reconcile` block that ranking reads (`unblock` / `close_done` /
`stale_triage`) is what drives it; keep it bounded and skip it on a very large ledger so a quick
`open-work` never turns into an expensive run.

The mechanical half of this skill — listing open issues, partitioning by status label,
resolving a candidate's linked-PR merge state, resolving `Blocked by #N` references, and
applying the priority × staleness sort — is **mechanical, not judgment-based** and lives in
[`scripts/rank_issues.py`](scripts/rank_issues.py), not in this prose. Run it (via `uv run`,
which resolves the script's own PEP 723 header — no project install needed):

```bash
uv run plugins/dev-kit/skills/open-work/scripts/rank_issues.py
```

It infers `--owner`/`--repo` (via `gh repo view`) and `--viewer` (via `gh api user`) when
omitted; pass them explicitly if the cwd isn't the target repo. It prints one JSON object:

```jsonc
{
  "tally": {"open": N, "ready": N, "in_progress": N, "untriaged": N},
  "degraded": bool,               // true when no status:* label is used anywhere
  "resume": {"yours": [...], "others": [...]},   // in-progress/in-review, done-but-open excluded
  "start_next": [...],            // every ready+startable issue, priority x staleness sorted, never capped
  "needs_attention": {
    "untriaged_count": N,
    "blocked": [...],             // status:blocked OR a ready issue with an open Blocked-by
    "done_but_open": [...]        // in-progress/in-review whose linked PR already merged
  }
}
```

Each issue object carries `number`, `title`, `url`, `updated_at`, `assignee`, `status`,
`priority`, `blocked_by` (a list of `{number, open}`, populated for `status:ready` issues),
`linked_pr` (`{number, state, merged_at, url}` or `null`), and (on resume rows) a `stale`
bool. Only the *first* assignee is tracked — a multi-assignee issue where the viewer isn't
first is misclassified as someone else's. **What the script does not do — because it's
judgment, not mechanics — stays your job**: read the body of each `needs_attention` candidate,
and of the `start_next` standout picks you call out with a rationale (a rationale needs more
than a title — you don't need to read every body when the ready list is long, just the ones
you're writing a rationale line for), and in **degraded mode** (see below) read bodies to
judge actionability, since the script has no ranking signal to fall back on there.

Readiness-gate semantics the script encodes (for reference — you don't need to re-derive
these, just narrate the result): only `status:ready` is startable; `status:triage` and
unlabeled issues are the untriaged pile; `status:in-progress`/`status:in-review` are in-flight
(split yours vs. others by assignee); `status:blocked` — or a `status:ready` issue whose body
references a still-open `Blocked by #N` — is excluded from `start_next` and surfaced
separately; an in-progress/in-review issue whose linked PR already **merged** is done-but-open,
not resumable. A `status:ready` issue assigned to someone else is excluded from `start_next`
(ownership filter) even though it still counts toward the `ready` tally.

## When the ledger isn't labeled (degraded mode)

Many repos haven't set up the status / priority taxonomy — issues may carry only a `type` or
a bare `enhancement` label. The script detects this itself (`"degraded": true` — no `status:*`
label used anywhere) and, in that mode, also resolves a linked-PR proxy for every *assigned*
issue (not just `status:in-progress`/`in-review` ones), so `resume` still surfaces real
in-flight work without the labels. **Don't fail.** Flag the gap, recommend
`/dev-kit:handle-task-tracking` to establish the labels (its
[`reference/recipes.md`](../handle-task-tracking/reference/recipes.md) has the one-time
`gh label create` block), then rank on whatever signal exists beyond the script's output: any
explicit priority in the body, type, how **actionable** the issue is (clear acceptance
criteria reads as more ready than a vague stub) — this part is judgment, not something the
script can compute — and recency/staleness (which the script does give you per-issue). Say
plainly that the ranking is best-effort until the labels exist.

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
<full ranked status:ready list as a signal table; one-line rationale beneath the table for standout picks>

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
3. **`## Start next`** — **every** `status:ready` and startable item, ranked, never capped to a
   top-N — as a **signal table** with columns `# | Issue | Pri | Assignee | Updated` (every row
   here is `status:ready` by definition, so a `Status` column would be constant and is
   omitted). Give a **one-line rationale in prose beneath the table** for the standout picks
   (the top priority item, anything that unblocks other work, a quick win) — never inside a
   table cell, and never force a rationale line for every row once the list is long; the table
   itself is the complete ranked record, the prose is judgment on top of it.
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
- **`Start next` is never capped.** Every `status:ready`, startable item appears in the table,
  ranked — no top-N truncation, ever. **`Resume in progress` may still show a top slice** when
  the in-flight pile itself is large (see above) — but state the total and never hide the
  remainder.
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

## Tooling — the script for gathering + ranking, MCP/gh for candidate bodies

`scripts/rank_issues.py` (above) is the `gh`-CLI gather-and-rank path — prefer it over
re-deriving the same `gh` calls by hand. `tests/open_work_rank.bats` exercises its `rank()`
half (the pure partition/sort logic) via `--input`; the live `gh`-calling `gather()` half is
not covered by automated tests (it was verified by hand against this repo instead). Its
`--input <fixture.json> --viewer <login>` mode is for testing only (bypasses live `gh`); a
normal run always calls it with no `--input`.

For the judgment-only step layered on top — reading a `start_next` or `needs_attention`
candidate's **body** to write its one-line rationale, or to judge actionability in degraded
mode — prefer the **GitHub MCP tools**: `mcp__github__issue_read` for a candidate's body,
comments, labels, and sub-issues. Fall back to `gh issue view <n> --json body` when the MCP
server isn't connected (it can be absent in headless or cron runs) or when a human wants a
command to paste. Don't clone a repo just to read it — both paths read remote content
directly. The label and query command forms live in `handle-task-tracking`'s
[`reference/recipes.md`](../handle-task-tracking/reference/recipes.md) (e.g. `gh issue list
--label "status:ready" --label "priority:high" --state open`) — reuse them rather than
duplicating.

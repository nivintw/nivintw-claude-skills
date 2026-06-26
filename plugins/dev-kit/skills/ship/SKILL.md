---
name: ship
description: >-
  This skill should be used when the user asks to "ship this", "ship a change/feature/fix",
  "take this from idea to a PR", "open a PR for this", or "run the full dev workflow on
  this" — any real change worth a planned, reviewed pull request. It drives a change from
  idea to a review-ready PR through a disciplined Human + AI teaming workflow: an explicit
  planning step and sign-off first, work isolated in a dedicated git worktree,
  implementation that fans out subagents and /workflows (delegating mechanical work to
  cheaper models to stay token-conscious), task tracking delegated to
  /dev-kit:handle-task-tracking across the lifecycle, then always /simplify, then refresh
  docs, then a full /dev-kit:review-pr pass, the local quality gate, a conventional-commit
  PR, and an automated Copilot review iterated to convergence before the change is handed
  off for human review. Not for a trivial one-off commit or a bare "push this". Never
  auto-merges.
---

# ship

The orchestrator for shipping a change well. Run the phases **in order**. The throughline:
keep the human in control at the ends (plan sign-off, final merge) and do rigorous,
token-aware work in the middle. **ship never merges** — it hands off a review-ready PR.

## Phase 0 — Continuity setup (do this first, maintain throughout)

Create a durable progress file — `.ship/<branch>.md` (gitignore `.ship/`) — and update it
at **every phase boundary**: the plan, decisions made, what's done, what's next. This is
what makes ship robust to context compaction: ship cannot trigger `/compact` itself and
cannot measure its own context, so instead it (a) pushes heavy work into subagents whose
context is discarded, (b) keeps this file + checkpoint commits as durable state, and (c) at
long phase boundaries, *advises* the user "good moment to /compact — state is saved in
.ship/<branch>.md." After any compaction, re-read this file to resume losslessly.

## Phase 1 — Plan (explicit, required)

Never skip this. Understand the ask, then **fan out `Explore` subagents** (read-only) to map
the relevant code, patterns, and prior art — so the main context stays lean. Write a concrete
plan + checklist into the progress file: what changes, which files, the approach, risks, and
how it'll be verified. **Get the user's sign-off on the plan before implementing.** Surface
genuine decisions now (don't bury them).

Delegate task tracking to **`/dev-kit:handle-task-tracking`** — don't reinvent it here.
Find or open the GitHub issue that tracks this work, record its number in the progress file,
and capture the plan's key decisions on the issue. The `.ship/<branch>.md` file tracks
*this run's* mechanics; the **issue is the durable record of the work itself**, so it
outlives the branch and the session.

## Phase 2 — Worktree + branch (always)

Create and work inside a **dedicated git worktree** on a fresh feature branch — never on
`main` or the user's primary checkout:

```bash
git worktree add ../<repo>-<branch> -b <type>/<short-name>
```

This isolates the in-progress change (the user keeps using their main checkout) and lets
parallel, file-mutating subagents run in **per-agent worktree isolation** without clobbering
each other. (Worktree teardown happens in Phase 8, or immediately on abort:
`git worktree remove`.)

## Phase 3 — Implement (fan out; delegate by cost)

Do the work. Be **thorough but token-conscious** — that balance is a first-class goal, not an
afterthought. Match the tool to the job:

- **Haiku** — mechanical, well-specified work: grep/inventory, renames, file moves,
  formatting, boilerplate, repetitive edits.
- **Sonnet** — moderate, well-scoped work: a contained implementation, writing tests, a
  focused refactor, a codegen script with a clear spec.
- **Opus / `/workflows`** — hard reasoning, design, cross-cutting changes, and the
  adversarial/verification work. Use `/workflows` to pipeline or fan out independent work
  (e.g. one agent per file/module/dimension) when the task decomposes.

Fan out **freely** where work is independent, but report what was delegated and to whom.
Update the progress file and make **checkpoint commits** as coherent pieces land. As work
starts, flip the tracking issue to `status:in-progress` (via
`/dev-kit:handle-task-tracking`) and log notable decisions on it as they're made.

## Phase 4 — Simplify (always)

Run **`/simplify`** on the change before any review. Quality-only cleanup (reuse,
simplification, efficiency, altitude) while everything is fresh.

## Phase 5 — Docs (default; skip only if no docs site)

Run **`/dev-kit:generate-docs`** so the docs never drift from the change. If the repo has no
docs site / isn't a marketplace, note that and skip — but default to keeping docs current.

## Phase 6 — Review (always)

Run **`/dev-kit:review-pr`** (Mode A — your own change). That runs the full battery
(`/code-review`, `/security-review`, `/pr-review-toolkit:review-pr`) **plus a context-chosen
adversarial pass**, then synthesizes one prioritized report. Apply the must-fixes; re-run as
needed; leave the branch green. Flip the tracking issue to `status:in-review` (via
`/dev-kit:handle-task-tracking`) once the change is up for review.

## Phase 7 — Local gate

Infer the repo's checks from its config (pre-commit/prek, test runner, linters, type
checker) and run them — don't wait to be told. Fix what they flag. Match the project's
existing quality bar.

## Phase 8 — Commit + PR (hand off, don't merge)

Commit in **Conventional Commit** style (and gitmoji if the repo enforces it — match the
history). Push the branch and open the PR **as a draft** (`gh pr create --draft`) — it stays
a draft while ship iterates below, so no human reviews it prematurely. Give it a body that
explains the *why*, the verification done, and any flagged trade-offs or decisions. Reference
the tracking issue with `Closes #N` so the merge closes it (the linking conventions live in
`/dev-kit:handle-task-tracking`). **Do not add AI attribution.**

### Converge an automated review before handing off

With the draft PR open, request an **automated Copilot review** (GitHub's `request_copilot_review`
via the GitHub MCP or `gh`) and **iterate to convergence**:

1. Wait for Copilot's review to land on the current PR head.
2. Triage its findings like any reviewer — apply the real ones (commit + push to the same
   branch) and, for each declined, note why.
3. **Re-request the review** so Copilot re-runs against the new head.
4. Repeat until it **converges**: Copilot approves, or its only remaining comments are
   non-actionable (nits already judged, or false positives). Bound the loop — after ~3
   rounds with nothing substantive left, stop and summarize the residue for the human
   rather than chasing nits forever.

This catches what the Phase 6 battery missed on the *actual* PR diff and keeps the branch
green before a person looks. If Copilot review isn't enabled on the repo, note that and skip
— don't block the hand-off on it.

### Hand off

Once the review has converged, **mark the PR ready for review** (`gh pr ready`) and **hand
off** — that flip from draft to ready *is* the hand-off signal. Ship stops here; merging is
the human's call (or a later, explicitly-authorized step). Finally, tear down the worktree.

## Guardrails

- Plan sign-off (Phase 1) and the final merge are the human's; everything between is ship's
  to execute rigorously. Merge happens *after* hand-off — it is never a ship phase.
- Task state is GitHub's job — delegate it to **`/dev-kit:handle-task-tracking`** throughout
  (establish the issue at Phase 1, `in-progress` at Phase 3, `in-review` at Phase 6,
  `Closes #N` at Phase 8). Don't duplicate that lifecycle inside ship.
- If real scope turns out much larger than the ask, stop and check in rather than silently
  ballooning or downgrading the change.
- The phases lean on skills this plugin doesn't ship (`/simplify`, `/dev-kit:generate-docs`,
  `/dev-kit:review-pr`, and the reviewers it calls). If one isn't installed or is denied,
  note the gap and continue — don't fail the whole ship over a missing optional step.
- Keep `.ship/<branch>.md` current — it's the resume point if context is compacted.

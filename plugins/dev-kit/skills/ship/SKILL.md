---
name: ship
description: >-
  Drive a change from idea to a review-ready pull request through a disciplined Human +
  AI teaming workflow: an explicit planning step first, work isolated in a dedicated git
  worktree, implementation that fans out subagents and /workflows (delegating mechanical
  work to cheaper models to stay token-conscious), then always /simplify, then refresh
  docs, then a full /dev-kit:review-pr pass, the local quality gate, and finally a
  conventional-commit PR handed off for human review. Use when asked to ship, ship a
  change/feature/fix, take something from idea to PR, or run the full dev workflow on a
  task — i.e. a real change worth a planned, reviewed PR, not a trivial one-off commit or
  a bare "push this." Never auto-merges.
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

Fan out **freely** where work is independent, but report what you delegated and to whom.
Update the progress file and make **checkpoint commits** as coherent pieces land.

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
needed; leave the branch green.

## Phase 7 — Local gate

Infer the repo's checks from its config (pre-commit/prek, test runner, linters, type
checker) and run them — don't wait to be told. Fix what they flag. Match the project's
existing quality bar.

## Phase 8 — Commit + PR (hand off, don't merge)

Commit in **Conventional Commit** style (and gitmoji if the repo enforces it — match the
history). Push the branch and open a PR whose body explains the *why*, the verification done,
and any flagged trade-offs or decisions. **Do not add AI attribution.** Then **hand off as
ready for human review** — ship stops here; merging is the human's call (or a later,
explicitly-authorized step). Finally, tear down the worktree.

## Guardrails

- Plan sign-off (Phase 1) and merge (Phase 8) are the human's; everything between is yours to
  execute rigorously.
- If real scope turns out much larger than the ask, stop and check in rather than silently
  ballooning or downgrading the change.
- The phases lean on skills this plugin doesn't ship (`/simplify`, `/dev-kit:generate-docs`,
  `/dev-kit:review-pr`, and the reviewers it calls). If one isn't installed or is denied,
  note the gap and continue — don't fail the whole ship over a missing optional step.
- Keep `.ship/<branch>.md` current — it's the resume point if context is compacted.

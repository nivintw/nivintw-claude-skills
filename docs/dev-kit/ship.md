---
title: dev-kit ship
---

# ship

The orchestrator. Drives a change from idea to a review-ready **draft PR** — plan and
sign-off first, work isolated in a dedicated worktree, rigorous token-aware execution in the
middle, hand-off at the end. The human holds both ends; ship executes everything between.

## Usage

```text
/dev-kit:ship <the change>                 # idea → plan → sign-off → implement → review → draft PR
/dev-kit:ship <the change>, and land it    # one grant covers sign-off AND the merge
```

Natural-language forms work too: *"ship this fix"*, *"take this from idea to a PR"*, *"ship
and land it"*.

## What it does

One run, phases in order:

| Step | What happens |
| --- | --- |
| Start of run | `/dev-kit:cleanup-locally` — update the default branch, prune merged leftovers, so the run branches off a current base. |
| Phase 0 — Continuity | Progress + state files under the git dir (uncommittable by construction); a Stop hook backstops against yielding mid-run. |
| Phase 1 — Plan | Fan out `Explore` agents, write a concrete plan, open/link the tracking issue, then **stop for sign-off**. |
| Phase 2 — Worktree | `EnterWorktree` onto a fresh branch — never `main`, never the primary checkout. |
| Phase 3 — Implement | Fan out subagents; route each chunk to the cheapest fitting model tier; checkpoint commits. |
| Phase 4 — Simplify | `/simplify` before any review — and a suppression is a finding, not a cleanup. |
| Phase 5 — Docs | `/dev-kit:generate-docs` so docs never drift (skip only if the repo has no docs). |
| Phase 6 — Review | `/dev-kit:review-pr` — the full battery plus an adversarial pass; apply the must-fixes. |
| Phase 7 — Local gate | Infer the repo's checks (prek, tests, linters) and run them green. |
| Phase 8 — Commit + PR | Conventional-commit draft PR, converge an automated Copilot review, then flip to ready — that flip *is* the hand-off. |

By default ship **never merges** — it stops at a review-ready draft PR and the merge is the
human's call. The one exception is the explicit [`land`](land.md) verb, which drives the PR
through CI, review convergence, and a rebase-merge.

## When to reach for it

Reach for `ship` to start fresh work — any real change worth a planned, reviewed PR. It does
not resume an in-flight branch: an already-open PR is `land`'s job, and a trivial one-off
commit or bare "push this" doesn't need ship at all.

The human holds exactly two gates: **plan sign-off** (Phase 1) and the **hand-off** (Phase
8). *"Ship and land it"* collapses both into one up-front grant — ship then skips the
sign-off pause, decides-and-logs instead of asking (every call lands in the PR's *Decisions
made without asking* section), and carries the run through the merge.

!!! note "Batching is a release question, not a `land` question"
    Naming several discrete items auto-detects as a batch regardless of `land` — one PR vs.
    several is decided by the repo's release/merge convention and risk-isolation, the same
    way either way. `land` only governs whether ship drives the resulting PR(s) to merge:
    without it, the grouping is proposed as part of the plan for sign-off; with it, the
    grouping is logged as a decision — in each resulting PR if the batch splits into several,
    and mirrored onto every tracking issue in the batch, not just the PR(s) themselves.

## Related

- [`land`](land.md) — the explicit opt-in path where ship merges; standalone entry point to
  the `land` verb.
- [`review-pr`](review-pr.md) — the Phase 6 battery ship runs before opening the PR.
- [`cleanup-locally`](cleanup-locally.md) — bookends every run: start-of-run reconcile and
  post-merge teardown.
- [`handle-task-tracking`](handle-task-tracking.md) — the issue lifecycle ship delegates to
  at every phase (open, `in-progress`, `in-review`, verified closed).

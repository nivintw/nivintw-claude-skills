---
title: dev-kit land
---

# land

Drive an already-open PR to merged — CI to green, the automated review converged, a
rebase-merge, then cleanup. A discoverable, tab-completable entry point to `ship`'s `land`
verb: landing is the one path where ship merges, and it's always explicit.

## Usage

```text
/dev-kit:land        # attach to the current branch's open PR
/dev-kit:land 42     # drive PR #42 cold — no active ship run needed
```

Natural-language forms work too: *"land it"*, *"land PR #42"* — or grant it up front with
*"ship and land it"*.

## What it does

One idempotent loop, wherever you start it:

1. **Update** the branch with its base.
2. **Watch CI** on the current head — on any red check: fix, push, re-watch until green
   (bounded — a failure it can't clear is surfaced, not thrashed against).
3. **Converge the automated review** — the same Copilot loop ship runs at hand-off.
4. **Rebase-merge** the PR (`gh pr merge --rebase`) — the one place ship merges.
5. **Clean up** — exit the worktree, reconcile local state, and verify the tracking issue
   actually closed rather than trusting `Closes #N` fired.

This is not GitHub auto-merge: ship holds the merge decision and merges only on green +
converged. And once granted, `land` decides-and-logs rather than stopping to ask — every
judgment call it makes is recorded in the PR's *Decisions made without asking* section.

## When to reach for it

Landing after a human review is the normal, encouraged path: `ship` deliberately stops at a
review-ready PR so someone can look it over — you (or a teammate) review, then `land`
finishes the job. Grant it whenever suits:

- **Up front** — *"ship and land it"*: one grant covers plan sign-off and the merge.
- **After hand-off** — you reviewed the PR ship handed you; now land it.
- **Cold** — `/dev-kit:land 42` needs no active ship run, and works on PRs ship never
  authored.

!!! note "The one thing land can't do after the fact"
    Batching several items into a single PR is a decision `ship` makes up front, before any
    PR exists. `land` drives one open PR to merged; it can't retroactively bundle several.

## Related

- [`ship`](ship.md) — owns the `land` verb; this command is its standalone entry point.
- [`cleanup-locally`](cleanup-locally.md) — the post-merge reconciliation `land` finishes
  with.
- [`handle-task-tracking`](handle-task-tracking.md) — how the tracking issue gets verified
  closed (and its stale status labels cleared) after the merge.

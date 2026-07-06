---
title: dev-kit cleanup-locally
---

# cleanup-locally

Reconcile the local clone with the remote after work merges — update the default branch,
prune merged worktrees and branches — **without ever destroying unmerged work**. When in
doubt it keeps and reports rather than deletes.

## Usage

```text
/dev-kit:cleanup-locally                   # do it
/dev-kit:cleanup-locally -n                # dry run — print what would change, change nothing
/dev-kit:cleanup-locally --prune-remote    # also delete merged remote branches
```

Natural-language forms work too: *"clean up local branches"*, *"prune merged worktrees"*,
*"update main"*, *"tidy up after a merge"*.

## What it does

One script, one ordered pass:

1. **`git fetch --prune origin`** — refresh remote state; if the fetch fails the whole run
   aborts, so nothing is pruned against stale data.
2. **Update the default branch** — a dirty tree is stashed, unpushed commits are rebased
   forward onto `origin`, then the stash is popped back. A genuine conflict aborts that
   step with a warning; nothing is clobbered or silently dropped.
3. **Prune merged worktrees** under `.claude/worktrees/` — removed only when the branch is
   merged *and* the tree is clean; never the primary or current checkout.
4. **Prune merged branches** — deleted only when their commits are verified in the default
   branch, squash merges detected too. Unmerged branches are never deleted, even when
   their remote is gone.
5. **Report merged remote branches** on `origin`, one line each — or delete them with
   `--prune-remote` (dry-run honoured).

## When to reach for it

`ship` runs it automatically at the start of a run and again after you report a merge —
but it stands alone any time local branches or worktrees have drifted from the remote.
Lead with the dry run (`-n`) when the state is unfamiliar, then re-run for real.

!!! note "Kept means kept for a reason"
    If it held back something you wanted gone, that item is unmerged, dirty, or checked
    out somewhere. The output says *why* it was kept — resolve that rather than forcing
    the delete blindly.

## Related

- [`ship`](ship.md) — calls this at the start of every run and again post-merge.
- [`land`](land.md) — finishes its merge-and-cleanup loop with this reconciliation.

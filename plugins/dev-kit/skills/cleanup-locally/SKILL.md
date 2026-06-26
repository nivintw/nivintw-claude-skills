---
name: cleanup-locally
description: >-
  This skill should be used when the user asks to "clean up local branches", "prune merged
  branches", "prune worktrees", "tidy up after a merge", "update main", "pull main", "sync
  main", or otherwise wants their local clone reconciled with the remote after PRs land. It
  fetches, brings the default branch up to date (stashing dirty work and rebasing unpushed
  commits forward, never clobbering), removes merged worktrees under .claude/worktrees/, and
  deletes local branches whose commits are already in the default branch — including squash
  merges. It is deliberately conservative: anything unmerged, dirty, or currently checked out
  is kept and reported. /dev-kit:ship calls it at the start of a run and again after the user
  reports a merge. Reach for it whenever local branches/worktrees have drifted from the remote.
---

# cleanup-locally

Reconcile the local clone with the remote after work merges: prune merged branches and
worktrees, and bring the default branch up to date — **without ever destroying unmerged
work**. This is the safe, repeatable "tidy up" that runs at the start of `/dev-kit:ship`
and again once a PR is merged.

## The script

`scripts/cleanup-locally.sh` does the whole job in one pass. Run it from inside the repo
(it assumes the remote is named `origin`):

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/cleanup-locally/scripts/cleanup-locally.sh"        # do it
"${CLAUDE_PLUGIN_ROOT}/skills/cleanup-locally/scripts/cleanup-locally.sh" -n     # dry run
```

`-n`/`--dry-run` prints exactly what *would* change without touching anything — lead with
it when the state is unfamiliar, then re-run for real. `-h`/`--help` explains the rest.

What it does, in order:

1. **`git fetch --prune origin`** — refresh remote state (and drop stale remote-tracking
   refs). Aborts the whole run if the fetch fails, so nothing is pruned on stale data.
2. **Update the default branch** (e.g. `main`) in whichever worktree holds it: a dirty tree
   is **stashed** first, unpushed local commits are **rebased forward** onto `origin`, then
   the stash is **popped** back. A genuine rebase or stash-pop **conflict aborts that step
   with a warning** and leaves the work exactly as it was — it never clobbers or silently
   drops anything. If the default branch isn't checked out anywhere, its ref is
   fast-forwarded only when that's a clean ancestor move.
3. **Prune merged worktrees** under `.claude/worktrees/` (never the primary checkout, never
   the current one): removed only when the branch is merged *and* the tree is clean.
4. **Prune merged branches**: a branch is deleted only when its commits are verified present
   in the default branch — a normal/rebase merge (ancestor) **or a squash merge** (the whole
   branch diff already applied, detected via `git commit-tree` + `git cherry`). Branches
   whose remote is gone but whose commits are *not* in the default branch are **kept** (an
   accidentally-deleted remote can't cost you your only copy). Branches checked out in *any*
   worktree are skipped.

Worktrees are pruned before branches so a branch freed by removing its worktree becomes
eligible for deletion in the same run.

## Reading the output

Every line is one decision. `Removed` / `Deleting` are actions taken; `Skipping … (need
review)` flags something unmerged the user may want to look at; `kept` counts things held
back for safety (dirty, detached, or checked out). The final summary tallies
deleted/removed/skipped/kept. A non-zero exit means at least one operation failed (e.g. a
worktree that wouldn't remove) — surface that, don't bury it.

The script is conservative by construction: when in doubt it keeps and reports rather than
deletes. If the user wants something gone that it kept, that item is unmerged/dirty/checked
out — say *why* it was kept rather than forcing the delete blindly.

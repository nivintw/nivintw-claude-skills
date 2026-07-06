---
title: dev-kit cleanup-locally
---

# cleanup-locally

`/dev-kit:cleanup-locally` — reconcile your local clone with the remote after PRs land:
bring the default branch up to date, prune merged worktrees, and delete local branches
whose commits already merged — squash merges included. Deliberately conservative: anything
unmerged, dirty, or checked out is kept and reported, never clobbered.

Try: *"clean up local branches"* · *"prune merged worktrees"* · *"update main"*.

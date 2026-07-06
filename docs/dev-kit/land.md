---
title: dev-kit land
---

# land

`/dev-kit:land` — a discoverable, tab-completable entry point to `ship`'s `land` verb —
drives an already-open PR to merged: CI to green, the automated review converged, a
rebase-merge, then cleanup. With no PR number, attaches to the current branch's open PR;
`/dev-kit:land <N>` drives PR #N cold. (Batching several items into one PR is a `ship`-time
decision, made before the PR exists — ask `ship` to land a batch up front, not this command
after the fact.)

Try: *"land it"* · *"land PR #42"*.

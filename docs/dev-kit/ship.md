---
title: dev-kit ship
---

# ship

`/dev-kit:ship` — the orchestrator. Drives a change from idea to a review-ready PR: plan and
get sign-off, work in a dedicated worktree, implement with work routed to the cheapest
fitting model tier, then simplify, refresh docs, run the full review battery, open the PR,
and converge an automated review. Hands off by default — or, on request, **lands** the PR:
drives CI to green, converges the review, then rebase-merges and cleans up. The one path
where ship merges.

Ask for `land` up front and that single grant covers the plan sign-off too — no separate
"plan and get sign-off" pause — plus every design/approach choice for the rest of the run,
logged to the PR (a required "Decisions made without asking" section) and mirrored as
`Decision:`-prefixed issue comments instead of re-confirmed. Naming several discrete items
alongside a `land` grant ("ship and land these three fixes as one batch") auto-detects as a
single minimal PR — that batching behavior doesn't apply without `land`; a bare `ship` batch
still ships each item as its own PR.

Try: *"ship this fix"* · *"take this from idea to a PR"* · *"land the PR"* · *"ship and land
it"*.

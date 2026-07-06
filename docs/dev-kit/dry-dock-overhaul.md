---
title: dev-kit dry-dock-overhaul
---

# dry-dock-overhaul

`/dev-kit:dry-dock-overhaul` — deliberately outside the loop above. An exhaustive,
always-human-triggered audit of the whole repo, not a diff: every tracked file is genuinely
read and judged, plus a "10,000-foot" pass discovered fresh for this repo's own shape
(docs-site UX, test-suite architecture, naming consistency, or whatever else it calls for).
Orchestrates `/dev-kit:review-pr` (whole-repo mode), `/dev-kit:generate-docs`, and
`/dev-kit:pre-public-hardening` alongside that net-new coverage into one severity-ranked,
ephemeral report. This is the most expensive skill in the marketplace by design — reach for
it rarely, and on purpose.

Try: *"dry dock overhaul this repo"* · *"audit the whole repo"* · *"review every line"*.

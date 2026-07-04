---
name: dry-dock-overhaul
description: >-
  This skill should be used when the user asks for a "dry dock overhaul", to "audit the whole
  repo", "deep audit this codebase", "review every line", "do a full repo review", "is this
  repo well organized", or wants an exhaustive, occasional health check of an entire
  repository rather than a diff. It reads every tracked source file and judges it, discovers
  and runs whatever "10,000-foot" communication/UX questions actually matter for this
  specific repo (docs-site UX, test-suite architecture, naming consistency, or whatever else
  the repo's shape calls for), and orchestrates /dev-kit:review-pr (Mode C),
  /dev-kit:generate-docs, and /dev-kit:pre-public-hardening alongside those net-new
  dimensions. Produces one ephemeral, severity-ranked report — nothing it newly finds gets
  auto-applied (generate-docs's own native writes are the one exception). Always
  human-triggered; no other skill should invoke it automatically. This is the most expensive
  skill in the marketplace by design — reach for it rarely, and on purpose.
---

# dry-dock-overhaul

(placeholder — full body written in Task 2-4)

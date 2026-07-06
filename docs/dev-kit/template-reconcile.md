---
title: dev-kit template-reconcile
---

# template-reconcile

`/dev-kit:template-reconcile` — for repos managed by a Copier template: reconciles against
the upstream template after an adopt or update, verifying no template infra was silently
dropped. Scaffolds a divergence registry and a synced-files test into the repo, and prompts
to file upstream (via `/dev-kit:handle-task-tracking`'s cross-repo filing) when a change
touches a template-owned file. A companion to `copier update`, not a replacement for it.

Try: *"adopt the copier template"* · *"reconcile against the template"* · *"did the template
infra come over?"*.

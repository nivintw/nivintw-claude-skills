---
description: Land an open PR — drive CI to green, converge the automated review, rebase-merge, and clean up. Delegates to ship's land verb.
argument-hint: "[PR number]"
---

# Land a PR

Run the **land** verb of the dev-kit `ship` skill against `$ARGUMENTS`.

Invoke the `ship` skill and follow its **Land the PR** section: if `$ARGUMENTS` is a PR
number, drive that PR cold (standalone entry point); if empty, attach to the current
branch's open PR and drive it from there. Either way, the same idempotent loop runs.

Landing is **opt-in and explicit** — it is the one path where ship merges. The loop drives
CI to green, converges the automated (Copilot) review, then **rebase-merges** the PR
(`gh pr merge --rebase`) and falls straight into Post-merge cleanup. Do not restate the
loop here — ship owns it in full (its **Land the PR** section and landing-driver reference).

**Granting `land` also means: don't stop to ask.** It extends "the human decides" from just
the merge to every design/plan choice left in the loop (CI fixes, review triage, batch
grouping if this is a multi-item request) — ship's own Phase 1 carve-out covers the details.
The one thing this never touches is destructive/irreversible actions (force-push, resets,
deletions), which still require explicit go-ahead. Every autonomous call gets logged where
you'll actually look for it: the PR's `## Decisions made without asking` and a `Decision:`
comment on the tracking issue — retrievable from either alone, in a brand-new session.

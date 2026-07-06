---
title: dev-kit
---

# dev-kit

<span data-version="dev-kit"></span> · workflow · pull-request · code-review · security-review ·
issues · worktrees ·
[source ↗](https://github.com/nivintw/nivintw-claude-skills/tree/main/plugins/dev-kit)

A human + AI development workflow. Take a change from idea to a reviewed pull request —
planned, isolated, implemented with tiered subagent delegation, simplified, documented, and
reviewed. The human stays in control at the ends; the rigorous work happens in the middle.
It never auto-merges — unless you explicitly tell it to `land` the PR.

## The loop

`/dev-kit:ship` is the orchestrator and calls the others directly; each also stands alone.
`/dev-kit:land` is a discoverable entry point to ship's own merge verb, not a separate loop
step. Three more sit deliberately outside this loop — `/dev-kit:dry-dock-overhaul`,
`/dev-kit:pre-public-hardening`, and `/dev-kit:template-reconcile` — occasional checks you
reach for on your own schedule, never called automatically.

Track work as issues with `/dev-kit:handle-task-tracking`, pick what's next with
`/dev-kit:open-work`, then `/dev-kit:ship` it — which reviews with `/dev-kit:review-pr`,
refreshes docs with `/dev-kit:generate-docs`, and tidies up with `/dev-kit:cleanup-locally`.

!!! note "A Stop hook backstops this"
    dev-kit also ships a `Stop` hook (`ship-continue.sh`) that blocks a premature stop only
    while a ship run's `state` names an active phase — e.g. right after a delegated
    sub-skill like `/security-review` hands back mid-run — and default-allows everywhere
    else (human gates, async waits, or no ship run at all), so it can never trap a session
    or nag during a legitimate wait.

## Commands

Eleven commands — each gets its own page.

| Command | One-liner |
|---------|-----------|
| [`ship`](ship.md) | Idea → review-ready PR: plan, worktree, implement, simplify, docs, review, hand off (or `land`). |
| [`land`](land.md) | Discoverable entry point to `ship`'s merge verb — drives an open PR to merged. |
| [`review-pr`](review-pr.md) | The single review entry point — full battery + adversarial pass, one prioritized report. |
| [`generate-docs`](generate-docs.md) | Reconciles the whole docs set against the whole codebase; authors this site. |
| [`handle-task-tracking`](handle-task-tracking.md) | GitHub issues as the durable task ledger — capture, triage, decompose, close. |
| [`open-work`](open-work.md) | Ranked "pick up next" shortlist from the open issues, leading with in-flight work. |
| [`cleanup-locally`](cleanup-locally.md) | Reconciles your local clone with the remote after PRs land. |
| [`doctor`](doctor.md) | Health check for installed plugins — version drift + a skill inventory. |
| [`pre-public-hardening`](pre-public-hardening.md) | Full-history secrets/licensing readiness review before a repo goes public. |
| [`dry-dock-overhaul`](dry-dock-overhaul.md) | The most expensive skill by design — an exhaustive, human-triggered whole-repo audit. |
| [`template-reconcile`](template-reconcile.md) | For Copier-managed repos — verifies template infra survived an adopt/update. |

## Install

```text
/plugin marketplace add nivintw/nivintw-claude-skills
/plugin install dev-kit@nivintw-claude-skills
```

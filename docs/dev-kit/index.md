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

Eleven commands aren't eleven unrelated tools — they're one iterative-delivery loop, with
`ship` as the orchestrator that drives most of it directly:

<div class="dk-loop">
  <div class="dk-flow">
    <a class="dk-node" href="handle-task-tracking/">handle-task-tracking</a>
    <div class="dk-edge">
      <span class="dk-line" aria-hidden="true"></span>
      <span class="dk-cap">track work as issues</span>
      <span class="dk-line" aria-hidden="true"></span>
      <span class="dk-arrow" aria-hidden="true">▾</span>
    </div>
    <a class="dk-node" href="open-work/">open-work</a>
    <div class="dk-edge">
      <span class="dk-line" aria-hidden="true"></span>
      <span class="dk-cap">pick what's next</span>
      <span class="dk-line" aria-hidden="true"></span>
      <span class="dk-arrow" aria-hidden="true">▾</span>
    </div>
    <div class="dk-shiprow">
      <a class="dk-node dk-node--ship" href="ship/">ship</a>
      <span class="dk-side dk-side--left">
        <a class="dk-node dk-node--ghost" href="handle-task-tracking/">handle-task-tracking</a>
        <span class="dk-sidelink">
          <span class="dk-sidecap">status updates</span>
          <span class="dk-dash" aria-hidden="true"></span>
        </span>
      </span>
      <span class="dk-side">
        <span class="dk-sidelink">
          <span class="dk-sidecap">entry point</span>
          <span class="dk-dash" aria-hidden="true"></span>
        </span>
        <a class="dk-node dk-node--ghost" href="land/">land</a>
      </span>
    </div>
    <span class="dk-drop" aria-hidden="true"></span>
    <div class="dk-fan">
      <div class="dk-branch">
        <span class="dk-cap">review battery</span>
        <span class="dk-arrow" aria-hidden="true">▾</span>
        <a class="dk-node" href="review-pr/">review-pr</a>
      </div>
      <div class="dk-branch">
        <span class="dk-cap">refresh docs</span>
        <span class="dk-arrow" aria-hidden="true">▾</span>
        <a class="dk-node" href="generate-docs/">generate-docs</a>
      </div>
      <div class="dk-branch">
        <span class="dk-cap">tidy up</span>
        <span class="dk-arrow" aria-hidden="true">▾</span>
        <a class="dk-node" href="cleanup-locally/">cleanup-locally</a>
      </div>
    </div>
    <div class="dk-loopnote">↺ then back to open-work for the next item</div>
  </div>
</div>

`/dev-kit:ship` is the orchestrator and calls the others directly; each also stands alone.
`/dev-kit:land` is a discoverable entry point to ship's own merge verb, not a separate loop
step. And `/dev-kit:handle-task-tracking` appears twice for a reason: it opens the loop by
capturing work as issues, and ship keeps delegating to it for the whole run — opening the
tracking issue at plan time, flipping its status labels as phases pass, logging decisions. Three more sit deliberately outside this loop — `/dev-kit:dry-dock-overhaul`,
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

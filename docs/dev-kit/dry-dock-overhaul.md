---
title: dev-kit dry-dock-overhaul
---

# dry-dock-overhaul

Haul the whole repo out of the water and inspect every plank — an exhaustive,
always-human-triggered audit of the entire repository, not a diff. It is deliberately the
most expensive skill in the marketplace: reach for it rarely, and on purpose.

## Usage

```text
/dev-kit:dry-dock-overhaul                     # audit the whole repo
/dev-kit:dry-dock-overhaul plugins/castify/    # scope the audit to a subtree
```

Natural-language forms work too: *"dry dock overhaul this repo"*, *"audit the whole repo"*,
*"review every line"*, *"deep audit this codebase"*.

## What it does

One run, five phases, one severity-ranked report:

1. **Classify & scope** — confirm a git repo, resolve the scope (root or a subtree
   argument), and classify the repo's kind by reusing `generate-docs`'s sentinel-file
   classification.
2. **Inventory** (cheap/local tier) — build the unit map and grep-based candidates (dead
   exports, zero-reference files); candidates, not findings.
3. **Deep-dive per unit** — one agent per unit reads **every tracked file** and reports
   exceptions only, confirming or dismissing each candidate. `.gitignore`-excluded and
   untracked paths are the only exclusion; sampling never is.
4. **10,000-foot pass** (parallel with 3) — holistic lenses *discovered fresh* for this
   repo's shape (docs-site UX, test-suite architecture, naming consistency — not a fixed
   checklist), plus the three existing whole-repo skills run in full: `review-pr` (Mode C),
   `generate-docs`, and `pre-public-hardening`.
5. **Synthesis** — everything merged, deduped, and ranked on `review-pr`'s
   blocker → major → minor → nit scale, into one ephemeral report.

Every new dimension is report-only — nothing it finds gets auto-applied. The one exception
is `generate-docs`'s own native writes, which is why the run happens inside a dedicated
worktree: the human reviews that diff separately. The report itself is never committed;
findings worth keeping get filed via `handle-task-tracking` by a human.

## When to reach for it

Occasionally, on your own schedule, and always by hand — no other skill invokes this one
automatically, and it sits entirely outside `ship`'s loop. Judging a diff is `review-pr`;
this judges the repo as it stands today, with no diff in sight. Expect the longest,
costliest run in the marketplace: exhaustive coverage is the whole premise, so being
cost-conscious means routing mechanical work to cheap tiers, never skipping files.

For a first run against a repo, stage a dry run scoped to one subtree before committing to
a genuine whole-repo pass.

!!! warning "A subtree scope doesn't make the whole run cheap"
    The path argument narrows Phases 0–3 and `review-pr` — but `generate-docs` and
    `pre-public-hardening` always run at full whole-repo scope regardless (docs reconcile
    whole-against-whole; secrets are a whole-history concern). Even a scoped dry run pays
    their full cost.

## Related

- [`review-pr`](review-pr.md) — its whole-repo Mode C is one of the four passes; use it
  alone when you're judging a diff, not the whole repo.
- [`generate-docs`](generate-docs.md) — runs natively as a sub-pass and is the one thing
  that writes to disk during an overhaul.
- [`pre-public-hardening`](pre-public-hardening.md) — the whole-history secret/license
  sub-pass, always at full scope.

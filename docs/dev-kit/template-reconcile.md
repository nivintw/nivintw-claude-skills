---
title: dev-kit template-reconcile
---

# template-reconcile

For Copier-managed repos (`.copier-answers.yml` present): closes the seam between what the
upstream template provides and what the repo does with it. Without active attention, infra
goes silently missing after a `copier update`, local edits to template-owned files never wash
back, and divergences pile up undocumented.

## Usage

```text
/dev-kit:template-reconcile     # reconcile this repo against its pinned template
```

Natural-language forms work too: *"adopt the copier template"*, *"reconcile against the
template"*, *"did the template infra come over?"*, *"should this be ported upstream?"*.

## What it does

Three concrete responsibilities:

1. **Adoption/update audit** — reads `_src_path` and the pinned `_commit` from
   `.copier-answers.yml`, materializes the template's tree at that commit, and walks its
   provided files against the repo. Output is a checklist: **landed / intentionally-skipped /
   MISSING** — nothing is allowed to be silently absent, and MISSING is the finding that
   warrants action.
2. **Synced-files test + divergence registry** — scaffolds two per-repo artifacts: a tracked
   registry listing every file that intentionally differs from the template (one-line reason
   each), and a test (matching the repo's existing framework, e.g. `bats`) asserting that
   everything else is byte-identical to the template at the pinned `_commit`. The test runs
   in CI and fails when a file drifts unintentionally.
3. **Upstream-port prompt** — when a diff touches a template-owned file that isn't in the
   registry, prompts to file the same change upstream in the template repo so it washes back
   on the next `copier update` instead of stranding a local divergence. The filing itself
   reuses `handle-task-tracking`'s cross-repo flow.

## When to reach for it

Right after a copier adoption or `copier update` — to verify the result landed complete — or
whenever a template-owned file was edited locally and you want to know if it should go
upstream. What it is **not**:

- **Not a replacement for `copier update`** — copier still does the merge and re-renders
  templates; this skill verifies the result, it never runs copier itself.
- **Not automatic upstreaming** — it prompts when a template-owned file is edited; the human
  decides whether to file.

!!! note "The registry is the boundary"
    A file absent from the divergence registry is expected to match the template exactly —
    that's the invariant the synced-files test enforces. An "intentionally skipped" audit
    entry with no documented reason in the registry is treated as a potential gap, not a
    pass.

## Related

- [`handle-task-tracking`](handle-task-tracking.md) — owns the cross-repo issue filing the
  upstream-port prompt invokes; this skill never reimplements it.
- [`ship`](ship.md) — a ship run is where template-owned files typically get edited, and
  where the upstream-port prompt earns its keep.

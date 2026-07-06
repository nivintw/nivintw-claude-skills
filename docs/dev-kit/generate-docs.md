---
title: dev-kit generate-docs
---

# generate-docs

Reconcile the entire documentation set against the entire codebase, then author the docs that
are wrong, missing, or badly communicated. Not a template engine printing manifests — Claude
is the author, the code is the source of truth, and every run re-derives what the docs should
say. (This page was authored by it.)

## Usage

```text
/dev-kit:generate-docs
```

Natural-language forms work too: *"generate the docs"*, *"refresh the docs"*, *"reconcile
the docs"*, *"publish to GitHub Pages"*.

## What it does

One reconciliation pipeline, whole-against-whole every run — never a "what changed since
last time" diff:

1. **Inventory & classify** — confirm `mkdocs.yml` exists, then classify the repo kind by
   sentinel files: marketplace, Copier template, library/CLI, or generic. Kind seeds the
   site shape; it never gates.
2. **Map the codebase** — fan out cheap read-only mappers, one per slice, so the whole repo
   is covered without blowing context.
3. **Reconcile into a work-list** — drift (docs contradict code), omission (surface with no
   docs), communication (covered but badly), and `nav:` gaps. Accurate, well-said pages are
   left byte-identical — that's what keeps the diff reviewable.
4. **Author** — write Markdown pages + the `mkdocs.yml` `nav:` tree shaped to the repo kind,
   and reconcile `README.md` as a concise entry point, not a site dump.
5. **Validate for real** — static link/nav checks, then `mkdocs build --strict`, then drive
   the *built* site from `file://` with Playwright: load pages, check assets and console,
   and click the interactive bits (tabs, embedded players) — a class of bug only
   interaction catches.
6. **Report** — emit a human-facing reconciliation report of what drifted, what was
   missing, and what was restructured and why.

## When to reach for it

It runs by default as Phase 5 of [`ship`](ship.md)'s flow, and stands alone whenever docs
need to catch up to code — a docs-only refresh needs no ship run. What a run never touches:

- **Source code** — read-only source of truth; where prose and code disagree, the prose is
  wrong.
- **Dev-only specs** — `docs/superpowers/**` shares the `docs/` tree but is never
  reconciled or rewritten.
- **The MkDocs mechanism** — default ownership of `mkdocs.yml` is the `nav:` list only; the
  theme block and `markdown_extensions` are template-owned. The one deliberate exception:
  a "make the site excellent" request may enable a structural tool the content now needs
  (a first grid, first tabs, first diagram) — and proposes folding it upstream into
  copier-everything rather than stranding a local divergence.

!!! note "Requires `mkdocs.yml` to already exist"
    This skill authors content and navigation, not the MkDocs scaffolding (theme, asset
    wiring, the Pages build workflow). No `mkdocs.yml` means the run stops and says so —
    the fix is `copier update` (or a hand-authored minimal `mkdocs.yml`), not this skill.

## Related

- [`ship`](ship.md) — runs this automatically as Phase 5, so shipped code never outruns its
  docs.
- [`template-reconcile`](template-reconcile.md) — the MkDocs mechanism this skill relies on
  is template-owned; this keeps it in sync with copier-everything.
- [`handle-task-tracking`](handle-task-tracking.md) — the cross-repo filing used to propose
  a structural-tool addition upstream instead of leaving a local-only divergence.

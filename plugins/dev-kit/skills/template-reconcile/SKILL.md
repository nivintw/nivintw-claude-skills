---
name: template-reconcile
description: >-
  This skill should be used when the user asks to "adopt the copier template", "reconcile
  against the template", "after a copier update", "did the template infra come over?", "are
  our template-owned files in sync?", or "should this be ported upstream to the template?". It
  reconciles a copier-managed repo against its upstream template: verifying no template infra
  was silently dropped on adoption or update, scaffolding a divergence registry and
  synced-files test into the repo, and prompting to file upstream when a change touches a
  template-owned file. A companion to copier's own `copier update` — it does NOT run copier
  itself. The upstream-port prompt reuses `/dev-kit:handle-task-tracking`'s cross-repo filing
  rather than reimplementing it. Reach for it whenever a `copier update` has just run, a
  template-owned file was edited locally, or you want to verify the repo's template infra is
  complete and documented.
---

# template-reconcile

A copier-managed repo (`.copier-answers.yml` present) has a seam between what the upstream
template provides and what the repo does with it. Without active attention, things slip through
that seam: infra silently absent after a `copier update`, local edits to template-owned files
that never wash back, divergences that accumulate without documentation until nobody can tell
what's intentional from what's accidental. This skill closes that seam with three concrete
responsibilities.

## Adoption & update — no silent drops

On copier adoption or a `copier update`, enumerate the infra the template provides and verify
each piece either landed in the repo or was deliberately skipped — never silently absent.

1. Read `.copier-answers.yml` for `_src_path` (here, `gh:nivintw/copier-everything`) and the
   pinned `_commit` (e.g. `v1.4.0`) — these are read from the file, not assumed.
2. **Render the template with copier — do NOT diff against the raw template tree.** The raw
   tree can't be mapped 1:1 to repo paths: it ships `.jinja`-suffixed files, Jinja-*conditional*
   file/dir names, `_exclude` skips, and usually a `_subdirectory` root, so a naive
   `template/<path>` → repo-path diff either mismatches or silently skips on any non-trivial
   template. Use copier itself — `copier recopy --pretend` / `copier update --pretend` — to
   produce **what the template actually generates for this repo's answers**, with `.jinja`,
   conditionals, `_exclude`, and `_subdirectory` all resolved. This is *using* copier to render,
   not reimplementing its rendering. (Read `_subdirectory` from the template's `copier.yml` if
   you need to reason about the source layout directly.)
3. Compare the **rendered** file set against the repo: for each file the template renders, check
   whether it's present (tests/ infra, config, CI workflows, gate hooks, scripts). Add a
   **positive control** — assert the render actually produced files — so a broken or empty render
   can't masquerade as "nothing missing."
4. Output a checklist: **landed / intentionally-skipped / MISSING**. MISSING is the finding
   that warrants action. "Intentionally skipped" must have a documented reason (see the
   divergence registry below); absent one, treat it as a potential gap.

The motivating failure this guards against: template infra that *should* have come over on
adoption didn't, silently, and nobody noticed until it was needed.

## Synced-files test + divergence registry

Some template-owned files should be byte-identical to the template at the pinned `_commit`.
Others are intentionally divergent. This section scaffolds two artifacts into the consuming
repo to keep that distinction explicit and machine-checkable.

**Divergence registry** — a tracked file (e.g. `tests/template-divergences.txt`) listing
every file that intentionally differs from the template, each with a one-line reason. The
invariant: a file absent from the registry is expected to match the template. Without this,
divergences accumulate silently; with it, they're documented, auditable, and the test below
can enforce the boundary.

**Synced-files test** — a `bats` test (matching this repo's existing framework; see `tests/`)
asserting that files meant to be byte-identical to the template actually match it at the pinned
`_commit`. Files in the registry are explicitly exempted. The test runs in CI via the gate and
fails when a file drifts unintentionally.

Model the test on whatever consistency-test pattern the repo already has. In this marketplace
that's `tests/check_plugin_release_wiring.bats` + `scripts/check_plugin_release_wiring.py` (a
`setup()`/`teardown()` sandbox plus a real-tree assertion over the actual repo); in another
consuming repo, fall back to its existing bats (or other) tests. For a synced-files test, the
real-tree assertion **renders the template with copier at `_commit`** (so `.jinja`,
conditionals, `_exclude`, and `_subdirectory` are handled — never a raw-tree byte-diff), diffs
each candidate against the *rendered* copy, and fails if they differ and the file isn't in the
registry. It must **fail loudly, not vacuously green**: assert the candidate set is non-empty,
assert the render produced files (positive control), and make a failed clone/render fail the
test rather than leaving an empty render dir that silently skips every comparison. A
copy-pasteable registry format and bats skeleton live in
[`reference/synced-files-test.md`](reference/synced-files-test.md).

This skill **scaffolds these into the target repo** — it reads the repo's existing conventions,
proposes the registry location and test structure, writes them to the right paths, and verifies
they pass. It does not ship a one-size-fits-all generic script; the registry and test are
per-repo artifacts that live in the repo.

## Upstream-port prompt

When a change in a copier-managed repo touches a **template-owned file** — one that came from
the template and isn't in the divergence registry — prompt to file the same change upstream in
the template repo so it washes back on the next `copier update` instead of stranding a local
divergence.

Reuse `/dev-kit:handle-task-tracking`'s cross-repo issue filing (see the "File it in the right
repo" guidance there). File the follow-up against `nivintw/copier-everything` (the `_src_path`)
using the GitHub MCP's explicit `owner`/`repo` parameters, then report back a typed, glossed
cross-repo link — `[nivintw/copier-everything#N](url)` — so the user can click through. Do NOT
reimplement cross-repo filing here.

The standing practice this operationalizes: "OK to edit a template-owned file for a clean
consolidation IF you file the same change upstream so it washes on the next update." This skill
automates the prompt; the human decides whether and how to file it.

The prompt fires when: (a) a diff touches a file the template provides and (b) that file isn't
in the divergence registry. If it is in the registry, the divergence is documented and no prompt
is needed.

## What this is not

- **Not a replacement for `copier update`** — copier still does the merge, resolves conflicts,
  and re-renders templates. This skill verifies the result; it doesn't drive copier.
- **Not automatic upstreaming** — it prompts when a template-owned file is edited; the human
  decides whether to file upstream.
- **Not cross-repo issue filing** — that capability lives in `/dev-kit:handle-task-tracking`.
  This skill invokes it; it doesn't reimplement it.
- **Not copier's templating** — this skill inspects and gates the output; copier produces it.

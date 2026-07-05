---
name: generate-docs
description: >-
  This skill should be used when the user asks to "generate the docs", "build the docs
  site", "refresh the docs", "reconcile the docs", "publish to GitHub Pages", or "make a
  docs page" for a repo. It reconciles the WHOLE documentation set against the WHOLE
  codebase every run — catching both drift (docs that no longer match the code) and omission
  (code with no docs) — and authors a bespoke, human-first MkDocs Material site (a landing
  page plus per-topic pages, as Markdown + a `mkdocs.yml` nav tree) shaped to whatever the
  repo is: a Claude Code plugin marketplace, a Copier template, a library or CLI, or a
  generic project. Code is the source of truth and Claude authors the prose. Requires the
  repo to already have an `mkdocs.yml` (from the copier-everything template's
  `include_docs_site` feature, or hand-authored) — reach for it to create, refresh, or
  reconcile a repo's docs content, including as part of shipping a change (dev-kit:ship runs
  it automatically).
---

# generate-docs

**Reconcile the entire documentation set against the entire codebase, then author the docs
that are wrong, missing, or badly communicated.** This skill is not a template engine that
prints manifests — *you* are the author. Every run reads the whole repo and the whole
existing docs set, decides what no longer tells the truth and what was never told at all,
and writes Markdown pages + a `mkdocs.yml` `nav:` tree (plus the `README.md`) shaped to that
specific repo.

It runs as Phase 5 of `dev-kit:ship`, and stands alone whenever docs need to catch up to
code.

**Requires `mkdocs.yml` to already exist.** This skill authors content and navigation; it
does not scaffold the MkDocs mechanism itself (theme, `extra_css`/`extra_javascript` wiring,
the Pages build workflow) — that's the copier-everything template's `include_docs_site`
feature. If a repo has no `mkdocs.yml`, stop and say so rather than authoring content with
nowhere to render: the fix is `copier update` (or, outside the fleet, hand-authoring a
minimal `mkdocs.yml`), not something this skill does for you.

## Core philosophy

1. **Whole-against-whole, every run.** Reconcile the *entire* docs set against the *whole*
   codebase. Never diff "what changed since last time" — re-derive the truth from the code
   each run, so nothing escapes the check.
2. **Catch drift and omission.** Stale prose (docs say X, code does Y) and undocumented
   surface (code with no docs) are *both* first-class findings.
3. **Humans first, LLMs second.** Optimize every page for human comprehension; machine
   readability is secondary.
4. **Always ask "is this the best way to communicate this?"** You have editorial authority
   to restructure, re-level, and re-present — a table, a diagram, a callout, a worked
   example — whatever communicates best.
5. **Code is the single source of truth.** Where prose and code disagree, the prose is
   wrong. Fix the prose; never invent behavior the code doesn't have.
6. **Analyze the whole, rewrite only what's wrong.** Whole-codebase *analysis* every run,
   but only drifted / missing / poorly-communicated content gets *rewritten*. Accurate,
   well-communicated pages are left **byte-identical** — that is what keeps the diff small
   and reviewable. "Reconcile whole" means *evaluate* whole, not *regenerate* whole.
7. **Pre-existing drift is yours to fix — "it was already like that" is never an excuse.**
   When the run surfaces something wrong — a stale number, a broken link, a section that no
   longer matches the code — fix it, even if it predates this run and you didn't introduce it.
   A docs refresh is broad by nature: every drifted/missing/miscommunicated item *within the
   docs set* is in scope, not just whatever a recent change touched. This sharpens #2, it does
   not soften #6: you still leave accurate pages byte-identical — the license is to *fix what's
   wrong*, never to regenerate what's already right.

## The reconciliation pipeline

One run = one pass through these stages. For a small repo, collapse them into a single
inline pass; for anything larger, fan out so the whole codebase is actually covered without
blowing context. Route mechanical mapping to a cheap tier, keep the reconciliation judgment
and the final synthesis with the driver.

### Stage 0 — Inventory & classify

Find the repo root (`.git`). Confirm `mkdocs.yml` exists at the root — if not, stop (see
above). Walk the tree and **classify the repo kind** by sentinel files — this *seeds* the
site shape, it never gates:

- `.claude-plugin/marketplace.json` → **marketplace**
- `copier.yml` → **Copier template**
- a package manifest (`pyproject.toml`, `package.json`, …) → **library / CLI**
- otherwise → **generic**

Locate the existing docs surface to reconcile against: `mkdocs.yml`'s `docs_dir` (default
`docs`) and its current `nav:` tree, the Markdown pages under it, and `README.md`. The
theme, `extra_css`/`extra_javascript` wiring, and any vendored assets (e.g. the
asciinema-player, per castify's `embedding.md`) are **template-owned or hand-wired
separately** — read them to know what's available, but this skill doesn't author them.

### Stage 1 — Map the codebase (cheap tier, parallel)

Fan out read-only mapper subagents (e.g. `Explore`), one per subsystem/slice. Each returns
a **structured facts model** for its slice: the public surface (commands, APIs, skills,
config keys, flags), behavior, examples, and what *should* be documented. This is how the
whole codebase gets covered when it doesn't fit one context.

### Stage 2 — Reconcile → work-list (keep with the driver)

Diff the facts model against the current site + `README.md`. Produce a **work-list**:

- **Drift** — docs/README contradict the code → rewrite.
- **Omission** — code surface with no coverage → author.
- **Communication** — covered but poorly (wrong altitude, buried, better as a table/diagram)
  → restructure.
- **Nav needs** — a new or moved page has no `nav:` entry, or a `nav:` entry points at a page
  that no longer exists.
- Everything accurate and well-said → **leave byte-identical**.

### Stage 3 — Author (mid tier, parallel)

One author per work-listed page: write/update **Markdown**, choosing the best structure for
that topic (tables, callouts via Material's admonition syntax, code blocks — whatever
communicates best; raw HTML is also fair game since it passes through Markdown unmodified,
e.g. castify's `<figure class="cast">` embeds). Maintain `mkdocs.yml`'s `nav:` tree to match
— add entries for new pages, remove entries for deleted ones, reorganize sections when that
communicates better. Reconcile `README.md` **as a concise entry point** — keep it the tight
GitHub landing, not a dump of the whole site.

Only touch `mkdocs.yml`'s `nav:` list (and, rarely, append an `extra_css`/`extra_javascript`
entry when a page newly needs a vendored asset, e.g. its first embedded cast). The theme
block and everything else in `mkdocs.yml` is template-owned — leave it alone; a needed
change there belongs upstream in copier-everything, not as a local edit here.

### Stage 4 — Validate

Run the docs validator on the output (broken internal links, missing anchors, nav
completeness, non-portable absolute refs):

```bash
uv run "${CLAUDE_PLUGIN_ROOT}/skills/generate-docs/scripts/check_docs.py" .
```

(Pass the repo root — it locates `mkdocs.yml` and reads `docs_dir` from it.) Exit 0 = clean;
1 = violations (one per line); fix and re-run until clean. Licensing, linting, formatting,
markdown, TOML, and secrets are **the repo's existing gate's job** (see *Licensing &
tooling*) — don't re-implement them here.

**Then build the site and confirm it actually renders.** `check_docs.py` catches broken
links, missing anchors, and orphaned pages *statically* against the Markdown source, but
only a real build catches a broken `nav:` reference, a plugin misconfiguration, or an asset
that fails to resolve once MkDocs processes it — the breakage the user otherwise discovers
only *after* publishing:

```bash
uvx --with mkdocs-material mkdocs build --strict -d /tmp/mkdocs-build-check
```

`--strict` turns MkDocs' own warnings (broken `nav:` entries, unresolved cross-references)
into a hard failure. Then smoke-check the **built** output (not the raw Markdown source)
from a `file://` path with no server, using the available Playwright tooling (the
`mcp__playwright__*` MCP, or the Playwright CLI):

- **Pages load.** Navigate to the built `index.html` and each key per-topic page it links
  (`mcp__playwright__browser_navigate`); confirm each renders content, not a blank page or an
  error.
- **Assets and embeds resolve.** Inspect the browser's network requests and console for failed
  loads (`mcp__playwright__browser_network_requests`,
  `mcp__playwright__browser_console_messages`) — over `file://` a missing local asset surfaces
  as `ERR_FILE_NOT_FOUND`, not an HTTP 404. Everything the page references — the theme's CSS/JS,
  search, embedded media (e.g. asciinema casts) — must actually load, not just be referenced.

A blank page, a failed asset load, or a missing embed is a **hand-off blocker**: fix the
source and rebuild. This is the whole point of doing it from `file://` *before* publishing —
the reusable build-and-deploy workflow (`repo-management`) serves this same build output, so
if it's broken locally it's broken live. It's a **load/parity smoke check, not visual
regression** — confirm pages and assets resolve; don't diff pixels. If no Playwright tooling
is available, say so and fall back to the static check + `mkdocs build --strict` rather than
skipping silently. If `uvx`/network access isn't available, say so and fall back to the
static check alone.

### Stage 5 — Synthesize + reconciliation report

Emit a human-facing **reconciliation report**: what drifted, what was missing, what you
restructured and *why*. This is the review aid that makes a Markdown/`nav:`/README diff
tractable. Print it in the run; when running inside `dev-kit:ship`, also save it under
ship's run dir (`"$(git rev-parse --git-dir)/ship/"`) so it survives for the human's review
without ever landing in the working tree. It is **not** part of the published site.

## Repo-kind shaping (zero-config)

Classification seeds a starting shape; then shape to what the repo actually contains. No
config file, no persisted structure manifest to drift — re-derive structure from the code
(the `nav:` tree in `mkdocs.yml` is the one exception, since MkDocs needs it to render
navigation — but it's derived from and kept in sync with the code each run, not a separate
source of truth).

- **Marketplace** — landing overview + a page per plugin (manifest facts,
  skills/commands/agents, rendered README). Authored, not mechanically templated, so it can
  communicate better.
- **Copier template** — landing + a template-reference section surfacing `copier.yml`
  questions/defaults and the modules/structure the template generates.
- **Library / CLI** — landing + install/usage + an API or commands reference from the
  public surface.
- **Generic** — landing from the README + the repo's own `docs/*.md` and key prose rendered
  into a coherent site, plus reference sections for whatever public surface exists.

**Principles override the templates.** Kind is a starting point, never a straitjacket: a
library-and-CLI gets both; a marketplace with rich guides gets a guides section; an
unrecognized repo degrades to generic rather than failing.

## What this skill owns (and what it never touches)

A run writes:

- **Markdown pages** under `mkdocs.yml`'s `docs_dir` (default `docs/`) — landing page,
  per-topic pages, hand-written prose guides,
- `mkdocs.yml`'s **`nav:` list** (and, rarely, an appended `extra_css`/`extra_javascript`
  entry for a newly-needed vendored asset),
- the repo **`README.md`** (reconciled as a concise entry point).

A run **never**:

- modifies source code — it is the read-only source of truth,
- touches `mkdocs.yml`'s theme block, plugin config, or anything outside `nav:` —
  template-owned; a needed change belongs upstream in copier-everything,
- touches the Pages build workflow or Pages configuration — see *Publishing* below.

**Excluded from reconciliation:** developer specs and internal design docs — concretely
`docs/superpowers/**` (specs and plans). The published site and dev specs share the `docs/`
tree; this skill owns the former, not the latter. Never rewrite or clobber them.

## Licensing & tooling

Do **not** hand-manage SPDX or re-create checks the repo's gate already runs.

- Every file this skill writes is **Markdown**, covered via **`REUSE.toml`**, never an
  inline header (frontmatter-first — a line-1 SPDX comment would break YAML frontmatter).
- Run the repo's existing gate (e.g. `uvx prek run --all-files`) and `reuse lint` to enforce
  licensing/lint/format. The only script this skill ships is the docs validator above.

## Publishing (GitHub Pages)

This skill's job ends at authored content — it does not configure Pages itself. Publishing
is two template-owned pieces, both outside this skill:

- the copier-everything template's thin caller workflow (`.github/workflows/docs.yml`),
  which delegates the actual build-and-deploy to `repo-management`'s reusable
  `workflow_call` workflow (one `mkdocs`/`mkdocs-material` version pin for the whole fleet),
- the repo's Pages source, declared as `pages: {enabled: true, build_type: workflow}` in its
  `repo-management` config file and applied via `PagesManager`.

If either is missing, that's a template-adoption or Pages-config gap to fix at that layer —
not something to work around by hand-calling the Pages API from here.

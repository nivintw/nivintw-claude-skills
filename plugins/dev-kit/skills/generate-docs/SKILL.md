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
4. **Always ask "is this the best way to communicate this?" — and mean it.** You have
   editorial authority to restructure, re-level, and re-present. This is not a rhetorical
   nicety to nod at before defaulting to plain paragraphs — it has concrete, recurring
   answers (see *Structural tools*, below) that a run should actually reach for when the
   content shape calls for them, not just when told to.
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

## Structural tools

Material ships far more than paragraphs, tables, and admonitions — reach for the tool that
matches the content's actual shape, not the one that's easiest to default to. Each earns its
place with a concrete need already present in the content; don't add one speculatively.

- **Grid cards** (`<div class="grid cards" markdown>` + attr_list) — a set of peer items
  each worth a glance and a link (a landing page's list of plugins/modules/packages) reads
  far better as a card grid with a one-line blurb each than a bulleted list. Needs
  `attr_list` + `md_in_html` in `markdown_extensions`. Two finish details users notice:
  make the **whole card** the click target, not just the title text (stretched-link
  pattern: the title link grows an `::after` overlay with the card as positioned ancestor;
  other links in the card stay clickable above it via `z-index`), and when the item count
  leaves a dead cell in the grid (3 cards, 2 columns), let the last card span the row
  (`li:last-child:nth-child(odd) { grid-column: 1 / -1 }`) so the block closes cleanly.
- **Content tabs** (`=== "label"`, `pymdownx.tabbed` with `alternate_style: true`) — when a
  reader picks exactly one of several equivalent paths (marketplace install vs. local clone;
  per-OS commands), tabs let them see their own path without scanning past the others.
  **Real footgun:** tab content nests like a list continuation (4-space indent) — a linter
  that doesn't know this convention (rumdl's MD046, in this fleet) will "fix" the indentation
  by wrapping the tab's prose in stray fences, destroying the structure. If the repo's
  markdown linter flags this, that's a false positive to suppress for the affected files
  (`per-file-ignores`), not a real formatting problem to fix in the content.
- **A relationship diagram (hand-built HTML/CSS, not Mermaid)** — when several
  commands/components delegate to, feed into, or gate each other (an orchestrator calling
  sub-skills, a pipeline of stages), *that relationship is the actual point* and prose alone
  under-sells it — a reader skimming separate per-item pages sees loosely related items, not
  the system. For the small graphs docs actually need (≲10 nodes), **hand-build the diagram
  as HTML/CSS styled from the theme's own CSS custom properties** rather than reaching for
  Mermaid: generated Mermaid output reads as generated (boxy nodes, awkward routing, styling
  you fight rather than own), and it has concrete failure modes — `click` directives wrap
  node labels in `<a>` so the site's link color silently overrides the diagram's declared
  text color (theme-dependent, uncontrolled contrast), edge labels hardcode a light
  background while inheriting the page's text color (illegible in a dark scheme), and
  Material force-shrinks wide SVGs until text is unreadable. The hand-built component gets
  all of this right by construction: nodes styled in the site's existing visual language
  (e.g. the inline-code chip look, if the items are commands), node text/fills from theme
  variables so both color schemes work without theme-specific rules, at most one
  accent-emphasized node (the orchestrator), nodes as real links, connectors via
  borders/pseudo-elements, and `overflow-x: auto` on the container for narrow screens.
  Mermaid remains acceptable only for genuinely large graphs where auto-layout is
  unavoidable — and then never combine `click` directives with colored `classDef` fills.
  Either way, draw the diagram from what the code actually does (which commands genuinely
  call which), never from an idealized architecture.
- **Icons** (`pymdownx.emoji` scoped to Material's own `material.extensions.emoji` index —
  `:material-*:`/`:octicons-*:` glyphs, never literal emoji faces) — a small, real aid to
  scanning a card grid or a nav tree; don't reach for these just to decorate a heading with
  no comparison/scanning purpose.
- **Tables** — comparing several peers across the same few dimensions (a command reference's
  name + one-liner, a feature matrix). Don't use a table for a single flowing narrative.
- **Admonitions** (`!!! note`/`!!! tip`, `??? note` for collapsible) — a caveat, a design
  rationale, or a "how this backstops X" aside that would otherwise interrupt the main
  narrative's flow. Not a substitute for actually explaining the main content well.

**Treat the repo's markdown auto-fixer as part of the docs pipeline — and audit what it
did.** Docs-site conventions trip general-purpose markdown linters in predictable ways, and
an auto-fix can silently destroy structure: a frontmatter `title:` can count as an implicit
H1 so the fixer demotes every real heading on the page (MD025-style); adjacent italic runs
(`*"try this"*, *"or this"*`) can misparse so the fixer deletes the separator spaces
(MD037-style); tab-content indentation gets rewrapped in stray fences (the MD046 case
above). Suppress these per-file for the docs tree — and make sure the glob actually covers
**subdirectories** (`docs/*.md` silently misses `docs/section/*.md`; a pinned linter version
may not support `**`, so add explicit per-subdirectory globs when in doubt). After any gate
run whose markdown fixer modified docs files, diff those files before shipping — never
assume an auto-fix was harmless.

**When a topic has many enumerable, individually-substantial sub-items — commands,
subcommands, endpoints, config keys each with real detail to say — split into a landing page
(the overview, shared context, and a summary table linking out) plus one page per sub-item,
rather than defaulting to `###`-per-item on a single page.** A single page with a dozen
`###` sections reads as a wall of text regardless of a summary table sitting above it — a
reader still scrolls past everything else to reach the one item they want. Every serious
CLI/API reference with a double-digit-plus item count (Docker CLI, kubectl, `gh`, git) does
this for exactly that reason: a persistent sidebar entry per item beats a shared on-page TOC,
a search hit lands directly on the right page, and no page can grow long regardless of how
much detail any one item eventually needs. There's no hard threshold — a handful of short
items is fine as sections on one page; use judgment on when the "wall of text" feeling
actually kicks in, and default to splitting once it does rather than waiting to be asked.
Splitting was tried against collapsible sections (`??? note` per item, one page) and
rejected: collapsing hides the wall of text without removing it — reading more than one item
still means opening each individually, worse than the flowing page it replaces.

**Give every split-out page the same fixed anatomy.** Pages that each answer the same
questions in the same order read as *complete* even when short — which is what cures the
"now each subpage is bare" reaction without regrowing the wall of text. The anatomy that
works for command/reference pages (modeled on Docker/`gh`/git command docs): a 1–3 sentence
lead stating the item's role, **Usage** (a fenced block of invocation forms plus
natural-language equivalents), **What it does** (the distilled mechanics — a numbered list
for a sequence, a small table for modes/phases; pick the furniture that fits, keep the
section names fixed), **When to reach for it** (the judgment guidance: when, when not,
versus which sibling), and **Related** (2–4 links with a one-line why each). At most one
boxed admonition per page, reserved for *the* gotcha. Keep Related links **bidirectional**
— if A's page cites B, B's page almost always owes A a link back; sweep for one-way pairs.
Each page must distill from the item's actual source of truth, readable in under two
minutes — never paste the source wholesale.

**Don't lock into "minimal" as a permanent stance.** A conservative baseline is a reasonable
place to *start*, but re-ask "is this the best this can be?" as content accumulates — a site
that was appropriately simple at 3 pages can look sparse and under-designed at 15. A
structural tool added without a concrete need is speculative decoration; the same tool added
because the content now actually has the shape it fits is the right call, even if an earlier
run deliberately left it out.

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

**Default scope is `nav:`** (plus, rarely, an appended `extra_css`/`extra_javascript` entry
for a newly-needed vendored asset, e.g. a page's first embedded cast) — the theme block and
`markdown_extensions` are template-owned, and a routine reconciliation run leaves them alone.
**That default lifts when a *Structural tool* the content now needs isn't yet enabled** (a
first grid, first tabs, first diagram) — enable it locally in `markdown_extensions`/
`theme.features` rather than working around its absence, and separately propose folding the
addition into the copier-everything template baseline (via `dev-kit:handle-task-tracking`'s
cross-repo filing) so the rest of the fleet inherits it too, rather than stranding a local-only
divergence. This is a repo-wide-request-scale decision ("make the docs site excellent"), not
something to reach for on an ordinary drift-fixing run.

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
- **Interact with anything interactive — a load check alone misses this class of bug
  entirely.** Click every content tab (confirm the content actually swaps), click any
  embedded player's play control, click through an instant-nav transition (a link, not a
  fresh `navigate` call) and re-check the console — a hydration script that only runs on
  first load, not on an in-app transition, is a real and easy mistake. A real bug from
  authoring this exact site was only found this way: a cast embed's asset path resolved
  relative to the *source* file's directory, which is correct for a page served at
  `docs_dir` root but wrong the moment MkDocs' directory URLs (the default) put the page
  one level deeper — the built page loaded clean, zero console errors, and only 404'd
  *after clicking Play*. `mkdocs build --strict` and `check_docs.py` cannot catch this
  class of bug; only exercising the interaction does.
- **Judge rendering by painted pixels, in both color schemes.** Take actual screenshots
  (the Playwright CLI's `screenshot` command is the reliable, deterministic way) and *look*
  at them — a `getComputedStyle` probe can measure the wrong element in a cascade and
  report a color the paint never uses (an anchor's inherited link color beating a declared
  text color is exactly such a case). When the theme ships a light/dark toggle, verify
  styled components in **both** schemes: a hardcoded color that looks fine in one can be
  illegible in the other, and the scheme the site defaults to is the one every new visitor
  sees. And if the user says something looks wrong, their eyes are ground truth — reproduce
  what they see before arguing with instruments.
- **A known MkDocs/Material trap: `docs/404.md` is not what it looks like.** Material
  registers `404.html` as a "static template" rendered straight from the theme, not from a
  `docs/404.md` source — such a file builds without error and its content is silently
  discarded (verified: the static-template render overwrites the same output path
  afterward). A custom 404 page needs a real theme override (`theme.custom_dir` +
  `overrides/404.html`, extending `main.html`), not a docs page. If a run ever needs a
  custom not-found page, this is the mechanism — don't rediscover the discard-behavior the
  hard way.

A blank page, a failed asset load, a missing embed, or a click that does nothing/errors is a
**hand-off blocker**: fix the source and rebuild. This is the whole point of doing it from
`file://` *before* publishing — the reusable build-and-deploy workflow (`repo-management`)
serves this same build output, so if it's broken locally it's broken live. It's a **load and
interaction smoke check, not visual regression** — confirm pages, assets, and interactive
elements actually work; don't diff pixels. If no Playwright tooling is available, say so and
fall back to the static check + `mkdocs build --strict` rather than
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
  entry for a newly-needed vendored asset, or a new `markdown_extensions`/`theme.features`
  entry for a newly-needed *Structural tool* — see Stage 3's default-scope note),
- the repo **`README.md`** (reconciled as a concise entry point).

A run **never**:

- modifies source code — it is the read-only source of truth,
- touches the theme block or `markdown_extensions` on an *ordinary* reconciliation run
  (template-owned; the Stage 3 exception is for a deliberate "make this site excellent"
  request, not a drift-fixing pass) — and even then, proposes folding the addition upstream
  into copier-everything rather than leaving it a silent local divergence,
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

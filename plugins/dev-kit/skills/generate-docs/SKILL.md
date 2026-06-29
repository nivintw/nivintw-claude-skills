---
name: generate-docs
description: >-
  This skill should be used when the user asks to "generate the docs", "build the docs
  site", "refresh the docs", "reconcile the docs", "publish to GitHub Pages", or "make a
  docs page" for a repo. It reconciles the WHOLE documentation set against the WHOLE
  codebase every run — catching both drift (docs that no longer match the code) and omission
  (code with no docs) — and authors a bespoke, human-first static documentation site (a
  landing page plus per-topic pages) shaped to whatever the repo is: a Claude Code plugin
  marketplace, a Copier template, a library or CLI, or a generic project. Code is the source
  of truth and Claude authors the prose; the site renders identically from a local file://
  path and from GitHub Pages. Reach for it to create, refresh, or reconcile a repo's docs
  site, including as part of shipping a change (dev-kit:ship runs it automatically).
---

# generate-docs

**Reconcile the entire documentation set against the entire codebase, then author the docs
that are wrong, missing, or badly communicated.** This skill is not a template engine that
prints manifests — *you* are the author. Every run reads the whole repo and the whole
existing docs set, decides what no longer tells the truth and what was never told at all,
and writes a bespoke static site (plus the `README.md`) shaped to that specific repo.

It runs as Phase 5 of `dev-kit:ship`, and stands alone whenever docs need to catch up to
code.

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

Find the repo root (`.git`). Walk the tree and **classify the repo kind** by sentinel files
— this *seeds* the site shape, it never gates:

- `.claude-plugin/marketplace.json` → **marketplace**
- `copier.yml` → **Copier template**
- a package manifest (`pyproject.toml`, `package.json`, …) → **library / CLI**
- otherwise → **generic**

Locate the existing docs surface to reconcile against: a `docs/` site (if any), `README.md`,
hand-written guides, and the per-repo design system (`docs/style.css` + `docs/app.js`) if
present.

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
- **Design-system needs** — components the changed pages will require.
- Everything accurate and well-said → **leave byte-identical**.

### Stage 3 — Author (mid tier, parallel)

One author per work-listed page: write/update **semantic HTML composed against the per-repo
design system** (see below), choosing the best structure for that topic. Reconcile
`README.md` **as a concise entry point** — keep it the tight GitHub landing, not a dump of
the whole site.

### Stage 4 — Validate

Run the docs validator on the output (broken internal links + non-portable absolute refs):

```bash
uv run "${CLAUDE_PLUGIN_ROOT}/skills/generate-docs/scripts/check_docs.py" docs
```

Exit 0 = clean; 1 = violations (one per line); fix and re-run until clean. Licensing,
linting, formatting, markdown, TOML, and secrets are **the repo's existing gate's job** (see
*Licensing & tooling*) — don't re-implement them here.

**Then render the built site and confirm it actually loads.** `check_docs.py` catches broken
links and absolute refs *statically*, but only a real render catches a missing embed, a
relative path that resolves wrong in a browser, or a script/asset that fails to load — the breakage
the user otherwise discovers only *after* publishing. Open the built site from a **`file://`
path with no server** using the available Playwright tooling (the `mcp__playwright__*` MCP, or
the Playwright CLI) and smoke-check:

- **Pages load.** Navigate to `file://…/docs/index.html` and each key per-topic page it links
  (`mcp__playwright__browser_navigate`); confirm each renders content, not a blank page or an
  error.
- **Assets and embeds resolve.** Inspect the browser's network requests and console for failed
  loads (`mcp__playwright__browser_network_requests`,
  `mcp__playwright__browser_console_messages`) — over `file://` a missing local asset surfaces
  as `ERR_FILE_NOT_FOUND`, not an HTTP 404. Everything the page references — its stylesheet,
  scripts (`app.js`), the search index, embedded media (e.g. asciinema casts) — must actually
  load, not just be referenced. Check whatever the built pages link rather than a fixed list of
  filenames.

A blank page, a failed asset load, or a missing embed is a **hand-off blocker**: fix the
relative path or restore the embed and re-render. This is the whole point of doing it from
`file://` *before* publishing — GitHub Pages serves these same files, so if it's broken
locally it's broken live (the parity the *Publishing* section promises). It's a **load/parity
smoke check, not visual regression** — confirm pages and assets resolve; don't diff pixels. If
no Playwright tooling is available, say so and fall back to the static check rather than
skipping silently.

### Stage 5 — Synthesize + reconciliation report

Emit a human-facing **reconciliation report**: what drifted, what was missing, what you
restructured and *why*. This is the review aid that makes an HTML/README diff tractable.
Print it in the run; when running inside `dev-kit:ship`, also save it under ship's run dir
(`"$(git rev-parse --git-dir)/ship/"`) so it survives for the human's review without ever
landing in the working tree. It is **not** part of the published site.

## Repo-kind shaping (zero-config)

Classification seeds a starting shape; then shape to what the repo actually contains. No
config file, no persisted structure manifest to drift — re-derive structure from the code.

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

## The per-repo design system

This skill ships **no** `style.css` or `app.js`. Author a design system **into the repo**
and maintain it as a reconciliation target like everything else. Repos may look different
from each other; coherence is *within* a repo.

- **`docs/style.css`** — the visual contract: light/dark via `prefers-color-scheme`, system
  fonts (no required web fonts), and a small component vocabulary the pages compose (page
  shell + nav, cards, callouts, tables, code blocks, badges, breadcrumbs). Author it to the
  repo's character.
- **`docs/app.js`** — vanilla JS, vendored, no build step, no framework: client-side search
  (over a small index the run emits), section/collapsible nav, and a theme toggle. Load it
  as a classic `<script src="app.js">` with a relative path so it works from `file://` and
  Pages alike. (Sites need not run offline; external CDNs are permitted, but vendoring is
  the default since the design system is local anyway.)
- **Escape hatch** — pages compose the shared components by default, but add **page-local**
  styles/markup for a genuinely special case (a bespoke diagram, an interactive widget),
  layered on top of the system, not replacing it.
- **First run** bootstraps `style.css` + `app.js` + the site; **later runs** treat them as
  inputs to reconcile — extend for a new component, refactor if they've gone incoherent,
  else leave alone. Treat "a page reinvents styling a shared component already covers" as a
  consistency finding in Stage 2.

## What a run writes (and what it never touches)

A run writes:

- the **docs site** rooted at `docs/` (`docs/index.html`, per-topic pages, `docs/style.css`,
  `docs/app.js`, a small search index),
- the repo **`README.md`** (reconciled as a concise entry point),
- hand-written **prose guides** (Claude-owned, reconcilable).

A run **never** modifies source code — it is the read-only source of truth.

**Excluded from reconciliation:** developer specs and internal design docs — concretely
`docs/superpowers/**` (specs and plans). The published site and dev specs share the `docs/`
tree; this skill owns the former, not the latter. Never rewrite or clobber them.

## Licensing & tooling

Do **not** hand-manage SPDX or re-create checks the repo's gate already runs.

- Generated **HTML/CSS/JS** get inline SPDX headers from **`hawkeye`** (run by the gate);
  **Markdown** (`README.md`, guides) is covered via **`REUSE.toml`**, never inline
  (frontmatter-first). If a generated file type isn't covered by the gate's config, fix that
  config — don't inject headers from here.
- Run the repo's existing gate (e.g. `uvx prek run --all-files`) and `reuse lint` to enforce
  licensing/lint/format. The only script this skill ships is the docs validator above.

## Publishing (GitHub Pages)

Point Pages at the `docs/` folder on the default branch (no Jekyll/baseurl, so project-pages
URLs and local `file://` both resolve):

```bash
gh api -X POST repos/{owner}/{repo}/pages -f source[branch]=main -f source[path]=/docs 2>/dev/null \
  || gh api -X PUT repos/{owner}/{repo}/pages -f source[branch]=main -f source[path]=/docs
```

Or set it in the UI (Settings → Pages → Deploy from a branch → `main` / `/docs`). Commit the
generated `docs/` so Pages can serve it.

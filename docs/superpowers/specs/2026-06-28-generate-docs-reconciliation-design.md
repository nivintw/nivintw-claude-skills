# generate-docs: LLM-driven documentation reconciliation

**Status:** design approved (brainstorming), pending spec review
**Date:** 2026-06-28
**Tracking issue:** #23 (to be updated — this supersedes its original "make `build.py` repo-agnostic" framing)
**Plugin:** `dev-kit` · skill `generate-docs`

## 1. Summary

Reconceive `generate-docs` from a **deterministic generator** (a `build.py` that templates
Claude Code plugin-marketplace manifests into HTML) into an **LLM-driven documentation
reconciliation skill**: a set of instructions that drive Claude to read the *whole* codebase
and the *whole* existing docs set every run, detect and fix **drift** and **omission**, and
author a bespoke, human-first static docs site — for **any** repo, not just plugin
marketplaces.

This is a near-total rewrite of the skill. The manifest-only generator is retired; Claude
becomes the author.

## 2. Motivation

`generate-docs` was always intended to produce a docs site shaped to *any* repo, but the
implementation hard-wired it to plugin/marketplace manifests — it exits if there is no
`.claude-plugin/marketplace.json`, only understands the skills/commands/agents trichotomy,
and templates a fixed page-per-plugin layout. A repo without those manifests (e.g. the
Copier template `nivintw/copier-everything`, the blocked downstream consumer
`copier-everything#54`) gets nothing useful.

A deterministic script also *cannot* satisfy the deeper intent the maintainer articulated:

- **Catch drift** — docs say X, code does Y — is semantic comparison.
- **Catch omission** — code surface exists, no docs cover it — requires understanding code.
- **"Is this the best way to communicate this information?"** — is editorial judgment.

None are scriptable. They are LLM/agent work. Hence the reconception.

## 3. Core philosophy

1. **Whole-against-whole, every run.** A run reconciles the *entire* docs set against the
   *whole* codebase. It never inspects "what changed" / diffs commits — it re-derives truth
   from the code each time.
2. **Catch both drift and omission.** Stale docs *and* undocumented surface are both
   first-class findings.
3. **Audience priority: humans primary, LLMs secondary.** Every output optimizes for human
   comprehension first; machine-readability is a secondary consideration.
4. **Always ask "is this the best way to communicate this information?"** Claude has
   editorial authority to restructure, re-level, and re-present.
5. **Code is the single source of truth.** Where prose and code disagree, the prose is wrong.
6. **Analyze whole, rewrite only what's wrong.** Whole-codebase *analysis* every run, but
   only drifted / missing / poorly-communicated content is *rewritten*; accurate,
   well-communicated content is left byte-identical. "Reconcile whole" = *evaluate* whole,
   not *regenerate* whole.

## 4. Key decisions (resolved during brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Generator vs. LLM-driven | **LLM-driven reconciliation** (skill drives Claude; any script is a helper, not the brains) |
| 2 | Output artifact | **Claude writes the final HTML directly** (no intermediate Markdown source) |
| 3 | "Reconcile whole" semantics | **Analyze whole, rewrite only what drifted/missing/poorly-communicated** |
| 4 | Content ownership | **Code is sole source of truth; Claude owns 100% of the prose** |
| 5 | Visual consistency | **Per-repo design system + escape hatch** (option C); design system authored *into each repo*, NOT shipped by the skill; coherence within a repo, repos differ from each other |
| 6 | Blast radius | A run writes the **docs site + `README.md` + hand-written guides**; **source code is read-only** |
| 7 | Interactivity / packaging | **Folder** packaging; **vanilla JS** (search/nav/theme), vendored locally; sites **need not run offline** (CDNs permitted, vendored is the default) |
| 8 | Architecture | **Approach 3 — tiered reconciliation pipeline** (dials down to single-agent for small repos) |
| 9 | Configuration | **Zero-config** repo-kind autodetection; no config file |
| 10 | Licensing | **Do not hand-manage SPDX**; let `hawkeye` add headers (HTML/CSS/JS) and `REUSE.toml` cover Markdown |
| 11 | Validators | **Don't recreate template tooling**; rely on the existing `prek` gate; add only docs-specific checks |
| 12 | `build.py` | **Retired** (manifest-only generator superseded by Claude authoring) |

## 5. Architecture — tiered reconciliation pipeline

One run = one pass through the stages below. The pipeline is the recommended orchestration
(Approach 3); for a small repo the stages collapse into a single inline pass.

### Stage 0 — Inventory & classify (cheap)

- Find repo root via `.git`.
- Walk the tree; **classify repo kind** by sentinel files:
  - `.claude-plugin/marketplace.json` → **marketplace**
  - `copier.yml` → **Copier template**
  - a package manifest (e.g. `pyproject.toml`, `package.json`) → **library / CLI**
  - else → **generic**
- Classification *seeds* the site shape; it **never gates** — an unrecognized repo still
  gets a generic site.
- Locate the existing docs surface: a `docs/` site (if any), `README.md`, hand-written
  guides, and the per-repo design system (if present).

### Stage 1 — Map the codebase (cheap tier, parallel)

- Fan out `Explore`/mapper subagents, one per subsystem/slice.
- Each returns a **structured facts model** for its slice: public surface (commands, APIs,
  skills, config keys, flags), behavior, examples, what *should* be documented.
- This is how "the whole codebase" is covered without exceeding a single context.
- Small repos: collapse to a single inline mapping pass.

### Stage 2 — Reconcile (top tier, kept in the driver)

Diff the facts model against the current site + `README.md` to produce a **work-list**:

- **Drift** — docs/README contradict the code → mark for rewrite.
- **Omission** — code surface with no coverage → mark for authoring.
- **Communication** — covered-but-poorly (wrong altitude, buried, better as table/diagram)
  → mark for restructure.
- **Design-system needs** — components the changed pages require.
- Accurate-and-well-said content → **leave byte-identical**.

### Stage 3 — Author (mid tier, parallel)

- One subagent per work-listed page → write/update **semantic HTML against the per-repo
  design system**, choosing the best structure per topic.
- Reconcile `README.md` **as a concise entry point** (not a dump of the whole site).

### Stage 4 — Validate (deterministic, docs-specific only)

Only checks the existing gate does **not** cover:

- internal-link integrity (no broken intra-site links),
- `file://` + GitHub Pages dual-target (relative paths, local assets).

Licensing, linting, formatting, markdown, TOML, secrets → left to the existing `prek` gate.

### Stage 5 — Synthesize + reconciliation report

Emit a human-facing **reconciliation report**: what drifted, what was missing, what was
restructured and *why*. This is the review aid that makes noisy HTML/README diffs tractable.
Printed in the run and saved to a predictable, non-published location (e.g. under ship's run
dir, `"$(git rev-parse --git-dir)/ship/"`); it is **not** part of the published site.

**Cost posture:** whole-codebase *analysis* every run; cheap-tier mapping +
only-rewrite-what-drifted + parallelism keep cost bounded. Tiering matches `dev-kit:ship`.

## 6. Repo-kind shaping (zero-config)

Classification seeds a starting shape; Claude then shapes to what the repo actually contains.

- **Marketplace** — landing overview + a page per plugin (manifest facts,
  skills/commands/agents, rendered README). Today's behavior, now *authored* (so it can
  communicate better) rather than mechanically templated.
- **Copier template** — landing + a template-reference section surfacing `copier.yml`
  questions/defaults and the modules/structure the template generates. Unblocks
  `copier-everything#54`.
- **Library / CLI** — landing + usage/install + an API/commands reference from the public
  surface.
- **Generic** — landing from the README + the repo's own `docs/*.md` and key prose rendered
  into a coherent site, plus reference sections for whatever public surface exists.

**Principles override templates.** Kind is a starting point, never a straitjacket: a
library-and-CLI gets both; a marketplace with rich guides gets a guides section; mixed/unknown
degrades to generic rather than failing. Structure is re-derived from the code each run — no
config file, no persisted structure manifest to drift.

## 7. The per-repo design system

The skill ships **no** `style.css`/`app.js`. Claude **authors a design system into each
repo** (under the docs output, e.g. `docs/style.css` + `docs/app.js`) and maintains it as a
reconciliation target.

- **`style.css`** — the visual contract: light/dark via `prefers-color-scheme`, system fonts
  (no required web fonts), and a small component vocabulary (page shell + nav, cards,
  callouts, tables, code blocks, badges, breadcrumbs). Authored to *this* repo's character.
- **`app.js`** — vanilla, vendored, no build step, no framework: client-side search (over a
  small index the run emits), nav (collapsible/section), theme toggle. Loaded as a classic
  script with a relative `src` (works from `file://` and Pages).
- **Escape hatch** — pages compose shared components by default, but Claude may add
  **page-local** styles/markup for a genuinely special case (bespoke diagram, interactive
  widget), layered on top, not replacing the system.
- **First run** bootstraps `style.css` + `app.js` + the site; **later runs** treat them as
  inputs to reconcile (extend for new components, refactor if incoherent, else leave alone).
- **Consistency is enforced by reconciliation, not a shipped asset:** Stage 2 treats "page
  reinvents styling a shared component already covers" as a communication/consistency
  finding.

## 8. Outputs & blast radius

A run writes:

- the **docs site** (folder: `index.html`, per-topic pages, `style.css`, `app.js`, a small
  search index),
- the repo **`README.md`** (reconciled as a concise entry point),
- hand-written **prose guides** (Claude-owned, reconcilable),
- a **reconciliation report** (non-published).

A run **never** modifies source code (read-only source of truth).

**Out of scope for reconciliation:** developer specs and internal design docs — concretely
`docs/superpowers/**` (where this very spec lives) must be **excluded** from the
reconciliation scope so the skill does not rewrite or clobber them. (The published docs site
and dev specs share the `docs/` tree in this repo; the skill owns the former, not the latter.)

## 9. Licensing (REUSE / SPDX)

Do **not** hand-manage SPDX in the skill.

- Generated **HTML/CSS/JS** receive inline SPDX headers from **`hawkeye`** (run by the
  existing gate). If the repo's `licenserc.toml` does not yet cover the generated file types
  in the docs output, fix that config (reconcile with the `nivintw/scaffold` template) rather
  than hand-injecting headers in the skill.
- **Markdown** (`README.md`, guides) is covered via **`REUSE.toml`**, never inline
  (frontmatter-first rule).
- `reuse lint` must pass — via the gate, not via skill-owned logic.

## 10. What the skill ships (rewrite scope)

- **Rewritten `SKILL.md`** — reconciliation philosophy, Stage 0–5 pipeline, repo-kind
  shaping, design-system contract, audience priority, tiering/cost guidance. **Description
  updated** to drop "Not for general-purpose project or API docs" and broaden triggering to
  any repo.
- **Thin deterministic validators** (small scripts) for Stage 4 only: internal-link check,
  `file://`+Pages relative-path check. (A genuinely reusable helper such as the existing
  markdown→sanitized-HTML utility may survive as a helper if useful; its *generator* role is
  gone.)
- **Retire `build.py`** — the manifest-only generator and its SPDX-template machinery.

## 11. Migration & regression (issue #23 acceptance criteria)

- **AC #1 (no-manifest repo produces a usable site):** met by the generic path + repo-kind
  shaping.
- **AC #2 (output shaped to the repo):** met by Stage 0 classification + Section 6 shaping.
- **AC #3 (plugin-marketplace path keeps working):** this repo's own `docs/` will be
  **re-authored** by Claude on the next run — **not byte-identical** to today's templated
  output. "No regression" means the marketplace still gets a first-class site, *not*
  identical bytes. Called out explicitly because it changes how this repo's docs are produced.
- **AC #4 (dual-target file:// + Pages):** preserved (relative links, local assets;
  validated in Stage 4).
- **AC #5 (description broadened; ship Phase 5 no longer skips non-marketplace repos):**
  both done — `SKILL.md` description rewrite + `dev-kit:ship` Phase 5 edit.

## 12. Verification / testing

- **`bats`** tests for the deterministic validators (internal-link, dual-target checks).
- **Dogfood:** run the skill on **this repo** (marketplace) → confirm a coherent re-authored
  site + sane README reconciliation + report; spot-check a **Copier** layout for the
  generic/Copier path.
- **Full local gate** (`uvx prek run --all-files`) green.

## 13. Out of scope

- A full static-site-generator framework (MkDocs/Docusaurus replacement). The goal is the
  self-contained, Claude-authored docs site — not a new toolchain.
- The actual `copier-everything` docs content (the blocked companion issue).
- Cross-repo aggregation / a shared cross-repo design system (repos intentionally differ).
- Reconciling developer specs / internal design docs (`docs/superpowers/**`).

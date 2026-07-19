# generate-docs → Starlight, and the fleet docs migration

**Status:** design approved (brainstorming), pending spec review
**Date:** 2026-07-14
**Branch:** `chore/copier-update-v1.12.0` (PR nivintw/nivintw-claude-skills#176)

## Context & goal

The fleet's docs stack is **MkDocs Material**, scaffolded by the `copier-everything`
template's `include_docs_site`, authored/reconciled by the **generate-docs** dev-kit skill,
and built/deployed by a **reusable `workflow_call`** in `repo-management` that each repo
invokes via a thin `docs.yml` caller.

We are pivoting the whole stack to **Astro + Starlight**. The lever is **generate-docs**:
it is being rewritten from *"authors a MkDocs Material site; **requires** an existing
`mkdocs.yml`"* into a **self-sufficient** skill that can **create, update, or migrate** a
polished Starlight site — needing nothing pre-scaffolded in the target repo.

This effort is the enabling tool **plus** its first fleet-wide application: the 8 in-flight
copier-adoption PRs (each of which just scaffolded a *mkdocs* site) and this repo itself all
get migrated mkdocs → Starlight **before those PRs merge**.

## Scope

**In scope (coordinated together):**

1. **PR hygiene** on #176 — bring it to the latest `copier-everything` release and up to date
   with `main`.
2. **Ticket updates** — reframe every relevant MkDocs ticket as Starlight (dated pivot notes,
   not silent rewrites).
3. **generate-docs rewrite** — Starlight, self-sufficient (create/update/migrate), on #176.
   Includes its validator (`check_docs.py`), the SKILL body, its own doc page, and the bats
   tests.
4. **repo-management reusable docs workflow** — migrated MkDocs → `astro build`/Starlight
   (one PR there). It stays the fleet's single build/version pin; it is **not** retired.
5. **Fleet application** — run the rewritten generate-docs across this repo (#176, dogfood)
   and the 8 adoption PR branches, converting each mkdocs scaffold to Starlight before merge.
6. **castify embed guidance** — the `record-terminal-casts` skill ships **mkdocs-specific**
   asciinema-embed guidance (`<figure class="cast">` + vendored player + `extra_css/js`) in
   `plugins/castify/skills/record-terminal-casts/reference/embedding.md`. Starlight embeds
   casts via an Astro/MDX component, so this reference (and this repo's own cast-embedding
   pages) migrate too. Non-obvious scope — it's not just generate-docs.

**Follow-ups (tracked, not blocking):**

- `copier-everything` `include_docs_site` → scaffold Starlight instead of MkDocs, so **new**
  adoptions start correct (generate-docs migrates the transitional mkdocs scaffold meanwhile).
- Renovate/Dependabot need an npm/pnpm manager entry once `package.json` exists (template-owned
  config; rides along with the `include_docs_site` follow-up).

**Out of scope:**

- Any docs-content rewrite beyond what the framework migration requires (the skill still
  leaves accurate pages semantically intact; it changes their *mechanism*, not their truth).

## Design

### generate-docs: three modes

The skill detects the target repo's docs state and acts accordingly:

- **create** (no docs site present) — scaffold the entire Astro+Starlight project, author
  content, and write the publish caller. Greenfield, incl. outside the fleet.
- **update** (already Starlight) — the current whole-against-whole reconciliation, unchanged
  in spirit: re-derive truth from code, rewrite only drift/omission/miscommunication, leave
  accurate pages byte-identical.
- **migrate** (existing MkDocs) — the fleet's actual case. Convert, then retire the MkDocs
  mechanism.

The hard *"requires `mkdocs.yml`; stop if absent"* gate is **removed**. Absence now means
"create," not "stop."

### What `create` scaffolds (the mechanism the skill used to disclaim)

- `package.json` + committed `pnpm-lock.yaml` — `astro`, `@astrojs/starlight`.
  **Toolchain decision: pnpm** (strict resolution / no phantom deps, content-addressable
  store, fast; committed lockfile for CI determinism). CI uses `corepack`/`pnpm/action-setup`.
  Renovate handles pnpm natively; Dependabot has supported pnpm lockfiles since 2024, so the
  fleet's floor+ceiling model is intact.
- `astro.config.mjs` — Starlight integration + `sidebar` (the nav's new home). **Must set
  `site` + `base: '/<repo>/'`** for project Pages (`nivintw.github.io/<repo>/`) — the #1
  Astro-on-Pages footgun: a wrong/absent `base` builds clean locally but 404s every asset and
  internal link once deployed under the subpath. generate-docs sets this per-repo; the
  Playwright check must exercise the site *under its base path*, not just at root.
- `src/content/docs/**` (+ `src/content.config.ts` / content collection config), `index.mdx`
  landing page.
- `.gitignore` additions: `node_modules/`, `dist/`, `.astro/`.
- `.github/workflows/docs.yml` — a **thin caller** delegating to repo-management's reusable
  Astro build+deploy `workflow_call` (see *Publishing*).
- `tsconfig.json` as Starlight expects.

### `migrate` — MkDocs → Starlight mapping

| MkDocs source | Starlight target |
|---|---|
| `mkdocs.yml` `nav:` tree | `astro.config.mjs` `sidebar` |
| `docs/*.md` (under `docs_dir`) | `src/content/docs/**` (`.md`/`.mdx`) |
| Material structural tools (below) | MDX component equivalents |
| `.github/workflows/docs.yml` (mkdocs caller) | thin Astro caller |
| `mkdocs.yml`, Material `theme`/`markdown_extensions` | **removed** |
| `docs/superpowers/**` (dev specs) | **preserved, not migrated content** — still the built-in excluded set; they move to `src/content/docs/` only if they were published, else stay put |

`README.md` stays the concise entry point.

**Forward-looking pages — marker dropped.** The old `doc_mode: target-state` **frontmatter
marker is removed** (and with it any Starlight content-schema worry). It's replaced by a
**textual convention**: a page that **explicitly declares** it describes intended/future
state (a visible in-content statement, e.g. "This is the design we are heading toward, not
current behavior") is left alone; every other page is current-state and reconciled to code.
The test is deterministic and textual — *honor an explicit declaration, never infer
aspiration.* A page that silently describes behavior the code lacks, with no such
declaration, is still **drift** and still gets fixed. This also reads more honestly for
humans (a visible banner beats an invisible flag). generate-docs philosophy #5 is reworded
accordingly.

### Affordance rubric & Structural tools — translated, not discarded

`reference/affordance-rubric.md` is already ~framework-neutral (principles, not syntax); only
its one "e.g. Material admonitions" example is retargeted to "Starlight asides." **The heavy
translation is in the SKILL's *Structural tools* section:**

| Today (Material) | Starlight / MDX |
|---|---|
| `grid cards` + `attr_list`/`md_in_html` | `<CardGrid>` / `<Card>` / `<LinkCard>` |
| `=== "tabs"` (`pymdownx.tabbed`) | `<Tabs>` / `<TabItem>` |
| `!!! note` / `??? note` admonitions | `:::note`/`:::tip`/`:::caution`/`:::danger` asides |
| `:material-*:`/`:octicons-*:` icons | Starlight `<Icon>` set |
| hand-built HTML/CSS relationship diagram | same principle → an Astro component styled from Starlight's theme CSS custom properties (still **not** Mermaid for ≲10-node graphs) |
| Tables / split-page anatomy / "is this the best way?" | unchanged (framework-agnostic) |

The **linter-footgun catalogue** is re-derived for **MDX**: the rumdl MD046 tab-indent trap
(Material content-tabs) disappears; MDX brings its own interactions (JSX in markdown, the
markdown fixer vs. `<Component>` blocks). The "audit what the auto-fixer did to docs files"
discipline stays.

### Publishing — thin caller + reusable workflow (both, composed)

- generate-docs **writes the thin `docs.yml` caller** in each repo → self-sufficiency of the
  *target repo* (nothing pre-scaffolded required).
- The caller **delegates to repo-management's reusable `workflow_call`**, migrated to run
  `pnpm install --frozen-lockfile && pnpm build` (`astro build`) and deploy to Pages. **One fleet-wide pin** for
  Node/Astro/Starlight versions + build logic, maintained in one place.
- Pages source stays `pages: {enabled: true, build_type: workflow}` in each repo's
  repo-management config.
- **Sequencing:** the reusable Astro workflow lands (or is referenceable on a branch) first,
  so per-repo thin callers point at something real — upstream-before-downstream, as with the
  adoptions.

### Validation (Stage 4) — retargeted, and the Playwright ask, sharpened

- **Rewrite `check_docs.py`** to validate Starlight structure statically: internal links,
  sidebar-entry ↔ file correspondence, anchors, orphan pages — against `src/content/docs/**`
  and the `astro.config.mjs` `sidebar`, not `mkdocs.yml`/`docs_dir`.
- **Real build:** `pnpm install --frozen-lockfile && pnpm build`; `astro build` already hard-fails on broken
  internal links (replaces `mkdocs build --strict`).
- **Playwright smoke over built `dist/`** (already ~80% present in the skill — retarget from
  MkDocs to Astro output and **strengthen the screenshot-driven visual check the user asked
  for**):
  - Pages load; assets/embeds resolve (network/console scrape) — cheap tier / subagent via
    the Playwright MCP.
  - **Interact** with everything interactive (tabs swap, players play, in-app nav transitions
    re-check console).
  - **Judge painted pixels via real screenshots in both light+dark schemes** (Starlight ships
    a theme toggle) — Playwright CLI `screenshot`, judged by a vision model on the driver.
    Call out explicitly: screenshots are the reliable way to catch visual/contrast bugs a
    `getComputedStyle` probe misses; the user's eyes are ground truth.
  - Fallbacks stated when Playwright / `npm` / network is unavailable (static check + build
    only, or static check alone) — never skip silently.

### Licensing for new file types

- `.md`/`.mdx`/`.json` → **REUSE.toml** (already globbed; `.mdx` may need adding to the
  markdown glob — verify).
- `astro.config.mjs`, `src/content.config.ts`, other JS/TS → inline SPDX via `hawkeye`
  (JS/TS take line comments). Add to `.config/licenserc.toml` if a new extension isn't mapped.
- `package.json`/`package-lock.json`/`tsconfig.json` → REUSE.toml (JSON, no inline header).

### This repo's skill artifacts touched

`plugins/dev-kit/skills/generate-docs/`: `SKILL.md` (description + Structural tools + pipeline

- Publishing + "what it owns"), `reference/affordance-rubric.md` (one example retarget),
`scripts/check_docs.py` (rewrite). Tests: `tests/check_docs.bats`,
`tests/docs_versions.bats` (both mkdocs-heavy — rewrite for Astro/Starlight). The
generate-docs doc page `docs/dev-kit/generate-docs.md` updates as part of the migration of
*this* repo's own site.

## Fleet execution plan

1. **#176 hygiene** — latest `copier-everything` release + rebase/update onto `main`.
2. **repo-management** — migrate the reusable docs `workflow_call` to Astro/Starlight (its own
   PR); lands first (or branch-referenceable). **Hard gate:** #176's `docs.yml` caller points
   at this workflow, so #176's docs CI can't go green — and #176 can't merge — until this
   lands. repo-management leads, #176 follows (upstream-before-downstream, as with the adoptions).
3. **generate-docs rewrite** on #176 (dev-kit `feat`) — kept as distinct, reviewable commits
   alongside the copier-update chore.
4. **Dogfood** — run rewritten generate-docs on **this repo** (#176), migrating its own
   mkdocs site → Starlight. Proves the tool end-to-end (build + Playwright).
5. **Fan out** — run generate-docs on each of the **8 adoption PR branches**, migrating each
   scaffolded mkdocs site → Starlight before those PRs merge (coordinated per-repo, like the
   adoption fan-out; review-deduplicated — the Starlight mechanism is reviewed once, each
   downstream PR reviews only its own content migration).
6. **Tickets (#2)** — dated pivot notes on the docs epic (repo-management#85) + per-repo docs
   sub-issues + the mkdocs-specific template issue (copier-everything#239).
7. **Follow-up filed** — copier-everything `include_docs_site` → Starlight.

### PR #176 final contents (mixed, by request)

copier update v1.12.0 (chore) + release_model fix (chore, done) + generate-docs Starlight
rewrite (dev-kit `feat`) + this repo's own docs mkdocs→Starlight migration. Per-plugin
release-please attributes the dev-kit `feat` by path → a dev-kit minor bump. Kept as distinct
commits for reviewability.

## Decisions locked

- Self-sufficient generate-docs (create/update/migrate); no template requirement.
- Publishing = thin caller (written by generate-docs) + reusable Astro workflow
  (repo-management, migrated, one pin).
- Node toolchain = **pnpm** + committed `pnpm-lock.yaml` (corepack/pnpm-action in CI).
- `include_docs_site` → Starlight is a **follow-up**, not blocking.
- #176 carries the generate-docs feat (+ this repo's docs migration).

## Risks / verify during planning

- **repo-management reusable workflow** exact path/interface — confirm before writing the thin
  caller contract.
- **`check_docs.py`** current internals — confirm validation surface to preserve parity.
- **Astro `social`/OG-image** parity with Material's `social` plugin (Linux-CI-only quirk
  today) — decide whether Starlight OG images are in the baseline.
- **`.mdx` licensing** — confirm REUSE glob covers it; add if not.
- **Content collection schema** — confirm the fleet's existing docs frontmatter (titles,
  descriptions, any per-page keys) all satisfy Starlight's default content schema during
  migrate; extend the schema for any legitimately-needed field. (The `doc_mode` marker is
  gone, so it's no longer a concern — this is only about whatever real frontmatter pages carry.)

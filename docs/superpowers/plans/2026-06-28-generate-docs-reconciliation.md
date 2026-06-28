# generate-docs Reconciliation Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconceive `dev-kit:generate-docs` from a manifest-only deterministic generator into an LLM-driven documentation-reconciliation skill that reconciles the whole docs set against the whole codebase every run, for any repo kind.

**Architecture:** The skill becomes instructions (SKILL.md) that drive Claude through a tiered reconciliation pipeline (inventory/classify → parallel cheap mappers → reconcile/work-list → parallel page authors → docs-only validators → reconciliation report). The deterministic `build.py` generator is retired. The only shipped code is one thin, dependency-free docs validator. Each repo gets its own Claude-authored design system (`style.css` + vanilla `app.js`); the skill ships no assets.

**Tech Stack:** Markdown (SKILL.md), Python 3.11+ stdlib (validator, run via `uv`), bats (tests), hawkeye + REUSE + prek (existing gate, unchanged).

**Source of truth for all content decisions:** the approved spec at `docs/superpowers/specs/2026-06-28-generate-docs-reconciliation-design.md`. This plan implements that spec; where this plan says "per spec §N," copy that section's substance.

## Global Constraints

- **Licensing:** never hand-manage SPDX. `hawkeye` adds inline headers to HTML/CSS/JS and to `.bats`/`.py` scripts; `REUSE.toml` covers `**/*.md`. New files must pass `reuse lint` *via the gate*, not via skill-owned logic. (`tests/*.bats` and `*.py` get inline headers — confirm with `hawkeye format`.)
- **Don't recreate template tooling:** rely on the existing `prek` gate (shellcheck, gitleaks, typos, rumdl, taplo, reuse/hawkeye, bats). Add only docs-specific checks the gate lacks.
- **Commits:** plain Conventional Commits (`feat:`, `fix(dev-kit):`, `docs:`, `chore:`, `test:`), no leading emoji, no AI attribution. `no-commit-to-branch` blocks `main` — we are on branch `worktree-feat+generate-docs-reconciliation`.
- **Validator is dependency-free:** Python stdlib only (`html.parser`), run via `uv run` with a PEP 723 header pinning `requires-python = ">=3.11"` and no dependencies.
- **Dual-target invariant:** generated sites must render from a `file://` path and from GitHub Pages — all intra-site refs relative, no leading-slash/absolute local paths.

---

## File Structure

- `plugins/dev-kit/skills/generate-docs/SKILL.md` — **rewritten**: the reconciliation skill (philosophy, pipeline, shaping, design-system contract, validator invocation, broadened description).
- `plugins/dev-kit/skills/generate-docs/scripts/build.py` — **deleted** (retired generator).
- `plugins/dev-kit/skills/generate-docs/scripts/check_docs.py` — **created**: combined docs validator (broken-internal-link + non-relative-ref), stdlib-only.
- `tests/check_docs.bats` — **created**: behavior tests for `check_docs.py` using sandbox HTML fixtures.
- `plugins/dev-kit/skills/ship/SKILL.md` — **modified** (Phase 5 wording): generate-docs no longer skips non-marketplace repos.

---

## Task 1: Docs validator (`check_docs.py`) + bats tests

Combined Stage-4 validator: one pass over the site's `*.html` flags (a) broken internal links and (b) absolute/non-portable local refs. One script (DRY — both checks share HTML-ref extraction). External links, `mailto:`, `data:`, protocol-relative (`//`), and pure anchors (`#foo`) are ignored.

**Files:**

- Create: `plugins/dev-kit/skills/generate-docs/scripts/check_docs.py`
- Test: `tests/check_docs.bats`

**Interfaces:**

- Consumes: nothing (first task).
- Produces: CLI `uv run .../scripts/check_docs.py <docs_dir>` → exit `0` clean / `1` violations (one per line on stdout) / `2` usage error. Stage 4 of the rewritten SKILL.md (Task 2) invokes this exact command.
- [ ] **Step 1: Write the failing test**

Create `tests/check_docs.bats`:

```bash
#!/usr/bin/env bats

# Tests for plugins/dev-kit/skills/generate-docs/scripts/check_docs.py — the docs-site
# validator. Each test builds a throwaway docs/ dir with HTML fixtures and asserts the
# validator's exit code and output: clean sites pass, broken internal links and absolute
# local refs fail, and external/anchor/mailto refs are ignored.
# Run:  bats tests/check_docs.bats

setup() {
  SANDBOX="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../plugins/dev-kit/skills/generate-docs/scripts/check_docs.py"
  SITE="$SANDBOX/docs"
  mkdir -p "$SITE"
}

teardown() {
  rm -rf "$SANDBOX"
}

run_check() {
  run uv run "$SCRIPT" "$SITE"
}

@test "clean site passes" {
  printf '<a href="other.html">x</a><img src="img/logo.png">' >"$SITE/index.html"
  printf 'ok' >"$SITE/other.html"
  mkdir -p "$SITE/img"; printf 'png' >"$SITE/img/logo.png"
  run_check
  [ "$status" -eq 0 ]
}

@test "broken internal link fails" {
  printf '<a href="missing.html">x</a>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
  [[ "$output" == *"missing.html"* ]]
}

@test "absolute local path fails (not portable to file://)" {
  printf '<link rel="stylesheet" href="/style.css">' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute path"* ]]
}

@test "external, mailto, data, protocol-relative and anchor refs are ignored" {
  printf '<a href="https://example.com">e</a><a href="mailto:a@b.c">m</a>' >"$SITE/index.html"
  printf '<a href="//cdn.example/x.js">p</a><a href="#top">t</a><img src="data:image/png;base64,AAAA">' >>"$SITE/index.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "link with anchor and query resolves against the file path" {
  printf '<a href="page.html#sec?v=1">x</a>' >"$SITE/index.html"
  printf 'ok' >"$SITE/page.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "nested-page relative link resolves from its own directory" {
  mkdir -p "$SITE/guide"
  printf '<a href="../index.html">home</a>' >"$SITE/guide/start.html"
  printf 'home' >"$SITE/index.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "usage error when given a non-directory" {
  run uv run "$SCRIPT" "$SANDBOX/does-not-exist"
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/check_docs.bats`
Expected: FAIL — the script does not exist yet (uv run errors / non-zero for every case).

- [ ] **Step 3: Write the validator**

Create `plugins/dev-kit/skills/generate-docs/scripts/check_docs.py`:

```python
# /// script
# requires-python = ">=3.11"
# ///
"""Validate a generated docs site.

Two checks over every *.html file under <docs_dir>:
  1. internal-link integrity — relative href/src targets must exist on disk.
  2. dual-target portability — no absolute (leading-slash) local refs, so the
     site renders from a file:// path and from GitHub Pages alike.

External refs (with a scheme), protocol-relative (//host), mailto:, data:, and
pure anchors (#frag) are ignored. Exit 0 = clean, 1 = violations, 2 = usage.
"""

import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

REF_ATTRS = {"href", "src"}


class RefExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.refs: list[tuple[str, str, str]] = []  # (tag, attr, value)

    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if name in REF_ATTRS and value is not None:
                self.refs.append((tag, name, value))


def is_external_or_special(url: str) -> bool:
    if url.startswith("//") or url.startswith("#"):
        return True
    return bool(urlparse(url).scheme)  # http:, https:, mailto:, data:, ...


def check_file(html_path: Path) -> list[str]:
    violations: list[str] = []
    parser = RefExtractor()
    parser.feed(html_path.read_text(encoding="utf-8"))
    for tag, attr, value in parser.refs:
        v = value.strip()
        if not v or is_external_or_special(v):
            continue
        if v.startswith("/"):
            violations.append(
                f"{html_path}: absolute path not portable to file://: "
                f"<{tag} {attr}={value!r}>"
            )
            continue
        ref = v.split("#", 1)[0].split("?", 1)[0]
        if not ref:
            continue
        target = html_path.parent / unquote(ref)
        if not target.exists():
            violations.append(
                f"{html_path}: broken internal link: <{tag} {attr}={value!r}>"
            )
    return violations


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_docs.py <docs_dir>", file=sys.stderr)
        return 2
    docs_root = Path(argv[1])
    if not docs_root.is_dir():
        print(f"not a directory: {docs_root}", file=sys.stderr)
        return 2
    violations: list[str] = []
    for html_path in sorted(docs_root.rglob("*.html")):
        violations.extend(check_file(html_path))
    for v in violations:
        print(v)
    if violations:
        print(f"\n{len(violations)} doc validation issue(s) found.", file=sys.stderr)
        return 1
    print(f"OK: {docs_root} — no broken internal links, all refs portable.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/check_docs.bats`
Expected: PASS — all 7 tests green.

- [ ] **Step 5: Apply license headers to the new files**

Run: `hawkeye format`
Expected: `check_docs.py` and `check_docs.bats` receive inline SPDX headers (matching `licenserc.toml`). Then `reuse lint` passes.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-kit/skills/generate-docs/scripts/check_docs.py tests/check_docs.bats
git commit -m "feat(dev-kit): add docs-site validator for generate-docs"
```

---

## Task 2: Rewrite `generate-docs/SKILL.md`

Replace the manifest-templating instructions with the reconciliation skill. **Content source: spec §3 (philosophy), §5 (pipeline Stage 0–5), §6 (repo-kind shaping), §7 (design system), §8 (outputs/blast radius), §9 (licensing), §10 (what ships).** This task writes prose; the deliverable is verified by the gate (rumdl/reuse) and by the plugin-dev reviewers, not by a unit test.

**Files:**

- Modify (full rewrite): `plugins/dev-kit/skills/generate-docs/SKILL.md`

**Interfaces:**

- Consumes: the validator CLI from Task 1 (`uv run "${CLAUDE_PLUGIN_ROOT}/skills/generate-docs/scripts/check_docs.py" docs`) — documented as Stage 4.
- Produces: the skill `name: generate-docs` and the broadened `description` (below) that drives triggering.
- [ ] **Step 1: Replace the YAML frontmatter**

The frontmatter is the first lines of the file (YAML between `---` fences). Set it to exactly:

```yaml
---
name: generate-docs
description: This skill should be used when the user asks to "generate the docs", "build the docs site", "refresh the docs", "reconcile the docs", "publish to GitHub Pages", or "make a docs page" for a repo. It reconciles the WHOLE documentation set against the WHOLE codebase every run — catching both drift (docs that no longer match the code) and omission (code with no docs) — and authors a bespoke, human-first static documentation site (a landing page plus per-topic pages) shaped to whatever the repo is: a Claude Code plugin marketplace, a Copier template, a library or CLI, or a generic project. Code is the source of truth and Claude authors the prose; the site renders identically from a local file:// path and from GitHub Pages. Reach for it to create, refresh, or reconcile a repo's docs site, including as part of shipping a change (dev-kit:ship runs it automatically).
---
```

(Note: the old description's "Not for general-purpose project or API docs." sentence is dropped. Do NOT add an inline SPDX comment above the frontmatter — markdown is licensed via `REUSE.toml`.)

- [ ] **Step 2: Write the body**

Author the body to cover, in this order, each mapped to its spec section (write real prose, no placeholders — pull substance from the cited spec sections):

1. **What this is / philosophy** (spec §3) — whole-against-whole every run; catch drift + omission; humans-primary/LLMs-secondary; "is this the best way to communicate this?"; code is source of truth; analyze-whole-but-rewrite-only-what's-wrong.
2. **The reconciliation pipeline** (spec §5) — Stage 0 inventory & classify; Stage 1 parallel cheap mappers (fan out `Explore` subagents, structured facts model); Stage 2 reconcile → work-list (drift / omission / communication / design-system needs / leave-byte-identical), kept in the driver; Stage 3 parallel page authors (mid tier) + README reconciled as a concise entry point; Stage 4 run the validator (`uv run "${CLAUDE_PLUGIN_ROOT}/skills/generate-docs/scripts/check_docs.py" <docs_dir>`) and note licensing/lint is the existing gate's job; Stage 5 synthesize + reconciliation report (non-published). Include the cost posture and "dials down to a single inline pass for small repos" note.
3. **Repo-kind shaping** (spec §6) — marketplace / Copier / library-CLI / generic, with "principles override templates; structure re-derived each run; zero-config."
4. **The per-repo design system** (spec §7) — skill ships no assets; Claude authors `style.css` + vanilla `app.js` (search/nav/theme) into the repo; design-system + escape hatch; first-run bootstrap vs later-run reconcile; consistency enforced by reconciliation.
5. **Outputs & blast radius** (spec §8) — writes docs site + `README.md` + guides; source code read-only; **excludes developer specs `docs/superpowers/**` from reconciliation**.
6. **Licensing & tooling** (spec §9, §10) — don't hand-manage SPDX (hawkeye/REUSE); don't recreate the gate; the only shipped script is `check_docs.py`.
7. **Audience priority** — restate humans-primary, LLMs-secondary as an authoring rule.

Keep the tone and structure consistent with other dev-kit SKILL.md files (e.g. `ship`, `cleanup-locally`).

- [ ] **Step 3: Verify no dangling references and gate-clean the file**

Run: `grep -n "build.py\|marketplace.json\|--repo-root" plugins/dev-kit/skills/generate-docs/SKILL.md`
Expected: no references to `build.py` or `--repo-root`; `marketplace.json` may appear only as a *classification sentinel* (Stage 0), never as a hard requirement.

Run: `uvx prek run rumdl --files plugins/dev-kit/skills/generate-docs/SKILL.md` (and let it autofix), then `uvx reuse lint`.
Expected: rumdl passes; reuse lint passes.

- [ ] **Step 4: Review the rewritten skill**

Dispatch the `plugin-dev:skill-reviewer` agent on `plugins/dev-kit/skills/generate-docs/SKILL.md` and the `plugin-dev:plugin-validator` on the `dev-kit` plugin. Apply any must-fix feedback (description triggering, structure).
Expected: reviewers report no blocking issues.

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-kit/skills/generate-docs/SKILL.md
git commit -m "feat(dev-kit): rewrite generate-docs as docs reconciliation skill"
```

---

## Task 3: Retire `build.py`

The manifest-only generator is superseded by Claude authoring. It is referenced only by the old SKILL.md (now rewritten in Task 2) and the spec.

**Files:**

- Delete: `plugins/dev-kit/skills/generate-docs/scripts/build.py`

**Interfaces:**

- Consumes: nothing.
- Produces: nothing (removal).
- [ ] **Step 1: Confirm no remaining references**

Run:

```bash
grep -rn "build\.py" \
  --include="*.md" --include="*.yml" --include="*.yaml" --include="*.toml" --include="*.sh" \
  . | grep -v "docs/superpowers/specs/" | grep -v "docs/superpowers/plans/"
```

Expected: no output (the only references were in the spec/plan, which intentionally describe the retirement).

- [ ] **Step 2: Delete the file**

```bash
git rm plugins/dev-kit/skills/generate-docs/scripts/build.py
```

- [ ] **Step 3: Verify the gate still passes**

Run: `uvx prek run --all-files`
Expected: green (no hook depends on `build.py`; no broken references).

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(dev-kit): retire manifest-only build.py generator"
```

---

## Task 4: Update `dev-kit:ship` Phase 5 wording

generate-docs now handles any repo kind, so ship's Phase 5 must no longer instruct skipping non-marketplace repos (spec AC #5).

**Files:**

- Modify: `plugins/dev-kit/skills/ship/SKILL.md:145-148`

**Interfaces:**

- Consumes: nothing.
- Produces: nothing (doc wording).
- [ ] **Step 1: Replace the Phase 5 paragraph**

Current text (lines 147–148):
> Run **`/dev-kit:generate-docs`** so the docs never drift from the change. If the repo has no
> docs site / isn't a marketplace, note that and skip — but default to keeping docs current.

Replace the second sentence so it no longer ties skipping to "isn't a marketplace." New paragraph:

```markdown
Run **`/dev-kit:generate-docs`** so the docs never drift from the change. It reconciles the
whole docs set against the whole codebase and shapes the site to the repo kind (marketplace,
Copier template, library/CLI, or generic), so it applies to any repo — only skip if the repo
genuinely has no docs to maintain. Default to keeping docs current.
```

- [ ] **Step 2: Gate-clean the file**

Run: `uvx prek run rumdl --files plugins/dev-kit/skills/ship/SKILL.md` (let it autofix).
Expected: rumdl passes.

- [ ] **Step 3: Commit**

```bash
git add plugins/dev-kit/skills/ship/SKILL.md
git commit -m "docs(dev-kit): ship Phase 5 no longer skips non-marketplace repos"
```

---

## Task 5: Dogfood, licensing verification, and scope checkpoint

Prove the rewritten skill works end-to-end and that generated assets are gate-clean. **Decision checkpoint:** re-authoring this repo's *committed* `docs/` site is a large content migration; do NOT bundle it into this skill-change PR without explicit user confirmation (spec §11 AC #3 flags this). Default to verifying in a throwaway location and proposing the real re-authoring as a follow-up.

**Files:**

- None committed by default (verification only). Possibly `licenserc.toml` *only if* a real coverage gap surfaces.

**Interfaces:**

- Consumes: the skill (Task 2) + validator (Task 1).
- Produces: a verification result + a go/no-go on committing a re-authored site.
- [ ] **Step 1: Dogfood the pipeline against a sandbox copy of this repo**

Copy the repo's docs inputs into a scratch dir (e.g. under the session scratchpad) and run the reconciliation pipeline (per the new SKILL.md) targeting that scratch `docs/`. This avoids touching the committed `docs/` during verification.
Expected: a coherent landing page + per-plugin pages + a `style.css` + `app.js` + a reconciliation report.

- [ ] **Step 2: Validate the generated site**

Run: `uv run plugins/dev-kit/skills/generate-docs/scripts/check_docs.py <scratch_docs_dir>`
Expected: exit 0 (no broken internal links, all refs portable).

- [ ] **Step 3: Verify licensing on generated assets**

Copy a few generated `*.html`/`*.css`/`*.js` into a scratch git work-area (or run in place in the scratch dir) and run `hawkeye format` then `reuse lint`.
Expected: hawkeye adds inline headers to HTML/CSS/JS cleanly and `reuse lint` passes. **If** a generated file type is not covered by `hawkeye`'s defaults, fix `licenserc.toml` (add the mapping) — do not hand-inject headers in the skill — and note it.

- [ ] **Step 4: Spot-check the Copier path**

Point the pipeline at a minimal Copier-template layout fixture (a dir with a `copier.yml` and a README, no marketplace manifest). Confirm it produces a usable generic/Copier-shaped site (landing from README + a template-reference section), not an error or empty shell (spec AC #1, #2).
Expected: a usable site; validator exits 0.

- [ ] **Step 5: Scope checkpoint with the user**

Present: "Skill verified. Re-authoring *this* repo's committed `docs/` is a large, separate diff. Bundle it into this PR, or ship the skill now and re-author the site as a follow-up issue?" Proceed per their answer. If bundling: run the skill against the real `docs/` + `README.md`, run the validator, `hawkeye format`, `reuse lint`, and commit as a dedicated `docs:` commit.

- [ ] **Step 6: Full gate**

Run: `uvx prek run --all-files`
Expected: green.

---

## Self-Review (completed during planning)

**Spec coverage:**

- §3 philosophy → Task 2 Step 2(1). §5 pipeline → Task 2 Step 2(2) + Task 1 (Stage 4 validator). §6 shaping → Task 2 Step 2(3). §7 design system → Task 2 Step 2(4). §8 outputs/exclusions → Task 2 Step 2(5). §9 licensing → Global Constraints + Task 1 Step 5 + Task 5 Step 3. §10 what ships → Task 1 (validator), Task 2 (SKILL), Task 3 (retire build.py). §11 AC#1/#2 → Task 5 Step 4; AC#3 → Task 5 Step 5 checkpoint; AC#4 → Task 1 (dual-target check); AC#5 → Task 2 (description) + Task 4 (ship Phase 5). §12 verification → Task 1 (bats), Task 5 (dogfood + gate).
- No spec requirement is left without a task.

**Placeholder scan:** validator code and bats tests are complete and runnable; prose tasks point to specific approved-spec sections (concrete content source, not a vague "fill in").

**Type/interface consistency:** the validator CLI contract (`check_docs.py <docs_dir>`, exit 0/1/2) is identical in Task 1 (definition), Task 2 Step 2(2) (Stage 4 invocation), and Task 5 Step 2 (verification).

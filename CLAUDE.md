<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

# CLAUDE.md

Repo-specific guidance for this Claude Code **plugin marketplace**. Global conventions
(conventional commits, no AI attribution, `uv add`, running quality checks) live in the
user's global CLAUDE.md and are not repeated here.

## What this repo is

A marketplace of Claude Code plugins. Two registries to keep in sync:

- `.claude-plugin/marketplace.json` — lists every plugin (name, `source`, description).
- `plugins/<name>/.claude-plugin/plugin.json` — each plugin's own manifest.

A plugin holds `skills/<skill>/SKILL.md` (and optionally `commands/`, `agents/`,
`scripts/`, `reference/`). Plugin skills are invoked **namespaced**: `/<plugin>:<skill>`
(e.g. `/castify:record-terminal-casts`), not bare.

### Adding a plugin

1. `plugins/<name>/.claude-plugin/plugin.json` + at least one `skills/<skill>/SKILL.md`.
2. Register it in `.claude-plugin/marketplace.json`.
3. SPDX + gate (below). Validate with `plugin-dev` (`plugin-validator`, `skill-reviewer`).

## Quality gate (prek)

Infra comes from the `nivintw/scaffold` copier template — **this repo is copier-managed**
(`.copier-answers.yml`); pull template updates with `copier update`. Don't hand-edit
generated config expecting it to survive unless you're deliberately reconciling.

- After clone: `uvx prek install`.
- Run the full gate: `uvx prek run --all-files`. Run it before pushing.
- Hooks: shellcheck, gitleaks, typos, rumdl (markdown), REUSE/hawkeye (SPDX), taplo
  (TOML), plus commit-message enforcement.
- Tests: `bats tests/` (the gate runs them too; bats is the suite for shell scripts).

## Commits

Commits are **gitmoji + Conventional Commits** (`cz-conventional-gitmoji`), enforced by a
`commit-msg` hook. Each gitmoji pairs with one specific type word — using the wrong emoji
fails the hook. Common pairs: `✨ feat`, `🐛 fix`, `📝 docs`, `♻️ refactor`, `✅ test`,
`👷 build`, `💚 ci`, `🔧 config`, `🧹 chore`, `🎉 init`. You can also write just
`feat: …` and the `gitmojify` hook prepends the emoji. `no-commit-to-branch` blocks
commits directly on `main` — branch, then PR.

## Licensing (REUSE / SPDX)

Every file needs SPDX info; `reuse lint` must pass.

- Most files get an inline header from `hawkeye format` (config: `licenserc.toml`).
- **JSON and Markdown are licensed via `REUSE.toml`, not inline.** Markdown is excluded
  from hawkeye on purpose: skill/agent/command markdown is **frontmatter-first** (YAML on
  line 1), and an inline SPDX comment above it breaks the frontmatter. So never let
  hawkeye add a header to a `SKILL.md`.
- `LICENSES/*.txt` must stay tracked — the `*.txt` gitignore rule has a `!LICENSES/*.txt`
  exception. Don't drop it.
- New file checklist: `hawkeye format` → `reuse lint`.

## CI / releases

- `pr.yml` runs the gate on PRs (`ci / lint-and-test` is the required check).
- `main.yml` runs the gate then a commitizen auto-release on push to `main`. The release
  job **skips cleanly** until `CI_APP_ID` / `CI_APP_PRIVATE_KEY` (release GitHub App)
  secrets exist — so merging is always safe; adding the secrets activates releases.

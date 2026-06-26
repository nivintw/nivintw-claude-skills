---
name: generate-docs
description: >-
  This skill should be used when the user asks to "generate the docs", "build the docs
  site", "refresh the plugin docs", "publish to GitHub Pages", or "make a docs page for
  this marketplace/plugin". It generates a self-contained static documentation site for a
  Claude Code plugin marketplace or repo — a landing page plus a page per plugin (manifest,
  skills, commands, agents, rendered README) — that works BOTH opened locally as a file://
  path AND served from GitHub Pages, with zero build step and no JavaScript or external
  assets at view time. Reach for it to create, refresh, or publish docs generated from the
  plugin/marketplace manifests, or to keep those docs current as part of shipping a change
  (dev-kit:ship runs it automatically). Not for general-purpose project or API docs.
---

# generate-docs

Build a **self-contained** static docs site from the repo's own manifests, so the
output renders identically whether someone double-clicks `docs/index.html` (a `file://`
URL) or visits the GitHub Pages site. "Self-contained" is the hard requirement: every
asset loaded at view time is local — vendored CSS, markdown pre-rendered to HTML, **no
JavaScript, no external fonts/CDNs**. (External *navigation* links like "View on GitHub"
are fine — they're clicks, not view-time loads.) It must *just work* from GitHub Pages,
and never be unusable locally.

## The generator

`scripts/build.py` reads the marketplace and plugin manifests (and each skill's `SKILL.md`
frontmatter) and writes a static site into `docs/`. It's a self-contained Python script
with PEP 723 inline dependencies — run it with `uv`, **from the repo root** (the verify
and publish steps below use repo-root-relative paths):

```bash
uv run "${CLAUDE_PLUGIN_ROOT}/skills/generate-docs/scripts/build.py" --repo-root .
```

Flags: `--repo-root PATH` (default: walks up to find `.claude-plugin/marketplace.json`),
`--out docs`, `--holder "Name"` (default: marketplace `owner.name`), `--license MIT`.

Output:

- `docs/index.html` — marketplace landing: name, description, owner, install snippet, a
  card per plugin linking to its page.
- `docs/<plugin>.html` — per-plugin page: version, description, keywords, rendered README,
  and each skill/command/agent with its description.
- `docs/style.css` — vendored, responsive, light/dark via `prefers-color-scheme`.

## Process

1. **Run the generator** (command above). Re-running cleanly overwrites `docs/`.
2. **Verify it works offline** — this is the acceptance test, do it every time:

   ```bash
   open docs/index.html            # macOS; or xdg-open / just open the file:// path
   # Nothing is fetched off-site at view time. The only asset is the vendored, relative
   # style.css — there is no JS or web font. (Absolute <a href> nav links to github.com
   # are expected — they're clicks, not view-time loads — so don't flag those.)
   grep -RiE '<script|<link[^>]+stylesheet' docs/   # stylesheet must be relative; no <script>
   grep -riE 'https?://(cdn|fonts|unpkg|jsdelivr)' docs/   # empty: no external CSS/JS/fonts
   ```

   Click through to a plugin page and back from the `file://` view — the internal
   page-to-page links must resolve locally. If one 404s, it's not self-contained — fix
   before publishing.
3. **Publish via GitHub Pages** — point Pages at the `docs/` folder on the default branch:

   ```bash
   gh api -X POST repos/{owner}/{repo}/pages -f source[branch]=main -f source[path]=/docs 2>/dev/null \
     || gh api -X PUT repos/{owner}/{repo}/pages -f source[branch]=main -f source[path]=/docs
   ```

   Or set it in the repo UI (Settings → Pages → Deploy from a branch → `main` / `/docs`).
   No Jekyll/baseurl is involved, so project-pages URLs and local `file://` both resolve.
4. **Commit `docs/`** — the generated site is tracked so Pages can serve it.

## Notes

- **Keep generated docs in sync.** `/dev-kit:ship` runs this skill on every ship so the
  site never drifts from the code. Regenerate whenever plugins, skills, or manifests change.
- **REUSE/SPDX:** generated `.html`/`.css` carry an SPDX header (from `--holder`/`--license`)
  so `reuse lint` passes in REUSE repos. In this marketplace, ensure `docs/**` stays
  compliant after generating (`reuse lint`).
- **When a server is genuinely needed** (e.g. testing something that requires an HTTP
  origin), `python3 -m http.server -d docs 8000` serves it — but the site must remain fully
  usable from `file://` regardless; the server is never a requirement.

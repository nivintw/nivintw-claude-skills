# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# /// script
# requires-python = ">=3.11"
# dependencies = ["markdown>=3.5", "nh3>=0.2"]
# ///
#
# REUSE-IgnoreStart
# (This file's SPDX header is managed by hawkeye — do not add one here.)
# The template strings below contain literal "SPDX-" tokens; without this guard,
# reuse lint would try to parse them as declarations on this source file.

"""build.py — Static documentation-site generator for a Claude Code plugin marketplace.

Usage:
    uv run build.py [--repo-root PATH] [--out docs] [--holder NAME] [--license SPDX]

Generates a static HTML docs site into <repo-root>/<out>/:
  - index.html  — landing page with plugin cards
  - <plugin>.html — per-plugin page with skills/commands/agents
  - style.css   — all styles, no external deps

All links are relative so the site works from file:// and GitHub Pages.
No JavaScript required to render. Markdown pre-rendered at build time.
"""

import argparse
import html
import json
import re
import sys
from datetime import date
from pathlib import Path

import markdown as md_module
import nh3


# ---------------------------------------------------------------------------
# SPDX header templates (guarded by REUSE-IgnoreStart above)
# ---------------------------------------------------------------------------

HTML_SPDX_TEMPLATE = """\
<!--
SPDX-FileCopyrightText: © {year} {holder}
SPDX-License-Identifier: {license}
-->
"""

CSS_SPDX_TEMPLATE = """\
/*
 * SPDX-FileCopyrightText: © {year} {holder}
 * SPDX-License-Identifier: {license}
 */
"""

# REUSE-IgnoreEnd


# ---------------------------------------------------------------------------
# CSS content
# ---------------------------------------------------------------------------

STYLE_CSS = """\
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

:root {
  --bg: #ffffff;
  --bg-card: #f8f9fa;
  --bg-code: #f1f3f4;
  --text: #1a1a1a;
  --text-muted: #6b7280;
  --accent: #2563eb;
  --accent-hover: #1d4ed8;
  --border: #e5e7eb;
  --border-card: #d1d5db;
  --tag-bg: #eff6ff;
  --tag-text: #1d4ed8;
  --tag-border: #bfdbfe;
  --radius: 8px;
  --font: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0f172a;
    --bg-card: #1e293b;
    --bg-code: #1e293b;
    --text: #f1f5f9;
    --text-muted: #94a3b8;
    --accent: #60a5fa;
    --accent-hover: #93c5fd;
    --border: #334155;
    --border-card: #475569;
    --tag-bg: #1e3a5f;
    --tag-text: #93c5fd;
    --tag-border: #2563eb;
  }
}

body {
  font-family: var(--font);
  font-size: 16px;
  line-height: 1.6;
  background: var(--bg);
  color: var(--text);
  padding: 2rem 1rem;
}

.container {
  max-width: 860px;
  margin: 0 auto;
}

header {
  margin-bottom: 2.5rem;
  padding-bottom: 1.5rem;
  border-bottom: 1px solid var(--border);
}

header h1 {
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  margin-bottom: 0.4rem;
}

header .subtitle {
  color: var(--text-muted);
  font-size: 1.05rem;
}

header .owner {
  margin-top: 0.5rem;
  font-size: 0.9rem;
  color: var(--text-muted);
}

a {
  color: var(--accent);
  text-decoration: none;
}

a:hover {
  color: var(--accent-hover);
  text-decoration: underline;
}

h2 {
  font-size: 1.35rem;
  font-weight: 600;
  margin-bottom: 1rem;
  margin-top: 2rem;
}

h2:first-child {
  margin-top: 0;
}

h3 {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 0.4rem;
  margin-top: 1.5rem;
}

p {
  margin-bottom: 0.75rem;
}

/* Plugin cards on index */
.plugin-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1rem;
  margin-top: 1rem;
}

.plugin-card {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: var(--radius);
  padding: 1.25rem 1.5rem;
  transition: border-color 0.15s;
}

.plugin-card:hover {
  border-color: var(--accent);
}

.plugin-card h3 {
  margin-top: 0;
  font-size: 1.05rem;
}

.plugin-card h3 a {
  color: var(--text);
  font-weight: 700;
}

.plugin-card h3 a:hover {
  color: var(--accent);
  text-decoration: none;
}

.plugin-card .description {
  color: var(--text-muted);
  font-size: 0.9rem;
  margin-top: 0.35rem;
  margin-bottom: 0;
}

.plugin-card .category {
  display: inline-block;
  margin-top: 0.75rem;
  font-size: 0.78rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--tag-text);
  background: var(--tag-bg);
  border: 1px solid var(--tag-border);
  padding: 0.1rem 0.5rem;
  border-radius: 999px;
}

/* Install snippet */
.install-block {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: var(--radius);
  padding: 1.25rem 1.5rem;
  margin: 1.5rem 0;
}

.install-block p {
  margin-bottom: 0.5rem;
  font-size: 0.9rem;
  color: var(--text-muted);
}

.install-block code, code {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  background: var(--bg-code);
  padding: 0.15em 0.4em;
  border-radius: 4px;
  color: var(--text);
}

.install-block .snippet {
  display: block;
  margin: 0.25rem 0;
  padding: 0.5rem 0.75rem;
  background: var(--bg-code);
  border-radius: 4px;
  font-family: var(--font-mono);
  font-size: 0.875rem;
  overflow-x: auto;
  white-space: pre;
}

/* Plugin page */
.meta-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 1rem;
}

.version-badge {
  font-size: 0.82rem;
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 999px;
  padding: 0.1rem 0.55rem;
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.keyword-tag {
  display: inline-block;
  font-size: 0.78rem;
  font-weight: 500;
  color: var(--tag-text);
  background: var(--tag-bg);
  border: 1px solid var(--tag-border);
  padding: 0.1rem 0.5rem;
  border-radius: 999px;
}

/* Skills / commands / agents list */
.component-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
  margin-top: 0.5rem;
}

.component-item {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: var(--radius);
  padding: 0.85rem 1.1rem;
}

.component-item .comp-name {
  font-family: var(--font-mono);
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--text);
}

.component-item .comp-desc {
  margin-top: 0.25rem;
  font-size: 0.88rem;
  color: var(--text-muted);
}

/* Rendered markdown (README section) */
.readme-content h1,
.readme-content h2,
.readme-content h3,
.readme-content h4 {
  margin-top: 1.5rem;
  margin-bottom: 0.5rem;
}

.readme-content ul,
.readme-content ol {
  margin-left: 1.5rem;
  margin-bottom: 0.75rem;
}

.readme-content li {
  margin-bottom: 0.25rem;
}

.readme-content pre {
  background: var(--bg-code);
  border-radius: var(--radius);
  padding: 1rem;
  overflow-x: auto;
  margin: 0.75rem 0;
}

.readme-content pre code {
  background: none;
  padding: 0;
  font-size: 0.875rem;
}

.readme-content blockquote {
  border-left: 3px solid var(--border-card);
  padding-left: 1rem;
  color: var(--text-muted);
  margin: 0.75rem 0;
}

.readme-content hr {
  border: none;
  border-top: 1px solid var(--border);
  margin: 1.5rem 0;
}

.readme-content table {
  border-collapse: collapse;
  width: 100%;
  margin: 0.75rem 0;
}

.readme-content th,
.readme-content td {
  border: 1px solid var(--border);
  padding: 0.5rem 0.75rem;
  text-align: left;
}

.readme-content th {
  background: var(--bg-card);
  font-weight: 600;
}

/* Nav / breadcrumb */
.breadcrumb {
  font-size: 0.88rem;
  color: var(--text-muted);
  margin-bottom: 1.5rem;
}

.breadcrumb a {
  color: var(--text-muted);
}

.breadcrumb a:hover {
  color: var(--accent);
}

footer {
  margin-top: 3rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--border);
  font-size: 0.82rem;
  color: var(--text-muted);
  text-align: center;
}
"""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def h(text: str) -> str:
    """HTML-escape a string."""
    return html.escape(str(text))


def render_markdown(text: str) -> str:
    """Render markdown to HTML, sanitized to remove XSS vectors."""
    extensions = ["extra", "fenced_code", "tables", "nl2br"]
    raw = md_module.markdown(text, extensions=extensions)
    return nh3.clean(raw)


def safe_url(url: str) -> str:
    """Return url if it uses a safe scheme (http/https/mailto, relative, or anchor), else empty string."""
    return url if re.match(r'^(https?:|mailto:|#|/|\.{0,2}/)', url.strip(), re.I) else ""


def slugify(name: str) -> str:
    """Return a filesystem-safe slug: lowercase, only [a-z0-9-], no leading/trailing hyphens."""
    slug = name.lower()
    slug = re.sub(r'[^a-z0-9-]', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')


def parse_frontmatter(content: str) -> tuple[dict, str]:
    """Parse YAML frontmatter (between --- delimiters at file start).

    Returns (frontmatter_dict, body_text). If no frontmatter, returns ({}, content).
    Only parses 'name' and 'description' keys — avoids a yaml dep.
    """
    if not content.startswith("---"):
        return {}, content

    # Find closing ---
    rest = content[3:]
    end = rest.find("\n---")
    if end == -1:
        return {}, content

    fm_text = rest[:end]
    body = rest[end + 4:]  # skip past "\n---"

    # Minimal multi-line value parser for name and description
    data: dict = {}
    current_key: str | None = None
    current_lines: list[str] = []

    def flush():
        if current_key and current_lines:
            data[current_key] = " ".join(current_lines).strip()

    for line in fm_text.splitlines():
        # Continuation lines (indented, or quoted block scalar)
        if current_key and line.startswith("  "):
            current_lines.append(line.strip().lstrip(">-").strip())
            continue

        # Key: value line
        m = re.match(r'^(\w+)\s*:\s*(.*)', line)
        if m:
            flush()
            current_key = m.group(1)
            value = m.group(2).strip().strip('"\'')
            # YAML block scalar indicator (">-", ">", "|", "|-")
            if value in (">-", ">", "|", "|-", ""):
                current_lines = []
            else:
                current_lines = [value]
        else:
            current_lines.append(line.strip())

    flush()
    return data, body


def find_repo_root(start: Path) -> Path:
    """Walk up from start looking for .claude-plugin/marketplace.json."""
    current = start.resolve()
    for _ in range(20):
        if (current / ".claude-plugin" / "marketplace.json").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    raise FileNotFoundError(
        "Could not find .claude-plugin/marketplace.json walking up from "
        f"{start}. Pass --repo-root explicitly."
    )


def derive_marketplace_add_target(owner_url: str, marketplace_name: str) -> str:
    """Derive the /plugin marketplace add target from owner URL."""
    # If it looks like a GitHub URL, extract owner/repo-like path.
    m = re.match(r'https?://github\.com/([^/]+)(?:/([^/]+))?', owner_url)
    if m:
        owner = m.group(1)
        repo = m.group(2)
        if repo:
            return f"{owner}/{repo}"
        # owner.url is just the profile (common case). The marketplace `name` is the
        # repo name, so `owner/name` is the correct `/plugin marketplace add` target.
        return f"{owner}/{marketplace_name}"
    return marketplace_name


def collect_components(plugin_source: Path) -> dict[str, list[dict]]:
    """Collect skills, commands, and agents from a plugin source directory.

    Returns a dict with keys 'skills', 'commands', 'agents', each a list of
    {'name': str, 'description': str}.
    """
    result: dict[str, list[dict]] = {"skills": [], "commands": [], "agents": []}

    # Skills: <source>/skills/*/SKILL.md
    skills_dir = plugin_source / "skills"
    if skills_dir.is_dir():
        for skill_dir in sorted(skills_dir.iterdir()):
            skill_md = skill_dir / "SKILL.md"
            if skill_md.is_file():
                fm, _ = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
                result["skills"].append({
                    "name": fm.get("name", skill_dir.name),
                    "description": fm.get("description", ""),
                })

    # Commands: <source>/commands/*.md
    commands_dir = plugin_source / "commands"
    if commands_dir.is_dir():
        for cmd_md in sorted(commands_dir.glob("*.md")):
            fm, _ = parse_frontmatter(cmd_md.read_text(encoding="utf-8"))
            result["commands"].append({
                "name": fm.get("name", cmd_md.stem),
                "description": fm.get("description", ""),
            })

    # Agents: <source>/agents/*.md
    agents_dir = plugin_source / "agents"
    if agents_dir.is_dir():
        for agent_md in sorted(agents_dir.glob("*.md")):
            fm, _ = parse_frontmatter(agent_md.read_text(encoding="utf-8"))
            result["agents"].append({
                "name": fm.get("name", agent_md.stem),
                "description": fm.get("description", ""),
            })

    return result


# ---------------------------------------------------------------------------
# HTML page builders
# ---------------------------------------------------------------------------

def html_page(title: str, body: str, spdx_comment: str, extra_head: str = "") -> str:
    return (
        spdx_comment
        + f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{h(title)}</title>
  <link rel="stylesheet" href="style.css">
{extra_head}</head>
<body>
<div class="container">
{body}
</div>
</body>
</html>
"""
    )


def build_component_section(label: str, items: list[dict]) -> str:
    if not items:
        return ""
    rows = "\n".join(
        f"""  <li class="component-item">
    <div class="comp-name">{h(item['name'])}</div>
    {"" if not item['description'] else f'<div class="comp-desc">{h(item["description"])}</div>'}
  </li>"""
        for item in items
    )
    return f"""
<h2>{h(label)}</h2>
<ul class="component-list">
{rows}
</ul>
"""


def build_index_page(
    marketplace: dict,
    plugins_data: list[dict],
    spdx_comment: str,
    marketplace_add_target: str,
) -> str:
    name = marketplace.get("name", "Plugin Marketplace")
    description = marketplace.get("description", "")
    owner = marketplace.get("owner", {})
    owner_name = owner.get("name", "")
    owner_url = owner.get("url", "")

    owner_html = ""
    if owner_name:
        safe_owner_url = safe_url(owner_url) if owner_url else ""
        if safe_owner_url:
            owner_html = (
                f'<div class="owner">By '
                f'<a href="{h(safe_owner_url)}">{h(owner_name)}</a></div>'
            )
        else:
            owner_html = f'<div class="owner">By {h(owner_name)}</div>'

    install_html = f"""
<div class="install-block">
  <p><strong>Add this marketplace:</strong></p>
  <code class="snippet">/plugin marketplace add {h(marketplace_add_target)}</code>
  <p style="margin-top:0.75rem"><strong>Install a plugin:</strong></p>
  <code class="snippet">/plugin install &lt;plugin-name&gt;@{h(name)}</code>
</div>
"""

    cards = "\n".join(
        f"""<div class="plugin-card">
  <h3><a href="{h(slugify(p['name']))}.html">{h(p['name'])}</a></h3>
  <p class="description">{h(p.get('description', ''))}</p>
  {f'<span class="category">{h(p["category"])}</span>' if p.get("category") else ""}
</div>"""
        for p in plugins_data
    )

    body = f"""<header>
  <h1>{h(name)}</h1>
  {"" if not description else f'<p class="subtitle">{h(description)}</p>'}
  {owner_html}
</header>

<h2>Quick install</h2>
{install_html}

<h2>Plugins ({len(plugins_data)})</h2>
<div class="plugin-grid">
{cards}
</div>

<footer>Generated by <code>generate-docs</code> &mdash; {date.today().isoformat()}</footer>
"""
    return html_page(name, body, spdx_comment)


def build_plugin_page(
    plugin_entry: dict,
    plugin_json: dict,
    components: dict[str, list[dict]],
    readme_html: str | None,
    spdx_comment: str,
) -> str:
    plugin_name = plugin_json.get("name", plugin_entry.get("name", ""))
    version = plugin_json.get("version", "")
    description = plugin_json.get("description", plugin_entry.get("description", ""))
    homepage = plugin_json.get("homepage", "")
    keywords = plugin_json.get("keywords", [])

    # Meta row: version badge + keyword tags
    meta_parts = []
    if version:
        meta_parts.append(f'<span class="version-badge">v{h(version)}</span>')
    for kw in keywords:
        meta_parts.append(f'<span class="keyword-tag">{h(kw)}</span>')
    meta_html = (
        f'<div class="meta-row">{" ".join(meta_parts)}</div>' if meta_parts else ""
    )

    # Homepage link
    homepage_html = ""
    if homepage:
        safe_homepage = safe_url(homepage)
        if safe_homepage:
            homepage_html = f'<p><a href="{h(safe_homepage)}">View source on GitHub →</a></p>'
        else:
            homepage_html = f'<p>View source on GitHub → {h(homepage)}</p>'

    # README section
    readme_section = ""
    if readme_html:
        readme_section = f"""
<h2>Overview</h2>
<div class="readme-content">
{readme_html}
</div>
"""

    # Component sections
    comp_html = ""
    comp_html += build_component_section("Skills", components.get("skills", []))
    comp_html += build_component_section("Commands", components.get("commands", []))
    comp_html += build_component_section("Agents", components.get("agents", []))
    if not comp_html.strip():
        comp_html = "<p><em>No skills, commands, or agents found.</em></p>"

    body = f"""<div class="breadcrumb">
  <a href="index.html">← Marketplace</a>
</div>
<header>
  <h1>{h(plugin_name)}</h1>
  {"" if not description else f'<p class="subtitle">{h(description)}</p>'}
  {meta_html}
  {homepage_html}
</header>
{readme_section}
<h2>Components</h2>
{comp_html}

<footer>Generated by <code>generate-docs</code> &mdash; {date.today().isoformat()}</footer>
"""
    return html_page(plugin_name, body, spdx_comment)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a static HTML docs site for a Claude Code plugin marketplace."
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="Path to the repo root containing .claude-plugin/marketplace.json "
             "(default: walk up from cwd)",
    )
    parser.add_argument(
        "--out",
        default="docs",
        help="Output directory name, relative to repo root (default: docs)",
    )
    parser.add_argument(
        "--holder",
        default=None,
        help="Copyright holder for generated SPDX headers (default: marketplace owner.name)",
    )
    parser.add_argument(
        "--license",
        default="MIT",
        dest="spdx_license",
        help="SPDX license identifier for generated files (default: MIT)",
    )
    args = parser.parse_args()

    # Resolve repo root
    if args.repo_root is not None:
        repo_root = args.repo_root.resolve()
        marketplace_path = repo_root / ".claude-plugin" / "marketplace.json"
        if not marketplace_path.exists():
            print(f"Error: {marketplace_path} not found.", file=sys.stderr)
            sys.exit(1)
    else:
        repo_root = find_repo_root(Path.cwd())

    marketplace_path = repo_root / ".claude-plugin" / "marketplace.json"
    try:
        marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"Error: {marketplace_path} is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Resolve copyright holder
    holder = args.holder or marketplace.get("owner", {}).get("name", "Unknown")
    year = date.today().year

    def make_html_spdx() -> str:
        return HTML_SPDX_TEMPLATE.format(
            year=year, holder=holder, license=args.spdx_license
        )

    def make_css_spdx() -> str:
        return CSS_SPDX_TEMPLATE.format(
            year=year, holder=holder, license=args.spdx_license
        )

    # Output directory
    out_dir = repo_root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    files_written: list[str] = []

    # Write style.css
    css_path = out_dir / "style.css"
    css_path.write_text(make_css_spdx() + STYLE_CSS, encoding="utf-8")
    files_written.append(str(css_path.relative_to(repo_root)))

    # Process plugins
    plugins = marketplace.get("plugins", [])
    plugins_data: list[dict] = []
    all_components: list[dict[str, list[dict]]] = []

    for plugin_entry in plugins:
        plugin_name = plugin_entry.get("name", "")
        source_rel = plugin_entry.get("source", f"./plugins/{plugin_name}")
        plugin_source = (repo_root / source_rel).resolve()

        # Load plugin.json
        plugin_json_path = plugin_source / ".claude-plugin" / "plugin.json"
        if plugin_json_path.is_file():
            try:
                plugin_json = json.loads(plugin_json_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as e:
                print(
                    f"  Warning: {plugin_json_path} is not valid JSON: {e}; skipping plugin.",
                    file=sys.stderr,
                )
                continue
        else:
            print(
                f"  Warning: {plugin_json_path} not found; using marketplace entry data.",
                file=sys.stderr,
            )
            plugin_json = {
                "name": plugin_name,
                "description": plugin_entry.get("description", ""),
            }

        # Collect components (once per plugin)
        components = collect_components(plugin_source)
        all_components.append(components)

        # Canonical name from plugin.json, slug for filename
        canonical_name = plugin_json.get("name", plugin_name)
        slug = slugify(canonical_name)

        # Augment plugin entry with category for index page
        plugins_data.append({
            **plugin_entry,
            "name": canonical_name,
            "slug": slug,
        })

        # README
        readme_path = plugin_source / "README.md"
        readme_html = None
        if readme_path.is_file():
            readme_html = render_markdown(readme_path.read_text(encoding="utf-8"))

        # Build plugin page
        page_html = build_plugin_page(
            plugin_entry=plugin_entry,
            plugin_json=plugin_json,
            components=components,
            readme_html=readme_html,
            spdx_comment=make_html_spdx(),
        )
        page_filename = f"{slug}.html"
        (out_dir / page_filename).write_text(page_html, encoding="utf-8")
        files_written.append(str((out_dir / page_filename).relative_to(repo_root)))

    # Derive marketplace add target
    owner_url = marketplace.get("owner", {}).get("url", "")
    marketplace_add_target = derive_marketplace_add_target(
        owner_url, marketplace.get("name", "marketplace")
    )

    # Build index page
    index_html = build_index_page(
        marketplace=marketplace,
        plugins_data=plugins_data,
        spdx_comment=make_html_spdx(),
        marketplace_add_target=marketplace_add_target,
    )
    index_path = out_dir / "index.html"
    index_path.write_text(index_html, encoding="utf-8")
    files_written.insert(0, str(index_path.relative_to(repo_root)))

    # Summary (use already-collected components — no extra collect_components calls)
    skill_count = sum(len(c.get("skills", [])) for c in all_components)
    cmd_count = sum(len(c.get("commands", [])) for c in all_components)
    agent_count = sum(len(c.get("agents", [])) for c in all_components)
    print(f"Generated {len(files_written)} file(s) into {out_dir.relative_to(repo_root)}/:")
    for f in files_written:
        print(f"  {f}")
    print(f"  Plugins: {len(plugins_data)}  Skills: {skill_count}  Commands: {cmd_count}  Agents: {agent_count}")


if __name__ == "__main__":
    main()

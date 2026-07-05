# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Validate an MkDocs-based docs site's Markdown source.

Reads <repo_root>/mkdocs.yml for `docs_dir` (default "docs") and `nav:`, then checks every
*.md file under docs_dir (excluding docs/superpowers/**, which this skill never touches):
  1. internal-link integrity — relative Markdown links (`[text](target)`), raw HTML href/src
     attributes, and each candidate in a srcset must resolve to a file that exists on disk,
     case-sensitively (so a link that works on a case-insensitive macOS FS but would 404 on
     case-sensitive GitHub Pages is caught). Fenced code blocks (``` / ~~~) are excluded from
     every check below — an illustrative `[link](...)`/`<a href>`/`# heading` shown as an
     example isn't real page structure.
  2. anchor integrity — a #fragment must match a heading's slug on the target page (same-page
     or cross-page), using MkDocs/Python-Markdown's default slugify + de-dupe rules (lowercase,
     punctuation other than "_"/"-" stripped, whitespace -> hyphens, repeats suffixed _1, _2,
     ...), or a literal HTML id/name attribute found anywhere on the page.
  3. nav completeness — every *.md file under docs_dir must be reachable from `nav:`
     (docs_dir/index.md is exempt: MkDocs uses it as the implicit homepage even when absent
     from nav), and every `nav:` entry must point at a file that exists.
  4. dual-target portability — no absolute (leading-slash) local refs. Protocol-relative
     (//host) refs fall into this bucket too (empty URL scheme, so NOT treated as external).

External refs (with a scheme), mailto:, and data: are ignored.
Exit 0 = clean, 1 = violations found, 2 = usage / setup error (no mkdocs.yml, no docs_dir).

Overlaps by design with MkDocs' own `validation:` config (nav/link/anchor checks, see
mkdocs.yml) enforced by `mkdocs build --strict` — this script is the fast, offline-capable
pre-check Stage 4 runs first; the real build is still the authoritative second pass, and
also validates things this script doesn't (plugin config, MkDocs-side rendering).
"""

import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote, urlparse

import yaml

DANGEROUS_SCHEMES = ("javascript:", "vbscript:", "file:")

MD_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
HTML_ATTR_RE = re.compile(
    r'\b(?:href|src)\s*=\s*"([^"]+)"|\b(?:href|src)\s*=\s*\'([^\']+)\''
)
SRCSET_RE = re.compile(r'\bsrcset\s*=\s*"([^"]+)"|\bsrcset\s*=\s*\'([^\']+)\'')
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*$", re.MULTILINE)
HTML_ID_RE = re.compile(r'\b(?:id|name)\s*=\s*"([^"]+)"|\b(?:id|name)\s*=\s*\'([^\']+)\'')
# Fenced code blocks (``` or ~~~, 3+) — content inside is a rendered example, not live
# Markdown structure, so a `#`-prefixed shell comment or an illustrative [link](...)/<a href>
# inside one must not be parsed as a real heading/link. Requires a closing fence of the same
# character repeated at least as many times, per CommonMark.
FENCED_CODE_RE = re.compile(r"^(`{3,}|~{3,})[^\n]*\n.*?^\1[`~]*[ \t]*$", re.MULTILINE | re.DOTALL)


def strip_fenced_code(text: str) -> str:
    return FENCED_CODE_RE.sub("", text)


class _TolerantLoader(yaml.SafeLoader):
    """A SafeLoader whose unknown-tag handling is local to this class, not the shared
    yaml.SafeLoader — mutating that global would leak into any other consumer that imports
    this module."""


def _ignore_unknown_tag(loader: yaml.SafeLoader, suffix: str, node: yaml.Node) -> None:
    return None


_TolerantLoader.add_multi_constructor("", _ignore_unknown_tag)


def _tolerant_yaml_load(text: str) -> dict:
    """Load mkdocs.yml tolerating custom tags (e.g. !!python/name:...) we don't need."""
    return yaml.load(text, Loader=_TolerantLoader) or {}


def slugify(heading: str) -> str:
    """Approximate Python-Markdown's default TOC slugify: NFKD-normalize and drop non-ASCII
    (its default unicode=False behavior), lowercase, strip punctuation, whitespace -> hyphens.
    Good enough for link validation, not byte-exact in every case."""
    ascii_only = unicodedata.normalize("NFKD", heading).encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"[^\w\s-]", "", ascii_only.strip().lower())
    return re.sub(r"[\s]+", "-", s)


def heading_anchors_from_prose(prose: str) -> set[str]:
    """Every heading's slug, with MkDocs' duplicate-suffix rule (_1, _2, ...) applied, plus
    any literal HTML id/name attribute. Expects fenced code blocks already stripped from
    `prose` (via strip_fenced_code) — an example `# comment` or `<a id=...>` shown in a fence
    isn't real page structure."""
    seen: dict[str, int] = {}
    anchors: set[str] = set()
    for _, raw in HEADING_RE.findall(prose):
        base = slugify(raw)
        if base not in seen:
            seen[base] = 0
            anchors.add(base)
        else:
            seen[base] += 1
            anchors.add(f"{base}_{seen[base]}")
    for m in HTML_ID_RE.finditer(prose):
        anchors.add(m.group(1) or m.group(2))
    return anchors


def is_external(url: str) -> bool:
    return bool(urlparse(url).scheme)


def split_ref(value: str) -> tuple[str, str]:
    rest, frag = value, ""
    if "#" in rest:
        rest, frag = rest.split("#", 1)
        frag = unquote(frag.split("?", 1)[0])
    return unquote(rest.split("?", 1)[0]), frag


def within_root(target: Path, root: Path) -> bool:
    try:
        target.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False  # genuinely outside root — the common, expected case
    except OSError as e:
        # An I/O error (permission denied, symlink loop) is not "outside root" — the caller
        # still reports it as a violation, but distinctly, so it isn't mistaken for one.
        print(f"warning: could not resolve {target}: {e}", file=sys.stderr)
        return False


def exists_cs(target: Path, root: Path) -> bool:
    """Existence check that is case-sensitive even on a case-insensitive filesystem."""
    if not target.exists():
        return False
    try:
        rel = target.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    except OSError as e:
        print(f"warning: could not resolve {target}: {e}", file=sys.stderr)
        return False
    cur = root.resolve()
    for part in rel.parts:
        try:
            if part not in (e.name for e in cur.iterdir()):
                return False
        except OSError as e:
            print(f"warning: could not list {cur}: {e}", file=sys.stderr)
            return False
        cur = cur / part
    return True


def nav_targets(nav) -> set[str]:
    """Flatten mkdocs.yml's nav: tree (list of str | {title: path} | {title: [nested]}) to
    the set of docs_dir-relative paths it references."""
    targets: set[str] = set()
    if not isinstance(nav, list):
        return targets  # absent, None, or malformed (e.g. a bare string) — nothing to flatten
    for entry in nav:
        if isinstance(entry, str):
            targets.add(entry)
        elif isinstance(entry, dict):
            for value in entry.values():
                if isinstance(value, str):
                    targets.add(value)
                elif isinstance(value, list):
                    targets |= nav_targets(value)
    return targets


def excluded_dirs(config: dict) -> set[str]:
    """Directory-style entries (trailing "/") from mkdocs.yml's own exclude_docs — read from
    the single source of truth instead of hardcoding a second copy that could drift from it."""
    raw = config.get("exclude_docs") or ""
    lines = raw.splitlines() if isinstance(raw, str) else raw
    return {line.strip().rstrip("/") for line in lines if line.strip().endswith("/")}


def is_excluded(md_file: Path, docs_dir: Path, excluded: set[str]) -> bool:
    rel_parts = md_file.relative_to(docs_dir).parts
    return bool(excluded & set(rel_parts[:-1]))


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_docs.py <repo_root>", file=sys.stderr)
        return 2
    repo_root = Path(argv[1])
    mkdocs_yml = repo_root / "mkdocs.yml"
    if not mkdocs_yml.is_file():
        print(f"no mkdocs.yml under {repo_root} — nothing to validate "
              "(this skill requires an existing MkDocs scaffold)", file=sys.stderr)
        return 2

    try:
        config = _tolerant_yaml_load(mkdocs_yml.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        print(f"could not parse {mkdocs_yml}: {e}", file=sys.stderr)
        return 2

    # `or "docs"`, not a dict-get default: a swallowed custom YAML tag (see _TolerantLoader)
    # on this key would leave it present but None, and a bare .get(..., "docs") default only
    # applies when the key is absent — silently producing `repo_root / None` otherwise.
    docs_dir = repo_root / (config.get("docs_dir") or "docs")
    if not docs_dir.is_dir():
        print(f"docs_dir {docs_dir} does not exist — nothing to validate", file=sys.stderr)
        return 2

    excluded = excluded_dirs(config)
    md_files = [p for p in sorted(docs_dir.rglob("*.md"))
                if p.is_file() and not is_excluded(p, docs_dir, excluded)]
    if not md_files:
        print(f"no .md files under {docs_dir} — nothing to validate (did generation run?)",
              file=sys.stderr)
        return 2

    violations: list[str] = []

    # nav completeness: every non-excluded page reachable, index.md exempt (implicit homepage)
    nav_refs = nav_targets(config.get("nav"))
    resolved_nav_paths: set[Path] = set()
    for ref in nav_refs:
        path, _ = split_ref(ref)
        if not path:
            continue
        target = docs_dir / path
        resolved_nav_paths.add(target.resolve())
        if not exists_cs(target, docs_dir):
            violations.append(f"mkdocs.yml: nav entry points at missing file: {ref!r}")
    for md in md_files:
        if md.resolve() in resolved_nav_paths:
            continue
        if md.parent == docs_dir and md.name == "index.md":
            continue  # MkDocs' implicit homepage — no nav: entry required
        violations.append(f"{md}: not reachable from mkdocs.yml's nav: tree")

    # Fenced code blocks are rendered examples, not live Markdown structure — strip them once
    # per file and scan the prose for headings/links/ids, so a `# comment` or an illustrative
    # [link](...)/<a href> shown inside a fence isn't parsed as real page structure. A read
    # failure (permission denied, bad encoding) is its own violation, not a crash — the file
    # is simply absent from prose_texts afterward, same as if it had no anchors/links at all.
    prose_texts: dict[Path, str] = {}
    for md in md_files:
        try:
            prose_texts[md.resolve()] = strip_fenced_code(md.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError) as e:
            violations.append(f"{md}: could not read: {e}")
    anchors_by_file = {path: heading_anchors_from_prose(prose) for path, prose in prose_texts.items()}

    def check_anchor(referrer: Path, target: Path, frag: str, raw: str) -> None:
        anchors = anchors_by_file.get(target.resolve())
        if anchors is not None and frag and frag not in anchors:
            violations.append(f"{referrer}: missing anchor #{frag}: {raw!r}")

    for md in md_files:
        text = prose_texts.get(md.resolve())
        if text is None:
            continue  # already reported as a "could not read" violation above
        refs = [m.group(1) for m in MD_LINK_RE.finditer(text)]
        refs += [m.group(1) or m.group(2) for m in HTML_ATTR_RE.finditer(text)]
        for m in SRCSET_RE.finditer(text):
            # "url 1x, url2 2x" — each comma-separated candidate's URL token
            for candidate in (m.group(1) or m.group(2)).split(","):
                token = candidate.strip().split()
                if token:
                    refs.append(token[0])
        for raw in refs:
            v = raw.strip()
            if not v:
                continue
            if v.lower().startswith(DANGEROUS_SCHEMES):
                violations.append(f"{md}: unsafe or non-portable URL scheme: {raw!r}")
                continue
            if is_external(v):
                continue
            if v.startswith("#"):
                _, frag = split_ref(v)
                check_anchor(md, md, frag, raw)
                continue
            if v.startswith("/"):
                violations.append(
                    f"{md}: absolute or protocol-relative path not portable: {raw!r}"
                )
                continue
            ref, frag = split_ref(v)
            if not ref:
                continue
            target = md.parent / ref
            if not within_root(target, docs_dir):
                violations.append(f"{md}: link escapes docs root: {raw!r}")
                continue
            if not exists_cs(target, docs_dir):
                violations.append(f"{md}: broken internal link: {raw!r}")
                continue
            if frag:
                check_anchor(md, target, frag, raw)

    for v in violations:
        print(v)
    if violations:
        print(f"\n{len(violations)} doc validation issue(s) found.", file=sys.stderr)
        return 1
    print(f"OK: {docs_dir} — {len(md_files)} Markdown file(s), no broken links/anchors, "
          "nav complete, all refs portable.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

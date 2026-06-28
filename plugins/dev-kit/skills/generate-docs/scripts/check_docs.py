# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# /// script
# requires-python = ">=3.11"
# ///
"""Validate a generated docs site.

Checks every *.html file under <docs_dir>, plus a search-index.js if present:
  1. internal-link integrity — relative href/src/srcset targets must exist on disk,
     case-sensitively (so a link that works on a case-insensitive macOS FS but would
     404 on case-sensitive GitHub Pages is caught).
  2. anchor integrity — a #fragment must point at an id/name that exists on the
     target page (same-page or cross-page).
  3. dual-target portability — no absolute (leading-slash) local refs, so the site
     renders from a file:// path and from GitHub Pages alike.

External refs (with a scheme), protocol-relative (//host), mailto:, and data: are
ignored. Exit 0 = clean, 1 = violations found, 2 = usage / nothing to validate.
"""

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

REF_ATTRS = {"href", "src"}
# Schemes that are unsafe (script execution) or non-portable (local file paths) in a
# shipped docs site — flagged rather than silently skipped as "external".
DANGEROUS_SCHEMES = ("javascript:", "vbscript:", "file:")


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.refs: list[tuple[str, str, str]] = []  # (tag, attr, value)
        self.ids: set[str] = set()                  # id/name anchor targets

    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if value is None:
                continue
            if name in REF_ATTRS:
                self.refs.append((tag, name, value))
            elif name == "srcset":
                # "url 1x, url2 2x" → take each candidate's URL token
                for cand in value.split(","):
                    parts = cand.split()
                    if parts:
                        self.refs.append((tag, "srcset", parts[0]))
            elif name in ("id", "name"):
                self.ids.add(value)


def is_external(url: str) -> bool:
    return url.startswith("//") or bool(urlparse(url).scheme)


def split_ref(value: str) -> tuple[str, str]:
    """Return (decoded path, decoded fragment), tolerating ?query and #frag in either order.

    Both parts are percent-decoded so they match the on-disk name and the id/name the
    browser resolves (e.g. "page.html#my%20id" → fragment "my id")."""
    rest, frag = value, ""
    if "#" in rest:
        rest, frag = rest.split("#", 1)
        frag = unquote(frag.split("?", 1)[0])
    return unquote(rest.split("?", 1)[0]), frag


def within_root(target: Path, root: Path) -> bool:
    """True if target stays inside the docs root — links must not escape it (Pages serves /docs)."""
    try:
        target.resolve().relative_to(root.resolve())
        return True
    except (ValueError, OSError):
        return False


def exists_cs(target: Path, root: Path) -> bool:
    """Existence check that is case-sensitive even on a case-insensitive filesystem."""
    if not target.exists():
        return False
    try:
        rel = target.resolve().relative_to(root.resolve())
    except (ValueError, OSError):
        return False  # outside the docs root is never a valid in-site target
    cur = root.resolve()
    for part in rel.parts:
        try:
            if part not in (e.name for e in cur.iterdir()):
                return False
        except OSError:
            return False
        cur = cur / part
    return True


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_docs.py <docs_dir>", file=sys.stderr)
        return 2
    root = Path(argv[1])
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 2

    html_files = [p for p in sorted(root.rglob("*.html")) if p.is_file()]
    if not html_files:
        print(f"no .html files under {root} — nothing to validate (did generation run?)",
              file=sys.stderr)
        return 2

    violations: list[str] = []
    pages: dict[Path, PageParser] = {}
    for hp in html_files:
        try:
            parser = PageParser()
            parser.feed(hp.read_text(encoding="utf-8"))
            pages[hp.resolve()] = parser
        except (OSError, UnicodeDecodeError) as e:
            violations.append(f"{hp}: could not read/parse: {e}")

    def check_anchor(referrer: Path, target: Path, frag: str, raw: str) -> None:
        page = pages.get(target.resolve())
        if page is not None and frag and frag not in page.ids:
            violations.append(f"{referrer}: missing anchor #{frag}: {raw!r}")

    for hp in html_files:
        page = pages.get(hp.resolve())
        if page is None:
            continue
        for tag, attr, value in page.refs:
            v = value.strip()
            if not v:
                continue
            if v.lower().startswith(DANGEROUS_SCHEMES):
                violations.append(
                    f"{hp}: unsafe or non-portable URL scheme: <{tag} {attr}={value!r}>"
                )
                continue
            if is_external(v):
                continue
            if v.startswith("#"):  # same-page anchor — reuse split_ref for query/percent handling
                _, frag = split_ref(v)
                if frag and frag not in page.ids:
                    violations.append(f"{hp}: missing anchor #{frag}: <{tag} {attr}={value!r}>")
                continue
            if v.startswith("/"):
                violations.append(
                    f"{hp}: absolute path not portable to file://: <{tag} {attr}={value!r}>"
                )
                continue
            ref, frag = split_ref(v)
            if not ref:
                continue
            target = hp.parent / ref
            if not within_root(target, root):
                violations.append(
                    f"{hp}: link escapes docs root (404s on Pages): <{tag} {attr}={value!r}>"
                )
                continue
            if not exists_cs(target, root):
                violations.append(f"{hp}: broken internal link: <{tag} {attr}={value!r}>")
                continue
            if frag:
                check_anchor(hp, target, frag, value)

    # The command-palette index, if the site emits one: its url fields drive navigation
    # but live in JS, so the HTML scan above never sees them — validate them too.
    idx = root / "search-index.js"
    if idx.is_file():
        try:
            text = idx.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as e:
            violations.append(f"{idx}: could not read: {e}")
            text = ""
        for m in re.finditer(r'url\s*:\s*"([^"]+)"', text):
            u = m.group(1)
            if u.lower().startswith(DANGEROUS_SCHEMES):
                violations.append(f"{idx}: unsafe or non-portable URL scheme: {u!r}")
                continue
            if is_external(u):
                continue
            if u.startswith("/"):
                violations.append(f"{idx}: absolute path not portable: {u!r}")
                continue
            ref, frag = split_ref(u)
            target = root / ref
            if not within_root(target, root):
                violations.append(f"{idx}: search url escapes docs root: {u!r}")
                continue
            if not exists_cs(target, root):
                violations.append(f"{idx}: broken search url: {u!r}")
                continue
            if frag:
                check_anchor(idx, target, frag, u)

    for v in violations:
        print(v)
    if violations:
        print(f"\n{len(violations)} doc validation issue(s) found.", file=sys.stderr)
        return 1
    print(f"OK: {root} — {len(html_files)} HTML file(s), no broken links/anchors, all refs portable.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

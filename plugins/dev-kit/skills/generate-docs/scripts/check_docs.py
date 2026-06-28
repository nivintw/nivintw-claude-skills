# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

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

#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT


# Tests for plugins/dev-kit/skills/generate-docs/scripts/check_docs.py — the MkDocs-source
# validator. Each test builds a throwaway repo root (mkdocs.yml + docs/) and asserts the
# validator's exit code and output: clean sites pass; broken links, absolute refs, missing
# anchors, orphaned/missing nav entries, and case-mismatched links fail; external/mailto/
# data refs are ignored; and usage/setup-error cases exit 2.
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

# write_mkdocs <nav-yaml-body> — writes mkdocs.yml with docs_dir: docs and the given nav:
# body (already indented 2 spaces, one entry per line). Defaults to just Home: index.md.
write_mkdocs() {
  local nav="${1:-  - Home: index.md}"
  printf 'docs_dir: docs\nnav:\n%s\n' "$nav" >"$SANDBOX/mkdocs.yml"
}

run_check() {
  run uv run "$SCRIPT" "$SANDBOX"
}

@test "clean site passes" {
  write_mkdocs "  - Home: index.md
  - Other: other.md"
  printf '# Home\n\n[x](other.md)\n\n![logo](img/logo.png)\n' >"$SITE/index.md"
  printf '# Other\n\nok\n' >"$SITE/other.md"
  mkdir -p "$SITE/img"; printf 'png' >"$SITE/img/logo.png"
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"Markdown file(s)"* ]]
}

@test "broken internal markdown link fails" {
  write_mkdocs
  printf '# Home\n\n[x](missing.md)\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
  [[ "$output" == *"missing.md"* ]]
}

@test "broken raw HTML href fails" {
  write_mkdocs
  printf '# Home\n\n<a href="missing.md">x</a>\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "broken image ref fails" {
  write_mkdocs
  printf '# Home\n\n![logo](missing.png)\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "absolute local path fails (not portable)" {
  write_mkdocs
  printf '# Home\n\n<img src="/style.css">\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"not portable"* ]]
}

@test "external https, mailto and data refs are ignored" {
  write_mkdocs
  printf '# Home\n\n[e](https://example.com) [m](mailto:a@b.c)\n\n<img src="data:image/png;base64,AAAA">\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "protocol-relative ref fails (not portable)" {
  write_mkdocs
  printf '# Home\n\n<a href="//cdn.example/x.js">p</a>\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"not portable"* ]]
}

@test "unsafe javascript: and file: schemes are rejected" {
  write_mkdocs
  printf '# Home\n\n[x](javascript:alert(1))\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsafe or non-portable URL scheme"* ]]
}

@test "missing same-page anchor fails" {
  write_mkdocs
  printf '# Home\n\n[x](#nope)\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing anchor #nope"* ]]
}

@test "present same-page anchor (from a heading slug) passes" {
  write_mkdocs
  printf '# Home\n\n[x](#a-section)\n\n## A Section\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "duplicate headings get MkDocs' _1, _2 de-dupe suffix" {
  write_mkdocs
  printf '# Home\n\n[x](#dup) [y](#dup_1)\n\n## Dup\n\n## Dup\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "same-page anchor tolerates a trailing query" {
  write_mkdocs
  printf '# Home\n\n[x](#sec?v=1)\n\n## Sec\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "anchor fragment is percent-decoded before matching" {
  write_mkdocs
  printf '# Home\n\n<a href="#my%%20id">x</a><span id="my id"></span>\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "missing cross-page anchor fails" {
  write_mkdocs "  - Home: index.md
  - Other: other.md"
  printf '# Home\n\n[x](other.md#gone)\n' >"$SITE/index.md"
  printf '# Other\n\n## Here\n' >"$SITE/other.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing anchor #gone"* ]]
}

@test "present cross-page anchor passes (fragment before query tolerated)" {
  write_mkdocs "  - Home: index.md
  - Other: other.md"
  printf '# Home\n\n[x](other.md#sec?v=1)\n' >"$SITE/index.md"
  printf '# Other\n\n## Sec\n' >"$SITE/other.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "nested-page relative link resolves from its own directory" {
  write_mkdocs "  - Home: index.md
  - Guide:
    - Start: guide/start.md"
  mkdir -p "$SITE/guide"
  printf '# Start\n\n[home](../index.md)\n' >"$SITE/guide/start.md"
  printf '# Home\n\nhome\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "percent-encoded link resolves to the on-disk name" {
  write_mkdocs "  - Home: index.md
  - Page: my page.md"
  printf '# Home\n\n[x](my%%20page.md)\n' >"$SITE/index.md"
  printf '# Page\n\nok\n' >"$SITE/my page.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "link escaping the docs root fails" {
  write_mkdocs
  printf 'outside' >"$SANDBOX/outside.md"
  printf '# Home\n\n[x](../outside.md)\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"escapes docs root"* ]]
}

@test "case-mismatched link fails (portable to case-sensitive Pages)" {
  write_mkdocs "  - Home: index.md
  - Other: other.md"
  printf '# Home\n\n[x](Other.md)\n' >"$SITE/index.md"
  printf '# Other\n\nok\n' >"$SITE/other.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "multiple violations are all reported and counted" {
  write_mkdocs
  printf '# Home\n\n[1](a.md) [2](b.md)\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"2 doc validation issue(s)"* ]]
}

@test "a page not reachable from nav fails" {
  write_mkdocs  # nav only lists index.md
  printf '# Home\n\nok\n' >"$SITE/index.md"
  printf '# Orphan\n\nok\n' >"$SITE/orphan.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"not reachable from mkdocs.yml's nav"* ]]
  [[ "$output" == *"orphan.md"* ]]
}

@test "docs_dir/index.md is exempt from the nav requirement" {
  # nav lists nothing — MkDocs still serves index.md as the implicit homepage.
  printf 'docs_dir: docs\nnav: []\n' >"$SANDBOX/mkdocs.yml"
  printf '# Home\n\nok\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "a nav entry pointing at a missing file fails" {
  write_mkdocs "  - Home: index.md
  - Gone: gone.md"
  printf '# Home\n\nok\n' >"$SITE/index.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"nav entry points at missing file"* ]]
  [[ "$output" == *"gone.md"* ]]
}

@test "docs/superpowers/** is excluded from both link and nav checks" {
  write_mkdocs  # nav only lists index.md
  printf '# Home\n\nok\n' >"$SITE/index.md"
  mkdir -p "$SITE/superpowers"
  printf '# Spec\n\n[x](missing.md)\n' >"$SITE/superpowers/spec.md"
  run_check
  [ "$status" -eq 0 ]
}

@test "no mkdocs.yml exits 2" {
  run_check
  [ "$status" -eq 2 ]
  [[ "$output" == *"no mkdocs.yml"* ]]
}

@test "empty docs_dir exits 2 (nothing to validate)" {
  write_mkdocs
  run_check
  [ "$status" -eq 2 ]
  [[ "$output" == *"no .md files"* ]]
}

@test "usage error with no repo_root argument" {
  run uv run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

@test "usage error when docs_dir doesn't exist" {
  printf 'docs_dir: nope\nnav:\n  - Home: index.md\n' >"$SANDBOX/mkdocs.yml"
  run_check
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not exist"* ]]
}

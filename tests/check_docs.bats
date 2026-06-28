#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT


# Tests for plugins/dev-kit/skills/generate-docs/scripts/check_docs.py — the docs-site
# validator. Each test builds a throwaway docs/ dir with fixtures and asserts the
# validator's exit code and output: clean sites pass; broken internal links, absolute
# refs, missing anchors, bad srcset, and case-mismatched links fail; external/mailto/
# data refs are ignored; and usage/empty-dir cases exit 2.
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
  printf '<main id="main">ok</main>' >"$SITE/other.html"
  mkdir -p "$SITE/img"; printf 'png' >"$SITE/img/logo.png"
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *"HTML file(s)"* ]]
}

@test "broken internal link (href) fails" {
  printf '<a href="missing.html">x</a>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
  [[ "$output" == *"missing.html"* ]]
}

@test "broken src fails" {
  printf '<img src="missing.png">' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "absolute local path fails (not portable to file://)" {
  printf '<link rel="stylesheet" href="/style.css">' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute path"* ]]
}

@test "external, mailto, data and protocol-relative refs are ignored" {
  printf '<a href="https://example.com">e</a><a href="mailto:a@b.c">m</a>' >"$SITE/index.html"
  printf '<a href="//cdn.example/x.js">p</a><img src="data:image/png;base64,AAAA">' >>"$SITE/index.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "missing same-page anchor fails" {
  printf '<a href="#nope">x</a>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing anchor #nope"* ]]
}

@test "present same-page anchor passes" {
  printf '<a href="#sec">x</a><h2 id="sec">S</h2>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "same-page anchor tolerates a trailing query" {
  printf '<a href="#sec?v=1">x</a><h2 id="sec">S</h2>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "missing cross-page anchor fails" {
  printf '<a href="other.html#gone">x</a>' >"$SITE/index.html"
  printf '<h2 id="here">H</h2>' >"$SITE/other.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing anchor #gone"* ]]
}

@test "present cross-page anchor passes (fragment before query tolerated)" {
  printf '<a href="other.html#sec?v=1">x</a>' >"$SITE/index.html"
  printf '<h2 id="sec">S</h2>' >"$SITE/other.html"
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

@test "percent-encoded link resolves to the on-disk name" {
  printf '<a href="my%%20page.html">x</a>' >"$SITE/index.html"
  printf 'ok' >"$SITE/my page.html"
  run_check
  [ "$status" -eq 0 ]
}

@test "broken srcset candidate fails" {
  printf '<img srcset="logo.png 1x, missing-2x.png 2x">' >"$SITE/index.html"
  printf 'png' >"$SITE/logo.png"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "absolute srcset candidate fails portability" {
  printf '<img srcset="/abs-2x.png 2x">' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute path"* ]]
}

@test "link escaping the docs root fails (would 404 on Pages)" {
  printf 'outside' >"$SANDBOX/outside.html"
  printf '<a href="../outside.html">x</a>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"escapes docs root"* ]]
}

@test "case-mismatched link fails (portable to case-sensitive Pages)" {
  printf '<a href="Other.html">x</a>' >"$SITE/index.html"
  printf 'ok' >"$SITE/other.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken internal link"* ]]
}

@test "multiple violations are all reported and counted" {
  printf '<a href="a.html">1</a><a href="b.html">2</a>' >"$SITE/index.html"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"2 doc validation issue(s)"* ]]
}

@test "search-index.js broken url fails" {
  printf '<a href="other.html">x</a>' >"$SITE/index.html"
  printf 'ok' >"$SITE/other.html"
  printf 'window.SEARCH_INDEX=[{url:"gone.html#x"}];' >"$SITE/search-index.js"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"broken search url"* ]]
}

@test "search-index.js valid url passes" {
  printf '<a href="#sec">x</a><h2 id="sec">S</h2>' >"$SITE/index.html"
  printf 'window.SEARCH_INDEX=[{url:"index.html#sec"}];' >"$SITE/search-index.js"
  run_check
  [ "$status" -eq 0 ]
}

@test "empty docs dir exits 2 (nothing to validate)" {
  run_check
  [ "$status" -eq 2 ]
  [[ "$output" == *"no .html files"* ]]
}

@test "usage error with no directory argument" {
  run uv run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

@test "usage error when given a non-directory" {
  run uv run "$SCRIPT" "$SANDBOX/does-not-exist"
  [ "$status" -eq 2 ]
}

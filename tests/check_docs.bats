#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT


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

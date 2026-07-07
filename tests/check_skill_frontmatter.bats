#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for scripts/check_skill_frontmatter.sh — the line-1-frontmatter scanner. Covers the
# real-tree assertion (this repo's loadable components all pass) plus single-file fixture
# cases for the good (line 1) and bad (frontmatter pushed to line 3) shapes.
# Run:  bats tests/check_skill_frontmatter.bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check_skill_frontmatter.sh"
  SANDBOX="$(mktemp -d)"
}

teardown() {
  rm -rf "$SANDBOX"
}

@test "passes against the real repo tree (all components have line-1 frontmatter)" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line-1 frontmatter"* ]]
}

@test "single file with frontmatter on line 1 passes" {
  local f="$SANDBOX/good.md"
  printf -- '---\nname: good\n---\n\nBody.\n' >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "single file whose frontmatter starts on line 3 is caught and named" {
  local f="$SANDBOX/late.md"
  printf -- '\n<!-- stray comment -->\n---\nname: late\n---\n\nBody.\n' >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"late.md"* ]]
  [[ "$output" == *"line 1 is not the '---' frontmatter opener"* ]]
}

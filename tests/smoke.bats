#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Example bats suite — replace with real tests. Self-contained: no helper libraries,
# plain bash assertions, a throwaway sandbox per test.
# Run:  bats tests/smoke.bats

setup() {
  SANDBOX="$(mktemp -d)"
}

teardown() {
  rm -rf "$SANDBOX"
}

@test "example: the sandbox is a writable temp dir" {
  [ -d "$SANDBOX" ]
  echo "hello" >"$SANDBOX/file"
  run cat "$SANDBOX/file"
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

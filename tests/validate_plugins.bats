#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for scripts/validate-plugins.sh — the hermetic `claude plugin validate --strict`
# guard. Kept deterministic: the CLI-present path asserts the real repo validates clean, and
# the CLI-absent path (forced via a claude-free PATH) asserts the skip notice + exit 0.
# Run:  bats tests/validate_plugins.bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-plugins.sh"
}

@test "skips cleanly (exit 0 + notice) when the claude CLI is absent" {
  # Build a minimal PATH with symlinks to ONLY the utilities the script needs, and nothing
  # else — so `command -v claude` fails deterministically regardless of where claude is
  # installed. A bare PATH=/usr/bin:/bin isn't safe: claude could be installed system-wide
  # there (now or in a future CI image), which would flip this into the validate branch.
  local bindir
  bindir="$(mktemp -d)"
  for util in bash dirname basename mktemp rm; do
    ln -s "$(command -v "$util")" "$bindir/$util"
  done
  run env PATH="$bindir" "$SCRIPT"
  rm -rf "$bindir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude CLI not available — skipping"* ]]
}

@test "validates the real repo clean when claude is available (else skips)" {
  run "$SCRIPT"
  [ "$status" -eq 0 ] # valid repo → 0 whether claude validated it or was absent+skipped
  if command -v claude >/dev/null 2>&1; then
    [[ "$output" == *"validated"* ]]
  else
    [[ "$output" == *"skipping"* ]]
  fi
}

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
  # /usr/bin:/bin keeps coreutils (dirname/cd/etc.) available but excludes claude (installed
  # under ~/.local/bin), forcing the not-available branch deterministically.
  run env PATH="/usr/bin:/bin" "$SCRIPT"
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

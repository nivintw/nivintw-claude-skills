#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# scripts/refresh-binary-checksums.sh's supply-chain tamper gate (refusing to silently
# re-pin a SHA256 when the upstream asset changed under an unchanged *_VERSION) is only
# active when BASE_REF is set. The central Renovate runner (nivintw/repo-management's
# renovate-global.json) sets BASE_REF for every repo and allowlists only the bare script, so
# .github/renovate.json's postUpgradeTask must be exactly that command. Anything else, such
# as a command that also sets BASE_REF inline, is refused by the runner, and the checksum is
# never refreshed.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  RENOVATE_JSON="$ROOT/.github/renovate.json"
}

@test "renovate.json exists and is valid JSON" {
  [ -f "$RENOVATE_JSON" ]
  jq -e . "$RENOVATE_JSON" >/dev/null
}

@test "the checksum-refresh postUpgradeTask is the command the central runner allows" {
  jq -e '
    [.packageRules[]?.postUpgradeTasks?.commands[]? | select(contains("refresh-binary-checksums.sh"))]
    | length > 0 and all(test("^scripts/refresh-binary-checksums\\.sh$"))
  ' "$RENOVATE_JSON" >/dev/null
}

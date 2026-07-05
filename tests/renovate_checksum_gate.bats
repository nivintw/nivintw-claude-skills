#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# scripts/refresh-binary-checksums.sh's supply-chain tamper gate (refusing to silently
# re-pin a SHA256 when the upstream asset changed under an unchanged *_VERSION) is only
# active when BASE_REF is set — .github/renovate.json's postUpgradeTask must pass it, or
# the exact automated run the gate exists for (Renovate re-pinning checksums unattended)
# runs with the gate silently off. Caught by review once already; this is the regression
# guard so it can't happen again without a test failing.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  RENOVATE_JSON="$ROOT/.github/renovate.json"
}

@test "renovate.json exists and is valid JSON" {
  [ -f "$RENOVATE_JSON" ]
  jq -e . "$RENOVATE_JSON" >/dev/null
}

@test "the checksum-refresh postUpgradeTask sets BASE_REF" {
  jq -e '
    [.packageRules[]?.postUpgradeTasks?.commands[]? | select(contains("refresh-binary-checksums.sh"))]
    | length > 0 and all(contains("BASE_REF="))
  ' "$RENOVATE_JSON" >/dev/null
}

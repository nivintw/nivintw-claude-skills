#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for scripts/check_managed_files.sh — the advisory template-owned-edit guard. The
# script derives its manifest/registry paths from its own location's ../tests, so each test
# copies the script into a sandbox <root>/scripts and writes the fixtures under <root>/tests.
# Run:  bats tests/check_managed_files.bats

setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/tests"
  cp "$BATS_TEST_DIRNAME/../scripts/check_managed_files.sh" "$SANDBOX/scripts/"
  SCRIPT="$SANDBOX/scripts/check_managed_files.sh"
}

teardown() {
  rm -rf "$SANDBOX"
}

# Seed a manifest of template-owned files and a divergence registry.
seed_manifests() {
  cat >"$SANDBOX/tests/template-owned-files.txt" <<'EOF'
# template-owned files
.pre-commit-config.yaml
pyproject.toml
.config/release-please-config.json
EOF
  cat >"$SANDBOX/tests/template-divergences.txt" <<'EOF'
# path <whitespace> reason
.config/release-please-config.json    per-plugin release wiring diverges from template
EOF
}

@test "flags an edit to a template-owned file NOT in the registry" {
  seed_manifests
  run "$SCRIPT" pyproject.toml
  [ "$status" -eq 0 ] # advisory: always exit 0
  [[ "$output" == *"WARNING: 'pyproject.toml' is a template-owned file edited outside the reconcile flow"* ]]
}

@test "does NOT flag an edit to a registered divergence" {
  seed_manifests
  run "$SCRIPT" .config/release-please-config.json
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARNING"* ]]
  [[ "$output" == *"no unregistered template-owned edits"* ]]
}

@test "does NOT flag an edit to a non-template file" {
  seed_manifests
  run "$SCRIPT" plugins/dev-kit/skills/ship/SKILL.md
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARNING"* ]]
  [[ "$output" == *"no unregistered template-owned edits"* ]]
}

@test "no-ops with an informational note when no manifest is present" {
  # no seed_manifests → tests/template-owned-files.txt absent
  run "$SCRIPT" pyproject.toml
  [ "$status" -eq 0 ]
  [[ "$output" == *"no template-owned manifest"* ]]
}

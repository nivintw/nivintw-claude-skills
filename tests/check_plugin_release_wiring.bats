#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for scripts/check_plugin_release_wiring.py — the release-please consistency gate.
# Each test builds a throwaway repo layout in a sandbox (the script derives its repo root
# from its own location, so a copy under <sandbox>/scripts treats <sandbox> as the root).
# Run:  bats tests/check_plugin_release_wiring.bats

setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/.config"
  cp "$BATS_TEST_DIRNAME/../scripts/check_plugin_release_wiring.py" "$SANDBOX/scripts/"
  SCRIPT="$SANDBOX/scripts/check_plugin_release_wiring.py"
}

teardown() {
  rm -rf "$SANDBOX"
}

# Write a plugin.json on disk: mkplugin <name> <version>
mkplugin() {
  mkdir -p "$SANDBOX/plugins/$1/.claude-plugin"
  printf '{ "name": "%s", "version": "%s" }\n' "$1" "$2" \
    >"$SANDBOX/plugins/$1/.claude-plugin/plugin.json"
}

# A consistent baseline: two plugins, both wired into config (with the extra-files entry
# that bumps plugin.json) + manifest, versions agree.
good_repo() {
  mkplugin castify 0.2.0
  mkplugin dev-kit 0.1.0
  cat >"$SANDBOX/.config/release-please-config.json" <<'EOF'
{
  "packages": {
    "plugins/castify": {
      "release-type": "simple", "component": "castify",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    },
    "plugins/dev-kit": {
      "release-type": "simple", "component": "dev-kit",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    }
  }
}
EOF
  cat >"$SANDBOX/.config/.release-please-manifest.json" <<'EOF'
{ "plugins/castify": "0.2.0", "plugins/dev-kit": "0.1.0" }
EOF
}

@test "passes when every plugin is consistently wired" {
  good_repo
  run python3 "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 plugin(s) consistently wired"* ]]
}

@test "fails when a plugin on disk is missing from the config" {
  good_repo
  cat >"$SANDBOX/.config/release-please-config.json" <<'EOF'
{
  "packages": {
    "plugins/castify": {
      "release-type": "simple", "component": "castify",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    }
  }
}
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/dev-kit: on disk but missing from .config/release-please-config.json"* ]]
}

@test "fails when a plugin on disk is missing from the manifest" {
  good_repo
  cat >"$SANDBOX/.config/.release-please-manifest.json" <<'EOF'
{ "plugins/castify": "0.2.0" }
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/dev-kit: on disk but missing from .config/.release-please-manifest.json"* ]]
}

@test "fails on an orphan config entry with no plugin on disk" {
  good_repo
  cat >"$SANDBOX/.config/release-please-config.json" <<'EOF'
{
  "packages": {
    "plugins/castify": {
      "release-type": "simple", "component": "castify",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    },
    "plugins/dev-kit": {
      "release-type": "simple", "component": "dev-kit",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    },
    "plugins/ghost": {
      "release-type": "simple", "component": "ghost",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    }
  }
}
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/ghost: in .config/release-please-config.json but no plugin exists on disk"* ]]
}

@test "fails on version drift between plugin.json and the manifest" {
  good_repo
  cat >"$SANDBOX/.config/.release-please-manifest.json" <<'EOF'
{ "plugins/castify": "0.2.0", "plugins/dev-kit": "9.9.9" }
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/dev-kit: version drift"* ]]
}

@test "fails when a registered plugin lacks the plugin.json extra-files wiring" {
  good_repo
  # dev-kit is registered but missing the extra-files entry that bumps its plugin.json.
  cat >"$SANDBOX/.config/release-please-config.json" <<'EOF'
{
  "packages": {
    "plugins/castify": {
      "release-type": "simple", "component": "castify",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    },
    "plugins/dev-kit": { "release-type": "simple", "component": "dev-kit" }
  }
}
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/dev-kit: .config/release-please-config.json package is missing the extra-files entry"* ]]
}

@test "fails on an orphan manifest entry with no plugin on disk" {
  good_repo
  cat >"$SANDBOX/.config/.release-please-manifest.json" <<'EOF'
{ "plugins/castify": "0.2.0", "plugins/dev-kit": "0.1.0", "plugins/ghost": "0.0.1" }
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/ghost: in .config/.release-please-manifest.json but no plugin exists on disk"* ]]
}

@test "fails when a plugin's extra-files entry has the wrong type" {
  good_repo
  cat >"$SANDBOX/.config/release-please-config.json" <<'EOF'
{
  "packages": {
    "plugins/castify": {
      "release-type": "simple", "component": "castify",
      "extra-files": [ { "type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    },
    "plugins/dev-kit": {
      "release-type": "simple", "component": "dev-kit",
      "extra-files": [ { "type": "yaml", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version" } ]
    }
  }
}
EOF
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/dev-kit: .config/release-please-config.json package is missing the extra-files entry"* ]]
}

@test "fails when a plugin.json has no string version field" {
  good_repo
  mkdir -p "$SANDBOX/plugins/nover/.claude-plugin"
  echo '{ "name": "nover" }' >"$SANDBOX/plugins/nover/.claude-plugin/plugin.json"
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"'version' must be a non-empty string"* ]]
}

@test "fails on malformed release-please-config.json" {
  good_repo
  echo 'not json' >"$SANDBOX/.config/release-please-config.json"
  run python3 "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not valid JSON"* ]]
}

@test "the real repository is consistently wired" {
  run python3 "$BATS_TEST_DIRNAME/../scripts/check_plugin_release_wiring.py"
  [ "$status" -eq 0 ]
}

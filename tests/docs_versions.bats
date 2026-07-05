#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# The docs version badges are rendered from per-plugin docs/versions/<name>.js shims that
# release-please bumps on release (a `generic` extra-files updater, one version per file so
# the unscoped updater can't clobber another plugin). release-please keeps each shim in sync
# with the plugin's version going forward; this test guards the *initial* value (and any
# stray hand-edit) by asserting every shim equals its entry in the release-please manifest —
# the single source of truth. If they ever diverge, the badge is lying.

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  MANIFEST="$ROOT/.config/.release-please-manifest.json"
}

@test "manifest exists and is valid JSON" {
  [ -f "$MANIFEST" ]
  jq -e . "$MANIFEST" >/dev/null
}

@test "each docs/versions/<name>.js version matches the release-please manifest" {
  shopt -s nullglob
  local shims=("$ROOT"/docs/versions/*.js)
  [ "${#shims[@]}" -gt 0 ] # there should be at least one shim to check

  for f in "${shims[@]}"; do
    local name shim_v manifest_v
    name="$(basename "$f" .js)"
    # Pull the version *value* from the `x-release-please-version` line — the quoted string
    # in `{ "<name>": "<version>" }` — so it survives a pre-release/build suffix (e.g.
    # 1.0.0-rc.1) that a bare \d+.\d+.\d+ grep would truncate and false-flag as drift.
    shim_v="$(grep 'x-release-please-version' "$f" | sed -nE 's/.*"[^"]+"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
    manifest_v="$(jq -r --arg p "plugins/$name" '.[$p] // empty' "$MANIFEST")"

    [ -n "$shim_v" ] || { echo "no annotated version in $f"; return 1; }
    [ -n "$manifest_v" ] || { echo "no manifest entry for plugins/$name (shim has $shim_v)"; return 1; }
    [ "$shim_v" = "$manifest_v" ] || { echo "version drift for $name: shim=$shim_v manifest=$manifest_v"; return 1; }
  done
}

@test "every [data-version] badge has its versions/<name>.js shim wired into mkdocs.yml" {
  # MkDocs pages are Markdown, and the shims load once site-wide via mkdocs.yml's
  # extra_javascript (badges.js hydrates every badge from them) rather than a per-page
  # <script> tag, so the check moves from "same page" to "same mkdocs.yml".
  shopt -s nullglob
  local pages=("$ROOT"/docs/*.md)
  [ "${#pages[@]}" -gt 0 ]

  grep -qE 'assets/badges\.js' "$ROOT/mkdocs.yml" \
    || { echo "mkdocs.yml's extra_javascript is missing assets/badges.js (the hydration script)"; return 1; }

  local all_names=""
  for page in "${pages[@]}"; do
    local names
    names="$(grep -oE 'data-version="[^"]+"' "$page" | sed -E 's/data-version="([^"]+)"/\1/')"
    all_names="$all_names
$names"
  done

  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -f "$ROOT/docs/versions/$name.js" ] || { echo "badge data-version=$name but docs/versions/$name.js is missing"; return 1; }
    grep -qE "versions/$name\.js" "$ROOT/mkdocs.yml" \
      || { echo "badge data-version=$name but mkdocs.yml's extra_javascript doesn't load versions/$name.js"; return 1; }
  done <<<"$(printf '%s\n' "$all_names" | sort -u)"
}

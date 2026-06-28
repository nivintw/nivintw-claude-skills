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

@test "every [data-version] badge loads its versions/<name>.js shim on the same page" {
  shopt -s nullglob
  local pages=("$ROOT"/docs/*.html)
  [ "${#pages[@]}" -gt 0 ]

  for page in "${pages[@]}"; do
    # every distinct data-version="X" referenced on this page...
    local names
    names="$(grep -oE 'data-version="[^"]+"' "$page" | sed -E 's/data-version="([^"]+)"/\1/' | sort -u)"
    [ -n "$names" ] || continue
    while IFS= read -r name; do
      # ...must have its shim file, and a <script> loading it on this page.
      [ -f "$ROOT/docs/versions/$name.js" ] || { echo "$(basename "$page"): badge data-version=$name but docs/versions/$name.js is missing"; return 1; }
      grep -qE "versions/$name\.js" "$page" || { echo "$(basename "$page"): badge data-version=$name but no <script src=versions/$name.js> on the page"; return 1; }
    done <<<"$names"
  done
}

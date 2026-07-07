#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Validate this marketplace's plugin + marketplace manifests with `claude plugin validate
# --strict`, in a HERMETIC temp HOME so the CLI validates THIS repo's manifests rather than
# whatever the developer happens to have installed. --strict fails on unrecognized fields,
# missing metadata, and other issues the runtime tolerates — catching manifest / registration
# errors before they ship.
#
# Placement decision: this guard is MARKETPLACE-SPECIFIC (it knows about
# .claude-plugin/marketplace.json and plugins/<name>) — it stays repo-local and is NOT
# promoted to the copier-everything template baseline.
#
# CI-safe: if the `claude` CLI is not on PATH, print a skip notice and exit 0 so a runner
# without it does not hard-fail. If claude IS present and validation fails, exit non-zero.
#
# Usage: scripts/validate-plugins.sh

set -uo pipefail

# Resolve the repo root from this script's location so it works from any CWD.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not available — skipping plugin validation."
  exit 0
fi

# Hermetic HOME: claude resolves installed marketplaces/plugins relative to HOME; point it at
# an empty temp dir so validation is against the repo manifests only, not the real config.
# Hard-error on a failed mktemp (set -e isn't enabled): an empty TMP_HOME would set HOME="" and
# validate against a non-hermetic HOME — the exact thing this indirection exists to prevent.
TMP_HOME="$(mktemp -d)" || {
  echo "error: failed to create a temp HOME for hermetic validation." >&2
  exit 1
}
[ -n "$TMP_HOME" ] || {
  echo "error: mktemp returned an empty path." >&2
  exit 1
}
cleanup() { rm -rf "$TMP_HOME"; }
trap cleanup EXIT

had_failure=0

validate() { # validate <path> <label>
  echo "--- Validating $2 ---"
  if ! HOME="$TMP_HOME" claude plugin validate --strict "$1"; then
    had_failure=1
  fi
}

# The marketplace registry first, then each plugin manifest.
validate "$REPO_ROOT/.claude-plugin/marketplace.json" "marketplace"

for plugin_dir in "$REPO_ROOT"/plugins/*/; do
  [ -d "$plugin_dir" ] || continue
  validate "$plugin_dir" "$(basename "$plugin_dir")"
done

if [ "$had_failure" -ne 0 ]; then
  echo "Plugin validation FAILED." >&2
  exit 1
fi

echo "All plugin + marketplace manifests validated."

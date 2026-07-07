#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Advisory managed-files guard. Given a set of candidate changed files, warn about any that is
# TEMPLATE-OWNED (rendered from the copier-everything template) being edited "outside the
# reconcile flow" — i.e. not registered as an intentional divergence. Such edits get clobbered
# on the next `copier update`; they should go through `/dev-kit:template-reconcile` (and be
# registered if the divergence is deliberate).
#
# Inputs (both optional, repo-relative):
#   tests/template-owned-files.txt  — one repo-relative path per line ('#' comments allowed):
#                                     the set of files the template renders/owns.
#   tests/template-divergences.txt  — the divergence registry: first whitespace field of each
#                                     non-comment line is a path allowed to diverge.
#
# Behaviour is FAIL-OPEN / advisory: if tests/template-owned-files.txt is absent it is a no-op
# (prints an informational note and exits 0), so it does nothing harmful before the manifest
# is adopted. The divergence registry (tests/template-divergences.txt) already ships in this
# repo; the template-owned-files.txt manifest is the still-missing gate — a full
# template-reconcile run derives it from the render. It never blocks; its purpose is reporting.
#
# Placement decision: this is a TEMPLATE-LAYER concern — it belongs in copier-everything
# alongside template-reconcile (which can actually derive the template-owned set from the
# render). Kept here as a thin repo-local advisory driven by an explicit committed manifest,
# pending the template-side build.
#
# Usage: scripts/check_managed_files.sh <path> [<path> ...]
# Always exits 0 (advisory).

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OWNED_FILE="$REPO_ROOT/tests/template-owned-files.txt"
DIVERGENCE_FILE="$REPO_ROOT/tests/template-divergences.txt"

if [ ! -f "$OWNED_FILE" ]; then
  echo "check_managed_files: no template-owned manifest at tests/template-owned-files.txt yet — nothing to check."
  exit 0
fi

# Load a newline-delimited set from a file, stripping '#' comments and blank lines. For the
# divergence registry, keep only the first whitespace field (the path).
load_set() { # load_set <file> <first-field-only:0|1>
  local file="$1" first_only="$2" line path
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}" # drop trailing comment
    # trim surrounding whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    if [ "$first_only" = "1" ]; then
      path="${line%%[[:space:]]*}" # first whitespace-delimited field
    else
      path="$line"
    fi
    printf '%s\n' "$path"
  done <"$file"
}

owned_set="$(load_set "$OWNED_FILE" 0)"
divergence_set="$(load_set "$DIVERGENCE_FILE" 1)"

in_set() { # in_set <needle> <newline-set>
  local needle="$1" set="$2" item
  while IFS= read -r item; do
    [ "$item" = "$needle" ] && return 0
  done <<<"$set"
  return 1
}

flagged=0
for candidate in "$@"; do
  if in_set "$candidate" "$owned_set" && ! in_set "$candidate" "$divergence_set"; then
    echo "WARNING: '$candidate' is a template-owned file edited outside the reconcile flow."
    echo "         Route it through /dev-kit:template-reconcile (and register it in"
    echo "         tests/template-divergences.txt if the divergence is intentional)."
    flagged=$((flagged + 1))
  fi
done

if [ "$flagged" -eq 0 ]; then
  echo "check_managed_files: no unregistered template-owned edits among the candidates."
fi

# Advisory only — never block.
exit 0

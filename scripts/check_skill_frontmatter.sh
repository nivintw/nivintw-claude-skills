#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Fail if any loadable component markdown has its YAML frontmatter NOT on line 1. Claude Code
# requires the `---` frontmatter opener to be the very first line; a stray blank line or
# comment above it makes the skill/command/agent silently fail to load — it never registers
# and there is NO error. This scanner catches that invisible failure.
#
# Scans exactly the loadable component files:
#   plugins/*/skills/*/SKILL.md, plugins/*/commands/*.md, plugins/*/agents/*.md
# It deliberately does NOT scan reference/**, CHANGELOG.md, or other plain docs (those
# legitimately have no frontmatter).
#
# Placement decision: this check is USEFUL TO ANY skill-authoring repo — recommend promoting
# it to the copier-everything template baseline (as a hook) so the fleet inherits it. Kept
# repo-local for now as a gate check.
#
# Usage:
#   scripts/check_skill_frontmatter.sh            # scan the whole repo tree
#   scripts/check_skill_frontmatter.sh <file.md>  # check a single file (hook-friendly)
# Exit 0 if all good; non-zero if any offender.

set -uo pipefail

offenders=()

# Assert line 1 of a file is exactly the `---` frontmatter opener; record offenders.
check_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  IFS= read -r first_line <"$f" || first_line=""
  if [ "$first_line" != "---" ]; then
    offenders+=("$f — line 1 is not the '---' frontmatter opener (found: '${first_line}')")
  fi
}

if [ "$#" -ge 1 ]; then
  # Single-file mode (e.g. for a future PreToolUse hook).
  check_file "$1"
else
  # Whole-tree mode: resolve the repo root via git so it works from any CWD.
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$repo_root" ]; then
    echo "check_skill_frontmatter: not in a git repository." >&2
    exit 1
  fi
  # Glob the three loadable component shapes; nullglob so absent shapes vanish.
  shopt -s nullglob
  for f in \
    "$repo_root"/plugins/*/skills/*/SKILL.md \
    "$repo_root"/plugins/*/commands/*.md \
    "$repo_root"/plugins/*/agents/*.md; do
    check_file "$f"
  done
  shopt -u nullglob
fi

if [ "${#offenders[@]}" -ne 0 ]; then
  echo "Frontmatter must be on line 1 of every loadable component. Offenders:" >&2
  for o in "${offenders[@]}"; do
    echo "  - $o" >&2
  done
  exit 1
fi

echo "All loadable component markdown has line-1 frontmatter."

#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

set -euo pipefail

# plugin-doctor — report each installed plugin-cache version against the latest
# released version, flagging drift. Backs /dev-kit:doctor's version-drift check.
#
# Usage: plugin-doctor.sh [marketplace] [owner/repo]
#   marketplace : cache dir under ~/.claude/plugins/cache (default: nivintw-claude-skills)
#   owner/repo  : GitHub repo whose <plugin>-v<ver> release tags are the source of truth
#                 (default: nivintw/<marketplace>)
#
# Always exits 0 — this is a report, not a gate. Drift is signalled in the STATUS column and
# a final summary line, so a caller running it as a plain command never sees a "failure".

marketplace="${1:-nivintw-claude-skills}"
repo="${2:-nivintw/${marketplace}}"
cache="${HOME}/.claude/plugins/cache/${marketplace}"

if [ ! -d "$cache" ]; then
  echo "No plugin cache for '${marketplace}' at ${cache}." >&2
  exit 0
fi

# Latest released version per plugin, parsed from <plugin>-v<ver> git tags (one network
# call). Records are "plugin<TAB>version"; absent gh or tags, the map is empty and every
# plugin reports "latest unknown" rather than failing.
releases=""
if command -v gh >/dev/null 2>&1; then
  releases="$(gh api "repos/${repo}/tags" --paginate -q '.[].name' 2>/dev/null |
    sed -n 's/^\(.*\)-v\([0-9][0-9.]*\)$/\1	\2/p' || true)"
fi

latest_for() {
  [ -n "$releases" ] || return 0
  printf '%s\n' "$releases" | awk -F'\t' -v p="$1" '$1 == p {print $2}' | sort -V | tail -1
}

drift=0
printf '%-14s %-18s %-10s %s\n' "PLUGIN" "INSTALLED" "LATEST" "STATUS"
for dir in "$cache"/*/; do
  [ -d "$dir" ] || continue
  plugin="$(basename "$dir")"

  versions="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V)"
  [ -n "$versions" ] || continue
  newest="$(printf '%s\n' "$versions" | tail -1)"
  count="$(printf '%s\n' "$versions" | grep -c .)"
  installed="$newest"
  [ "$count" -gt 1 ] && installed="$newest ($count cached)"

  latest="$(latest_for "$plugin")"
  if [ -z "$latest" ]; then
    status="latest unknown (no gh / no release tag)"
  elif [ "$newest" = "$latest" ]; then
    status="ok"
  elif [ "$(printf '%s\n%s\n' "$newest" "$latest" | sort -V | head -1)" = "$newest" ]; then
    status="DRIFT — $latest released; run /reload-plugins"
    drift=1
  else
    status="ahead of released $latest"
  fi

  printf '%-14s %-18s %-10s %s\n' "$plugin" "$installed" "${latest:-?}" "$status"
done

echo
if [ "$drift" -ne 0 ]; then
  echo "DRIFT: at least one installed plugin is behind its latest release — run /reload-plugins."
else
  echo "No drift detected against the latest releases that were resolvable."
fi
exit 0

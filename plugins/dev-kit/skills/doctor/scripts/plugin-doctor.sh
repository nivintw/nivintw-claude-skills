#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

set -euo pipefail

# plugin-doctor — report each installed plugin-cache version against the latest
# released version, flagging drift, and classify each installed hook as blocking vs
# advisory. Backs /dev-kit:doctor's version-drift check and hook inventory.
#
# Usage: plugin-doctor.sh [marketplace] [owner/repo]
#   marketplace : cache dir under ~/.claude/plugins/cache (default: nivintw-claude-skills)
#   owner/repo  : GitHub repo whose <plugin>-v<ver> release tags are the source of truth
#                 (default: nivintw/<marketplace>)
#
# The INSTALLED version is read from each cached entry's .claude-plugin/plugin.json (the
# manifest is canonical), not from the cache directory's name — so a mislabeled or renamed
# cache dir can't misreport what's installed.
#
# The one release-tag lookup distinguishes a real transport/auth failure (the tags call
# itself errored → degrade to cache-only, explicitly) from a plugin that simply has no
# release yet (the call succeeded but no <plugin>-v* tag matched). The two used to collapse
# into an indistinguishable "latest unknown".
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
# call). Records are "plugin<TAB>version". The fetch is split three ways so a transport
# failure never masquerades as "no release":
#   tags_status=ok           — tags fetched (a plugin with no matching tag = "no release yet")
#   tags_status=no-gh        — gh not installed; can't resolve any latest
#   tags_status=not-found    — the tags endpoint 404'd (repo missing/renamed) → cache-only
#   tags_status=fetch-failed — network/auth/other transport error → cache-only
releases=""
tags_status="ok"
tags_detail=""
if ! command -v gh >/dev/null 2>&1; then
  tags_status="no-gh"
elif gh_err="$(mktemp 2>/dev/null)" && [ -n "$gh_err" ]; then
  # `mktemp` runs in the `elif` condition so a failure there is `set -e`-exempt and falls to the
  # else branch below (degrade to cache-only) rather than exiting non-zero — this tool always
  # exits 0.
  if raw="$(gh api "repos/${repo}/tags" --paginate -q '.[].name' 2>"$gh_err")"; then
    releases="$(printf '%s\n' "$raw" | sed -n 's/^\(.*\)-v\([0-9][0-9.]*\)$/\1	\2/p')"
  elif grep -q 'HTTP 404' "$gh_err"; then
    tags_status="not-found"
    tags_detail="repo or tags endpoint not found (HTTP 404)"
  else
    tags_status="fetch-failed"
    tags_detail="$(sed -n '1p' "$gh_err" | tr -d '\r')"
    [ -n "$tags_detail" ] || tags_detail="network/auth failure"
  fi
  rm -f "$gh_err"
else
  # Couldn't create a temp file to capture gh's stderr — degrade to cache-only, don't exit.
  tags_status="fetch-failed"
  tags_detail="could not create a temp file for the release lookup"
fi

latest_for() {
  [ -n "$releases" ] || return 0
  printf '%s\n' "$releases" | awk -F'\t' -v p="$1" '$1 == p {print $2}' | sort -V | tail -1
}

# Canonical installed version: read `.version` from the manifest, not the cache dir name.
# jq if present, else a tolerant sed fallback; empty output lets the caller fall back to the
# directory name.
read_version() {
  local f="$1"
  [ -f "$f" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.version // empty' "$f" 2>/dev/null
  else
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1
  fi
}

# --- Skill inventory ------------------------------------------------------------------
# Harvest a skill's `name` and the trimmed first sentence of its `description` from a
# SKILL.md's YAML frontmatter (the `>-` folded description is joined into one line first,
# then cut at the first ". "). Emits "name<TAB>purpose". This moves the marketplace
# inventory's per-skill frontmatter parsing off the model and into the helper.
skill_purpose() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" { exit }
    infm && /^name:/ { name=$0; sub(/^name:[[:space:]]*/,"",name); next }
    infm && /^description:/ { indesc=1; next }
    infm && indesc && /^[A-Za-z_-]+:/ { indesc=0 }
    infm && indesc { line=$0; sub(/^[[:space:]]+/,"",line); desc=desc (desc==""?"":" ") line }
    END {
      s=desc
      if (match(s, /\. /)) s=substr(s,1,RSTART)
      if (name != "") printf "%s\t%s\n", name, s
    }
  ' "$f"
}

# --- Hook classification --------------------------------------------------------------
# Heuristic (blocking vs advisory): a hook is BLOCKING when it runs on a decision-capable
# event — one whose output/exit can veto an action (PreToolUse, UserPromptSubmit, Stop,
# SubagentStop) — AND its command script emits a veto (a `deny` permission decision, a
# `block` decision, or a deliberate `exit 2` / `sys.exit(2)`). Everything else is ADVISORY:
# a non-decision event (PostToolUse, SessionStart/End, Notification, PreCompact) can only
# annotate/inject/log, and a decision-capable event whose script never vetoes just observes.
# When the event is decision-capable but the script can't be located to confirm, it's
# reported "blocking?" — the event alone gives it the power, we just couldn't verify use.
DECISION_EVENTS=" PreToolUse UserPromptSubmit Stop SubagentStop "

is_decision_event() {
  case "$DECISION_EVENTS" in
  *" $1 "*) return 0 ;;
  *) return 1 ;;
  esac
}

# Resolve a hook's command string to the on-disk script it runs: expand ${CLAUDE_PLUGIN_ROOT}
# to the cached version dir, then pick the first token that is an existing file (skips a
# leading interpreter like `python3`). Empty (return 1) when nothing resolves.
resolve_hook_script() {
  local cmd="$1" vdir="$2" tok
  local -a toks
  cmd="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$vdir}"
  cmd="${cmd//\$CLAUDE_PLUGIN_ROOT/$vdir}"
  read -ra toks <<<"$cmd"
  for tok in "${toks[@]}"; do
    if [ -f "$tok" ]; then
      printf '%s\n' "$tok"
      return 0
    fi
  done
  return 1
}

script_vetoes() {
  local f="$1"
  [ -f "$f" ] || return 1
  grep -Eq '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"|"decision"[[:space:]]*:[[:space:]]*"block"|exit[[:space:]]+2([^0-9]|$)|sys\.exit\(2\)' "$f"
}

# Classify every hook in one plugin's newest cached version and append TSV rows
# (plugin<TAB>event<TAB>matcher<TAB>class<TAB>hook) to the global hook_rows.
classify_plugin_hooks() {
  local plugin="$1" vdir="$2" hj="$2/hooks/hooks.json"
  [ -f "$hj" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    hooks_need_jq=1
    return 0
  fi
  local event matcher command script cls hookname
  while IFS=$'\t' read -r event matcher command; do
    [ -n "$event" ] || continue
    hookname="$command"
    script="$(resolve_hook_script "$command" "$vdir" || true)"
    [ -n "$script" ] && hookname="$(basename "$script")"
    cls="advisory"
    if is_decision_event "$event"; then
      if [ -n "$script" ]; then
        script_vetoes "$script" && cls="blocking"
      else
        cls="blocking?"
      fi
    fi
    hook_rows+="${plugin}	${event}	${matcher}	${cls}	${hookname}"$'\n'
  done < <(jq -r '.hooks // {} | to_entries[] | .key as $e | .value[]? | (.matcher // "*") as $m | .hooks[]? | [$e, $m, (.command // "")] | @tsv' "$hj" 2>/dev/null)
}

drift=0
hook_rows=""
skill_rows=""
hooks_need_jq=0
printf '%-14s %-18s %-10s %s\n' "PLUGIN" "INSTALLED" "LATEST" "STATUS"
for dir in "$cache"/*/; do
  [ -d "$dir" ] || continue
  plugin="$(basename "$dir")"

  versions="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V)"
  [ -n "$versions" ] || continue
  newest_dir="$(printf '%s\n' "$versions" | tail -1)"
  count="$(printf '%s\n' "$versions" | grep -c .)"
  vdir="${dir}${newest_dir}"

  # Manifest-canonical installed version; fall back to the dir name only if unreadable.
  installed_ver="$(read_version "${vdir}/.claude-plugin/plugin.json")"
  [ -n "$installed_ver" ] || installed_ver="$newest_dir"
  installed="$installed_ver"
  [ "$count" -gt 1 ] && installed="$installed_ver ($count cached)"

  if [ "$tags_status" = "not-found" ] || [ "$tags_status" = "fetch-failed" ]; then
    # Transport/lookup failure: can't judge drift for anyone — say so per row, cache-only.
    latest=""
    status="release lookup failed — ${tags_detail}; cached-only"
  else
    latest="$(latest_for "$plugin")"
    if [ -z "$latest" ]; then
      if [ "$tags_status" = "no-gh" ]; then
        status="latest unknown (no gh)"
      else
        status="no release yet (no ${plugin}-v* tag)"
      fi
    elif [ "$installed_ver" = "$latest" ]; then
      status="ok"
    elif [ "$(printf '%s\n%s\n' "$installed_ver" "$latest" | sort -V | head -1)" = "$installed_ver" ]; then
      status="DRIFT — $latest published; autoupdate will fetch it, then /reload-plugins (or it's live next session)"
      drift=1
    else
      status="ahead of released $latest"
    fi
  fi

  printf '%-14s %-18s %-10s %s\n' "$plugin" "$installed" "${latest:-?}" "$status"

  classify_plugin_hooks "$plugin" "$vdir"

  # Harvest the skill inventory for this plugin's newest cached version.
  if [ -d "${vdir}/skills" ]; then
    for skdir in "${vdir}/skills"/*/; do
      skf="${skdir}SKILL.md"
      [ -f "$skf" ] || continue
      while IFS=$'\t' read -r sname spurpose; do
        [ -n "$sname" ] && skill_rows+="${plugin}	${sname}	${spurpose}"$'\n'
      done < <(skill_purpose "$skf")
    done
  fi
done

echo
if [ "$tags_status" = "not-found" ] || [ "$tags_status" = "fetch-failed" ]; then
  echo "Release lookup FAILED (${tags_detail}) — the versions above are cache-only; latest-released could not be resolved, so drift can't be judged. This is a transport/auth error, distinct from a plugin that simply has no release yet."
elif [ "$drift" -ne 0 ]; then
  echo "DRIFT: at least one installed plugin is behind its latest release — autoupdate will fetch it; then /reload-plugins (or it's live next session)."
else
  echo "No drift detected against the latest releases that were resolvable."
fi

echo
if [ -n "$hook_rows" ]; then
  echo "HOOKS  (blocking = decision-capable event whose script emits a deny/block; advisory = annotates/logs only)"
  printf '%-14s %-16s %-22s %-11s %s\n' "PLUGIN" "EVENT" "MATCHER" "CLASS" "HOOK"
  printf '%s' "$hook_rows" | while IFS=$'\t' read -r p e m c h; do
    printf '%-14s %-16s %-22s %-11s %s\n' "$p" "$e" "$m" "$c" "$h"
  done
elif [ "$hooks_need_jq" -ne 0 ]; then
  echo "HOOKS: jq not found — hook blocking/advisory classification skipped (install jq to enable)."
else
  echo "HOOKS: none installed."
fi

echo
if [ -n "$skill_rows" ]; then
  echo "SKILLS  (each skill's name and the first sentence of its description)"
  printf '%s' "$skill_rows" | while IFS=$'\t' read -r p n purpose; do
    printf '  %-14s %-26s %s\n' "$p" "$n" "$purpose"
  done
else
  echo "SKILLS: none found in the cache."
fi
exit 0

#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# ship-continue — a Stop hook for /dev-kit:ship. It keeps a ship run from yielding
# mid-flight after a delegated sub-skill (e.g. /security-review) hands back: when ship's
# per-run `state` file holds an explicit active-phase token (`phase-*`), it blocks the stop
# and tells the agent to synthesize and continue. It is INERT and DEFAULT-ALLOW everywhere
# else — no git repo, no state file, a `gate:*`/`done`/blank/typo/stale `state`, an already
# re-invoked stop, a missing jq, or any error all let the stop through. Blocking only on a
# `phase-*` token means it can never trap the session at a human gate (plan sign-off /
# hand-off) and a forgotten or stale token fails safe instead of nagging.
#
# Reads the Claude Code Stop-hook JSON payload on stdin; emits a `{"decision":"block",...}`
# object only when blocking, and nothing (exit 0) when allowing.
set -euo pipefail

# allow() — let the stop proceed: emit nothing, exit success. The safe default.
allow() { exit 0; }

# jq ships with Claude Code, but if it's somehow absent we can't parse the payload or
# encode a reason safely — fail open rather than guess.
command -v jq >/dev/null 2>&1 || allow

# Parse the two fields we need from the Stop payload in one jq pass, reading stdin directly
# (this runs on every Stop event in every repo). A parse failure — malformed or empty
# payload — is treated exactly like a missing jq above: we can't read it, so fail open.
parsed="$(jq -r '[.stop_hook_active // false, .cwd // empty] | @tsv' 2>/dev/null)" || allow
IFS=$'\t' read -r stop_active cwd <<<"$parsed" || true

# If this Stop was already re-triggered by a previous Stop-hook block, let it through to
# rule out any chance of a loop.
[ "$stop_active" = "true" ] && allow

# Resolve the absolute git dir for the hook's working directory. Not a repo → no ship run.
[ -n "$cwd" ] || cwd="$PWD"
gitdir="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
[ -n "$gitdir" ] || allow

state_file="$gitdir/ship/state"
[ -f "$state_file" ] || allow # no active ship run

# The token is the first non-empty line, whitespace-stripped. Block ONLY on an explicit
# active-phase token (`phase-*`); every other value — blank, `done`, any `gate:*`, a stale
# token, or a typo — falls through to allow. Default-allow keeps the hook from ever trapping
# the session at a human gate or nagging on a forgotten/stale `state`.
# This vocabulary (`phase-*` active, `gate:*` parked, `done` done) is the contract documented
# in plugins/dev-kit/skills/ship/SKILL.md (Phase 0); keep the two in sync.
state="$(grep -m1 -v '^[[:space:]]*$' "$state_file" 2>/dev/null | tr -d '[:space:]' || true)"
case "$state" in
phase-*) : ;; # active phase → fall through to block
*) allow ;;
esac

# An active phase is named: block the stop and steer the agent back into the workflow.
reason="A /dev-kit:ship run is mid-flight (state: ${state}). A delegated sub-skill's return is a hand-back, NOT a stopping point — synthesize its output and continue to the next phase. If you are genuinely at a stopping point — plan sign-off, hand-off, or surfacing an unrecoverable blocker to the human — set the run's state to 'gate:plan-signoff' or 'done' (in ${state_file}) and stop again. If no ship run is active, that file is stale — remove it and stop again."

printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | jq -Rs .)"
exit 0

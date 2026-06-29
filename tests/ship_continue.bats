#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for plugins/dev-kit/hooks/ship-continue.sh — the /dev-kit:ship Stop hook. Its one
# job is to block a stop ONLY when ship's per-run `state` file names an active phase, and to
# fail OPEN (allow the stop, empty output, exit 0) on every other path. Each test feeds a
# Stop-hook JSON payload on stdin and asserts allow-vs-block, so the safety contract —
# "never trap the session except on an explicitly-active phase" — is pinned down.
# Run:  bats tests/ship_continue.bats

setup() {
  SANDBOX="$(mktemp -d)"
  HOOK="$BATS_TEST_DIRNAME/../plugins/dev-kit/hooks/ship-continue.sh"
  REPO="$SANDBOX/repo"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
  git init -q "$REPO"
}

teardown() {
  rm -rf "$SANDBOX"
}

# Write a state token into the repo's ship dir.
set_state() {
  mkdir -p "$REPO/.git/ship"
  printf '%s\n' "$1" >"$REPO/.git/ship/state"
}

# Run the hook with a payload for the given cwd (and optional stop_hook_active flag).
run_hook() {
  local cwd="$1" active="${2:-false}"
  run bash "$HOOK" <<<"{\"cwd\":\"$cwd\",\"stop_hook_active\":$active}"
}

@test "allows the stop when cwd is not a git repository" {
  run_hook "$SANDBOX" # SANDBOX itself is not a repo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop when there is no ship state file" {
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop when the state file is empty" {
  set_state ""
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop when state is 'done'" {
  set_state "done"
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop at a human gate (any gate:* token)" {
  set_state "gate:plan-signoff"
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop while parked on an async wait (any waiting:* token)" {
  set_state "waiting:ci"
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks the stop when state names an active phase" {
  set_state "phase-6-review"
  run_hook "$REPO"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # Output must be valid JSON with decision:block and a hand-back reason.
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("hand-back"; "i")'
  echo "$output" | jq -e '.reason | test("phase-6-review")'
}

@test "default-allow: a non-phase token (typo / stale gate) never blocks" {
  # Only `phase-*` blocks; a malformed gate, a bare word, or garbage all fall through to allow.
  for tok in "gate" "plan-signoff" "donezo" "garbage" "Phase-3"; do
    set_state "$tok"
    run_hook "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || {
      echo "expected allow for token '$tok' but got: $output"
      return 1
    }
  done
}

@test "blocks on a valid payload that omits stop_hook_active (defaults to not-active)" {
  set_state "phase-3-implement"
  run bash "$HOOK" <<<"{\"cwd\":\"$REPO\"}"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
}

@test "fails open on a malformed (non-JSON) payload even at an active phase" {
  set_state "phase-3-implement"
  cd "$REPO"
  run bash "$HOOK" <<<"{not valid json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fails open (allows) when jq is unavailable, even at an active phase" {
  set_state "phase-3-implement"
  # Shadow PATH with a dir that has bash/git but no jq.
  local shim="$SANDBOX/bin"
  mkdir -p "$shim"
  for cmd in bash git env head grep tr cat printf; do
    p="$(command -v "$cmd" || true)"
    [ -n "$p" ] && ln -sf "$p" "$shim/$cmd"
  done
  run env PATH="$shim" bash "$HOOK" <<<"{\"cwd\":\"$REPO\",\"stop_hook_active\":false}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows the stop even on an active phase when stop_hook_active is true (loop guard)" {
  set_state "phase-3-implement"
  run_hook "$REPO" true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks from a subdirectory of the repo (git-dir resolves upward)" {
  set_state "phase-4-simplify"
  mkdir -p "$REPO/nested/deep"
  run_hook "$REPO/nested/deep"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
}

@test "per-worktree isolation: blocks inside a linked worktree, main checkout stays independent" {
  # This is the property #25 introduces — state travels with each worktree's own git dir.
  git -C "$REPO" commit -q --allow-empty -m init # worktree add needs a commit
  local wt="$SANDBOX/wt"
  git -C "$REPO" worktree add -q "$wt" -b feature
  # Arm an active phase in the WORKTREE's own git dir (…/.git/worktrees/wt/ship/state).
  local wt_gitdir
  wt_gitdir="$(git -C "$wt" rev-parse --absolute-git-dir)"
  mkdir -p "$wt_gitdir/ship"
  printf 'phase-6-review\n' >"$wt_gitdir/ship/state"
  # Inside the linked worktree → blocks (reads the worktree's own state).
  run_hook "$wt"
  echo "$output" | jq -e '.decision == "block"'
  # The main checkout has no active state of its own → still allows (no cross-worktree bleed).
  run_hook "$REPO"
  [ -z "$output" ]
}

@test "emits nothing and succeeds on an empty stdin payload" {
  # With no payload the hook falls back to $PWD; run from a non-repo dir so it allows.
  cd "$SANDBOX"
  run bash "$HOOK" <<<""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

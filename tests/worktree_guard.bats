#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for the worktree-guard PreToolUse hook: it must block Write/Edit/MultiEdit that
# target the parent checkout when cwd is inside a .claude/worktrees/<name>/ worktree, while
# allowing the worktree's own tree, the worktree's own git dir, non-matching tools, and any
# session that isn't in a worktree. A real linked worktree is built in the sandbox so the
# `.git`-pointer resolution of the worktree's own git dir is exercised for real.

setup() {
  HOOK="$BATS_TEST_DIRNAME/../plugins/worktree-guard/hooks/block-write-outside-worktree.py"
  SANDBOX="$(mktemp -d)"
  REPO="$SANDBOX/repo"
  # Hermetic git identity + config (CI runners have none) so `commit`/`worktree add` work.
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
  git init -q "$REPO"
  git -C "$REPO" commit --allow-empty -qm init
  WT="$REPO/.claude/worktrees/feat+x"
  git -C "$REPO" worktree add -q -b feat-x "$WT" >/dev/null 2>&1
  # The worktree's own git dir, read from its `.git` pointer (don't assume the name).
  GITDIR="$(sed 's/^gitdir: //' "$WT/.git")"
}

teardown() {
  rm -rf "$SANDBOX"
}

# run_hook TOOL CWD FILE_PATH — feed the hook a PreToolUse payload on stdin.
run_hook() {
  run python3 "$HOOK" <<<"{\"tool_name\":\"$1\",\"cwd\":\"$2\",\"tool_input\":{\"file_path\":\"$3\"}}"
}

# A deny is signalled by a JSON object on stdout; an allow emits nothing. The hook always
# exits 0 either way, so assert on output, not status.
assert_deny() {
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
}

assert_allow() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks editing the parent checkout's working tree from inside a worktree" {
  run_hook "Edit" "$WT" "$REPO/install.sh"
  assert_deny
}

@test "allows writing into the worktree's own git dir (e.g. ship run state)" {
  run_hook "Write" "$WT" "$GITDIR/ship/progress.md"
  assert_allow
}

@test "allows writing the worktree's own copy" {
  run_hook "Edit" "$WT" "$WT/install.sh"
  assert_allow
}

@test "ignores non-Write tools (Bash is not matched)" {
  run_hook "Bash" "$WT" "$REPO/install.sh"
  assert_allow
}

@test "blocks a parent-checkout config write too (not just source)" {
  run_hook "Write" "$WT" "$REPO/.claude/settings.json"
  assert_deny
}

@test "is inert when the session is not in a worktree" {
  run_hook "Edit" "$REPO" "$REPO/install.sh"
  assert_allow
}

@test "fails open on a malformed payload" {
  run python3 "$HOOK" <<<"not json"
  assert_allow
}

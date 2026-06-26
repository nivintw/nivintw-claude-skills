#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# Tests for plugins/dev-kit/skills/cleanup-locally/scripts/cleanup-locally.sh — the local
# branch/worktree pruner + default-branch updater. Each test builds a throwaway repo with a
# bare "origin" remote in a sandbox and exercises one safety property: merged things get
# pruned, unmerged/dirty/checked-out things are kept, and the default branch is brought
# forward without ever clobbering local work.
# Run:  bats tests/cleanup_locally.bats

setup() {
  SANDBOX="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../plugins/dev-kit/skills/cleanup-locally/scripts/cleanup-locally.sh"
  REMOTE="$SANDBOX/remote.git"
  REPO="$SANDBOX/repo"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  # Keep the host's git config from leaking in (hooks, signing, default branch name…).
  export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

  git init -q --bare "$REMOTE"
  git -C "$REMOTE" symbolic-ref HEAD refs/heads/main # so clones check out main, not master
  git clone -q "$REMOTE" "$REPO"
  cd "$REPO" || return 1
  echo base >file.txt
  git add file.txt
  git commit -qm "initial"
  git push -q -u origin main
  git remote set-head origin main # so origin/HEAD resolves to main
}

teardown() {
  rm -rf "$SANDBOX"
}

# --- helpers --------------------------------------------------------------------------- #

# A second clone that can push to origin "from elsewhere" (advance/diverge the remote).
other_clone() {
  git clone -q "$REMOTE" "$SANDBOX/other"
  git -C "$SANDBOX/other" config user.name test
  git -C "$SANDBOX/other" config user.email test@example.com
}

# Advance origin/main by one commit, made in a separate clone.
advance_origin() {
  other_clone
  echo ahead >"$SANDBOX/other/ahead.txt"
  git -C "$SANDBOX/other" add ahead.txt
  git -C "$SANDBOX/other" commit -qm "remote advance"
  git -C "$SANDBOX/other" push -q origin main
}

commit_on() { # commit_on <branch-cwd> <file> <content> <msg>
  echo "$3" >"$1/$2"
  git -C "$1" add "$2"
  git -C "$1" commit -qm "$4"
}

# A branch whose commit is in main via a normal --no-ff merge, then its remote is deleted
# (the classic merged-PR state: upstream shows [gone]).
merged_gone_branch() {
  git checkout -q -b "$1" main
  commit_on "$REPO" "$1.txt" "$1" "$1 work"
  git push -q -u origin "$1"
  git checkout -q main
  git merge -q --no-ff "$1"
  git push -q origin main
  git push -q origin --delete "$1"
}

# --- tests ----------------------------------------------------------------------------- #

@test "deletes a merged branch whose upstream is gone" {
  merged_gone_branch feat-merged
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run git rev-parse --verify --quiet refs/heads/feat-merged
  [ "$status" -ne 0 ] # branch is gone
}

@test "deletes a squash-merged branch (diff applied as one commit)" {
  git checkout -q -b feat-squash main
  commit_on "$REPO" squash.txt one "part 1"
  echo two >>"$REPO/squash.txt"
  git add squash.txt
  git commit -qm "part 2"
  git push -q -u origin feat-squash
  git checkout -q main
  git merge -q --squash feat-squash
  git commit -qm "squash feat-squash"
  git push -q origin main
  git push -q origin --delete feat-squash

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run git rev-parse --verify --quiet refs/heads/feat-squash
  [ "$status" -ne 0 ]
}

@test "keeps an unmerged branch even when its upstream is gone" {
  git checkout -q -b feat-orphan main
  commit_on "$REPO" orphan.txt o "orphan work"
  git push -q -u origin feat-orphan
  git push -q origin --delete feat-orphan
  git checkout -q main

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not in main"* ]]
  run git rev-parse --verify --quiet refs/heads/feat-orphan
  [ "$status" -eq 0 ] # still there — its only copy was not destroyed
}

@test "reports and counts a merged local-only branch checked out in a worktree" {
  git checkout -q -b lo-wt main
  commit_on "$REPO" lo.txt lo "lo work"
  git checkout -q main
  git merge -q --no-ff lo-wt
  git push -q origin main # lo-wt never pushed → local-only, no upstream
  git worktree add -q "$SANDBOX/lo-ext" lo-wt

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked out in a worktree"* ]] # reported, not silently skipped
  [[ "$output" == *"kept 1."* ]]                    # and counted in the summary
  run git rev-parse --verify --quiet refs/heads/lo-wt
  [ "$status" -eq 0 ] # kept
}

@test "deletes a merged local-only branch (no upstream)" {
  git checkout -q -b local-merged main
  commit_on "$REPO" l.txt l "local work"
  git checkout -q main
  git merge -q --no-ff local-merged
  git push -q origin main # never pushed local-merged itself

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run git rev-parse --verify --quiet refs/heads/local-merged
  [ "$status" -ne 0 ]
}

@test "deletes a merged local-only branch when run from a non-default branch" {
  git checkout -q -b lo3 main
  commit_on "$REPO" lo3.txt lo3 "lo3 work"
  git checkout -q -b side main # 'side' forks off base, before lo3 merges → does not contain lo3
  git checkout -q main
  git merge -q --no-ff lo3
  git push -q origin main
  git checkout -q side # current HEAD does NOT contain lo3

  run "$SCRIPT"
  [ "$status" -eq 0 ] # with plain -d this would fail (lo3 not merged into 'side')
  run git rev-parse --verify --quiet refs/heads/lo3
  [ "$status" -ne 0 ] # deleted regardless of which branch is checked out
}

@test "keeps a merged branch that still has a live upstream" {
  git checkout -q -b feat-live main
  commit_on "$REPO" live.txt v "live work"
  git push -q -u origin feat-live
  git checkout -q main
  git merge -q --no-ff feat-live
  git push -q origin main # remote branch is NOT deleted — upstream stays live

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run git rev-parse --verify --quiet refs/heads/feat-live
  [ "$status" -eq 0 ] # a live remote means the work isn't done; leave it alone
}

@test "skips a merged branch that is checked out in a worktree" {
  git checkout -q -b wt-branch main
  commit_on "$REPO" w.txt w "w work"
  git push -q -u origin wt-branch
  git checkout -q main
  git merge -q --no-ff wt-branch
  git push -q origin main
  git push -q origin --delete wt-branch # merged + gone: would normally be deleted…
  git worktree add -q "$SANDBOX/external-wt" wt-branch # …but it's checked out here

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked out in a worktree"* ]]
  run git rev-parse --verify --quiet refs/heads/wt-branch
  [ "$status" -eq 0 ] # checked out somewhere → never deleted
}

@test "removes a merged worktree under .claude/worktrees and then its freed branch" {
  git worktree add -q "$REPO/.claude/worktrees/done" -b wt-done main
  commit_on "$REPO/.claude/worktrees/done" d.txt d "done work"
  git merge -q --no-ff wt-done # merge from the primary checkout
  git push -q origin main

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -d "$REPO/.claude/worktrees/done" ] # worktree removed
  run git rev-parse --verify --quiet refs/heads/wt-done
  [ "$status" -ne 0 ] # branch freed by removal, then pruned in the same run
}

@test "keeps an unmerged worktree" {
  git worktree add -q "$REPO/.claude/worktrees/wip" -b wt-wip main
  commit_on "$REPO/.claude/worktrees/wip" wip.txt wip "wip work"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$REPO/.claude/worktrees/wip" ] # not merged → kept
  [[ "$output" == *"not merged"* ]]
}

@test "keeps a merged worktree that has uncommitted changes" {
  git worktree add -q "$REPO/.claude/worktrees/dirty" -b wt-dirty main
  commit_on "$REPO/.claude/worktrees/dirty" c.txt c "c work"
  git merge -q --no-ff wt-dirty
  git push -q origin main
  echo scratch >>"$REPO/.claude/worktrees/dirty/c.txt" # now dirty

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$REPO/.claude/worktrees/dirty" ] # dirty → kept despite being merged
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "dry-run changes nothing" {
  merged_gone_branch feat-dry
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  run git rev-parse --verify --quiet refs/heads/feat-dry
  [ "$status" -eq 0 ] # nothing was actually deleted
}

@test "updates main: stashes a dirty tree, fast-forwards, restores the change" {
  advance_origin
  echo localscratch >scratch.txt # untracked dirty change in main's worktree

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$REPO/ahead.txt" ]   # main advanced to origin
  [ -f "$REPO/scratch.txt" ] # dirty change carried back
  run cat "$REPO/scratch.txt"
  [ "$output" = "localscratch" ]
}

@test "updates main: rebases an unpushed local commit forward onto origin" {
  advance_origin
  commit_on "$REPO" mine.txt mine "my unpushed commit"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$REPO/ahead.txt" ] # origin's commit is now present
  [ -f "$REPO/mine.txt" ]  # and my commit survived, replayed on top
  run git -C "$REPO" log --oneline origin/main..HEAD
  [[ "$output" == *"my unpushed commit"* ]] # exactly the local commit sits ahead of origin
}

@test "updates main: a genuine conflict aborts the rebase and keeps local work intact" {
  other_clone
  echo remote-change >"$SANDBOX/other/file.txt"
  git -C "$SANDBOX/other" add file.txt
  git -C "$SANDBOX/other" commit -qm "remote edits file"
  git -C "$SANDBOX/other" push -q origin main
  echo local-change >"$REPO/file.txt" # conflicting local edit on the same line
  git add file.txt
  git commit -qm "local edits file"

  run "$SCRIPT"
  [ "$status" -ne 0 ]                  # surfaces failure
  [[ "$output" == *"WARNING"* ]]       # warns rather than clobbering
  run cat "$REPO/file.txt"
  [ "$output" = "local-change" ]       # local work untouched
  run git -C "$REPO" status --porcelain
  [ -z "$output" ] # not left mid-rebase
}

@test "errors out when not in a git repository" {
  run "$SCRIPT" --help # help works without a repo
  [ "$status" -eq 0 ]
  cd "$SANDBOX" || return 1
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a git repository"* ]]
}

@test "errors out when the default branch can't be resolved" {
  # Remote HEAD dangles (points at a nonexistent "main") while only "trunk" exists, so even
  # after fetch origin/HEAD stays unset and the origin/main fallback resolves to nothing —
  # the script must bail loudly rather than silently do nothing against a bogus base.
  local r2="$SANDBOX/trunk.git" c2="$SANDBOX/trunkrepo"
  git init -q --bare "$r2"
  git -C "$r2" symbolic-ref HEAD refs/heads/main # dangling: no "main" will ever be pushed
  git clone -q "$r2" "$c2"
  git -C "$c2" config user.name test
  git -C "$c2" config user.email test@example.com
  (cd "$c2" && git checkout -q -b trunk && echo x >f.txt && git add f.txt &&
    git commit -qm init && git push -q -u origin trunk)

  cd "$c2" || return 1
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot resolve the default branch"* ]]
}

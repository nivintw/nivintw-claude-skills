#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# cleanup-locally — prune merged local branches and worktrees, and bring the default
# branch up to date, without ever destroying unmerged work.
#
# Order: fetch → update default branch → prune merged worktrees → prune merged branches.
# (Worktrees first, so a freed branch becomes deletable in the branch pass.)
#
# Safety: a branch/worktree is only removed when its commits are verified present in the
# default branch — via a normal/rebase merge (ancestor) or a squash merge (patch-id /
# `git cherry`). Anything unmerged, dirty, or checked out is kept and reported. Assumes the
# remote is named "origin".

set -uo pipefail

DRY_RUN=0
deleted=0
skipped=0
kept=0
removed_wt=0
had_failure=0

usage() {
  cat <<'EOF'
Usage: cleanup-locally.sh [-n|--dry-run] [-h|--help]

Prune local branches and worktrees that have been merged into the default branch, and
fast-forward / rebase the default branch onto origin. Run from inside a git repository
(assumes the remote is named "origin").

A branch or worktree is removed only when its commits are verified present in the default
branch (normal, rebase, or squash merge). Unmerged, dirty, or currently-checked-out items
are kept and reported, so an accidentally-deleted remote can't cost you your only copy.

The default branch is updated in whichever worktree holds it: a dirty tree is stashed and
restored, and unpushed local commits are rebased forward onto origin. A genuine conflict
(rebase or stash-pop) aborts that step with a warning, leaving your work intact.

Options:
  -n, --dry-run   Show what would happen without changing anything.
  -h, --help      Show this help and exit.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
  shift
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not a git repository." >&2
  exit 1
fi

[ "$DRY_RUN" = 1 ] &&
  echo "(dry run: still fetches to assess state, but deletes no branches/worktrees and leaves the default branch untouched)"

# All branches currently checked out in any worktree — these can't be deleted, and the
# default-branch update must happen in the worktree that holds it.
checked_out_branches() {
  git worktree list --porcelain | sed -n 's#^branch refs/heads/##p'
}

is_checked_out() {
  checked_out_branches | grep -qxF -- "$1"
}

worktree_of_branch() {
  git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree /{wt=substr($0, 10)}
    $0 == "branch " want {print wt; exit}
  '
}

# True if every commit on $1 is already present in $2 (ancestor merge OR squash merge).
is_merged() {
  local branch=$1 base=$2 unmerged mb synth
  unmerged=$(git log --cherry-pick --right-only --oneline "$base...$branch" 2>/dev/null) || return 1
  [ -z "$unmerged" ] && return 0 # normal / rebase merge: nothing left on the branch side
  # Collapse the branch to one synthetic commit of its whole diff vs the merge-base, then
  # ask whether the base already contains that patch (git cherry prints "-" if so).
  mb=$(git merge-base "$base" "$branch" 2>/dev/null) || return 1
  [ -z "$mb" ] && return 1
  synth=$(git commit-tree "$branch^{tree}" -p "$mb" -m squash-check 2>/dev/null) || return 1
  [ -z "$synth" ] && return 1
  git cherry "$base" "$synth" 2>/dev/null | grep -q '^-'
}

echo "Fetching latest changes from origin..."
if ! git fetch --prune origin; then
  echo "Error: git fetch failed; aborting to avoid pruning on stale remote state." >&2
  exit 1
fi

# Resolve the default branch (e.g. origin/main → main).
default_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/||')
[ -z "$default_ref" ] && default_ref="origin/main"
default_local=${default_ref#origin/}

# Bail rather than silently do nothing against a misresolved base: if origin/HEAD is unset
# and the default isn't "main", every merge check below would run against a nonexistent ref.
if ! git rev-parse --verify --quiet "$default_ref" >/dev/null; then
  echo "Error: cannot resolve the default branch '$default_ref'." >&2
  echo "       Point origin/HEAD at it first:  git remote set-head origin --auto" >&2
  exit 1
fi

# ----------------------------- Update the default branch ----------------------------- #
update_default() {
  local wt stashed=0
  wt=$(worktree_of_branch "$default_local")

  if [ -z "$wt" ]; then
    # Not checked out anywhere: fast-forward the ref if it's behind, else leave it.
    if git rev-parse --verify --quiet "$default_local" >/dev/null &&
      git merge-base --is-ancestor "$default_local" "$default_ref"; then
      if [ "$DRY_RUN" = 1 ]; then
        echo "[dry-run] would fast-forward $default_local to $default_ref"
      elif git update-ref "refs/heads/$default_local" "$(git rev-parse "$default_ref")"; then
        echo "Fast-forwarded $default_local to $default_ref."
      else
        echo "WARNING: failed to fast-forward $default_local to $default_ref." >&2
        had_failure=1
      fi
    else
      echo "Note: $default_local not checked out and not fast-forwardable; left as-is."
    fi
    return
  fi

  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would update $default_local in $wt (stash if dirty, rebase onto $default_ref)"
    return
  fi

  if [ -n "$(git -C "$wt" status --porcelain)" ]; then
    if git -C "$wt" stash push --include-untracked -m "cleanup-locally: auto-stash" >/dev/null 2>&1; then
      stashed=1
    else
      # Couldn't safely set the tree aside — don't rebase a dirty tree (it would fail for
      # reasons unrelated to conflicts and misdiagnose). Leave the branch untouched.
      echo "WARNING: $default_local in $wt has changes that couldn't be stashed; left as-is." >&2
      had_failure=1
      return
    fi
  fi

  if git -C "$wt" rebase "$default_ref" >/dev/null 2>&1; then
    echo "Updated $default_local (rebased onto $default_ref) in $wt."
  else
    git -C "$wt" rebase --abort >/dev/null 2>&1
    echo "WARNING: could not rebase $default_local onto $default_ref (left as-is). Re-run to see why:" >&2
    echo "         git -C \"$wt\" rebase $default_ref" >&2
    had_failure=1
  fi

  if [ "$stashed" = 1 ]; then
    if ! git -C "$wt" stash pop >/dev/null 2>&1; then
      # A conflicting pop keeps the stash entry (git does not drop it on conflict), so no
      # work is lost — but the tree in $wt may carry conflict markers. We deliberately do
      # NOT auto-reset it: that could discard restored-then-untracked files. Tell the user
      # exactly where their work is and how to finish.
      echo "WARNING: auto-stashed changes in $wt didn't re-apply cleanly and may have left" >&2
      echo "         conflict markers. Your work is safe in the stash — resolve, then run:" >&2
      echo "         git -C \"$wt\" stash pop   (or: git -C \"$wt\" checkout . && git -C \"$wt\" stash pop)" >&2
      had_failure=1
    fi
  fi
}

update_default

# ------------------------------ Prune merged worktrees ------------------------------- #
current_top=$(git rev-parse --show-toplevel 2>/dev/null || true)

while IFS=$'\t' read -r wt branch; do
  # Only manage worktrees under .claude/worktrees/ — never the primary checkout.
  case "$wt" in
  */.claude/worktrees/*) ;;
  *) continue ;;
  esac
  [ "$wt" = "$current_top" ] && continue

  if [ -z "$branch" ]; then
    echo "Skipping worktree (detached HEAD): $wt"
    kept=$((kept + 1))
    continue
  fi
  # Read status explicitly so a failure (missing/corrupt worktree) can't masquerade as a
  # clean tree via empty output and lead to removal — on any read error, keep it.
  if ! wt_status=$(git -C "$wt" status --porcelain 2>/dev/null); then
    echo "Skipping worktree (couldn't read status): $wt [$branch]"
    kept=$((kept + 1))
    continue
  fi
  if [ -n "$wt_status" ]; then
    echo "Skipping worktree (uncommitted changes): $wt [$branch]"
    kept=$((kept + 1))
    continue
  fi
  if ! is_merged "$branch" "$default_ref"; then
    echo "Skipping worktree (branch not merged): $wt [$branch]"
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would remove merged worktree: $wt [$branch]"
    removed_wt=$((removed_wt + 1))
  elif git worktree remove "$wt"; then
    echo "Removed merged worktree: $wt [$branch]"
    removed_wt=$((removed_wt + 1))
  else
    echo "    WARNING: failed to remove worktree: $wt" >&2
    had_failure=1
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree /{wt=substr($0, 10); br=""}
  /^branch /{br=substr($0, 8); sub(/^refs\/heads\//, "", br)}
  /^$/{if (wt != "") print wt"\t"br; wt=""}
  END{if (wt != "") print wt"\t"br}
')

# ------------------------------- Prune merged branches ------------------------------- #
delete_branch() {
  local branch=$1 reason=$2 flag=$3
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would delete $reason branch: $branch"
    deleted=$((deleted + 1))
  elif git branch "$flag" "$branch" >/dev/null 2>&1; then
    echo "Deleting $reason branch: $branch"
    deleted=$((deleted + 1))
  else
    echo "    WARNING: failed to delete branch: $branch" >&2
    had_failure=1
  fi
}

# Branches already deleted in the gone-upstream pass, one per line (so the local-only pass
# below doesn't reprocess them in --dry-run, where they aren't actually gone yet). A
# newline-delimited set gives exact-match membership via `already_handled`.
handled=""
already_handled() { printf '%s' "$handled" | grep -qxF -- "$1"; }

# Branches whose upstream is gone (PR merged + remote deleted). Tab-delimit the two fields so
# the branch name and the (multi-word) track value split unambiguously.
while IFS=$'\t' read -r branch track; do
  [ "$track" = "[gone]" ] || continue
  if is_checked_out "$branch"; then
    echo "Skipping branch (checked out in a worktree): $branch"
    kept=$((kept + 1))
    continue
  fi
  if is_merged "$branch" "$default_ref"; then
    delete_branch "$branch" "merged" "-D"
    handled="$handled$branch"$'\n'
  else
    echo "Skipping branch (commits not in $default_local): $branch"
    skipped=$((skipped + 1))
  fi
done < <(git for-each-ref --format '%(refname:short)%09%(upstream:track)' refs/heads)

# Local-only branches that are ancestors of the default branch (no live upstream).
while IFS= read -r branch; do
  [ "$branch" = "$default_local" ] && continue
  already_handled "$branch" && continue
  if is_checked_out "$branch"; then
    echo "Skipping branch (checked out in a worktree): $branch"
    kept=$((kept + 1))
    continue
  fi
  if [ -n "$(git config --get "branch.$branch.remote" 2>/dev/null)" ]; then
    continue # has a live upstream — leave it alone
  fi
  # Force-delete (-D), not -d: the `git branch --merged "$default_ref"` filter already proved
  # the branch is in the default branch. `-d` re-checks against the *current* HEAD, so it
  # would wrongly refuse when the script runs from a non-default branch/worktree.
  delete_branch "$branch" "merged local-only" "-D"
done < <(git branch --merged "$default_ref" --format '%(refname:short)')

# ------------------------------------ Summary ---------------------------------------- #
if [ "$deleted" = 0 ] && [ "$removed_wt" = 0 ] && [ "$skipped" = 0 ] && [ "$kept" = 0 ]; then
  echo "Nothing to clean up."
elif [ "$DRY_RUN" = 1 ]; then
  echo "Dry run complete: would delete $deleted branch(es), would remove $removed_wt worktree(s), skipped $skipped (need review), kept $kept."
else
  echo "Cleanup complete: deleted $deleted branch(es), removed $removed_wt worktree(s), skipped $skipped (need review), kept $kept."
fi

[ "$had_failure" = 0 ]

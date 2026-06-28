#!/usr/bin/env python3
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

"""PreToolUse guard: when the session is inside a git worktree (created under
`.../.claude/worktrees/<name>/`), block Write/Edit/MultiEdit whose target resolves
into the *parent* repository but OUTSIDE the active worktree.

This catches the classic worktree footgun: editing the main checkout
(`<repo>/plugins/foo`) by absolute path while you meant the worktree copy
(`<repo>/.claude/worktrees/<name>/plugins/foo`).

Design:
- No-op unless cwd is inside a `.claude/worktrees/<name>/` directory, so it never
  fires when you're legitimately working in a normal checkout.
- Only denies writes that land inside the parent repo but outside the worktree.
  Writes elsewhere (scratchpad, ~/.claude memory, other repos, /tmp) are allowed.
- The worktree's *own* git dir (`<parent>/.git/worktrees/<name>/`) is in-bounds even
  though it sits outside the worktree tree — it's this worktree's private metadata, and
  tools legitimately write there (e.g. /dev-kit:ship keeps its run state under it).
- Fail-open: any error or unexpected shape exits 0 and allows the operation.
"""

import json
import os
import re
import sys


def main() -> None:
    data = json.load(sys.stdin)

    tool = data.get("tool_name", "")
    if tool not in ("Write", "Edit", "MultiEdit"):
        return  # allow

    cwd = data.get("cwd") or ""
    file_path = (data.get("tool_input") or {}).get("file_path") or ""
    if not cwd or not file_path:
        return  # allow

    # Are we inside an EnterWorktree-style worktree? Match the worktree root:
    # everything up to and including `.claude/worktrees/<name>`.
    m = re.match(r"^(?P<wt>.*/\.claude/worktrees/[^/]+)(?:/|$)", cwd)
    if not m:
        return  # not in a worktree -> allow (can't false-positive on main)

    worktree_root = m.group("wt")
    parent_repo_root = worktree_root.split("/.claude/worktrees/", 1)[0]

    # Resolve the target to an absolute, normalized path (relative paths resolve
    # against cwd, matching how the tool would interpret them).
    target = file_path if os.path.isabs(file_path) else os.path.join(cwd, file_path)
    target = os.path.normpath(target)
    wt = os.path.normpath(worktree_root)
    repo = os.path.normpath(parent_repo_root)

    def under(path: str, root: str) -> bool:
        return path == root or path.startswith(root + os.sep)

    # A linked worktree's OWN git dir lives *outside* the worktree tree — at
    # <parent>/.git/worktrees/<name>/ — so it matches "in the parent repo, outside the
    # worktree" below. But that dir is this worktree's private metadata, not the parent
    # checkout's working source the guard exists to protect, and tools legitimately write
    # there (e.g. /dev-kit:ship keeps its progress/state under `$(git rev-parse --git-dir)/
    # ship/`). Resolve it from the worktree's `.git` pointer file and treat it as in-bounds.
    own_gitdir = None
    try:
        with open(os.path.join(wt, ".git")) as fh:
            ptr = re.search(r"^gitdir:\s*(.+)$", fh.read(), re.M)
        if ptr:
            gd = ptr.group(1).strip()
            own_gitdir = os.path.normpath(gd if os.path.isabs(gd) else os.path.join(wt, gd))
    except OSError:
        own_gitdir = None  # fail-open: fall back to the plain parent-vs-worktree check

    # Block only when the write lands in the parent repo's working tree — not in the worktree
    # itself, and not in the worktree's own git dir.
    if under(target, repo) and not under(target, wt) and not (own_gitdir and under(target, own_gitdir)):
        reason = (
            "Blocked: you're in worktree\n"
            f"  {wt}\n"
            "but this write targets the parent checkout outside it:\n"
            f"  {target}\n"
            f"Write to the worktree copy instead (under {wt}/)."
        )
        out = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            },
            "systemMessage": reason,
        }
        print(json.dumps(out))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: never break a write because the guard errored
    sys.exit(0)

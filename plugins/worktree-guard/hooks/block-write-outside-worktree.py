#!/usr/bin/env python3
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

"""PreToolUse guard: when the session is inside a git worktree (created under
`.../.claude/worktrees/<name>/`), block Write/Edit/NotebookEdit whose target resolves
into the *parent* repository but OUTSIDE the active worktree.

This catches the classic worktree footgun: editing the main checkout
(`<repo>/plugins/foo`) — usually via a stray absolute path, but a relative path that
escapes the worktree is caught too — while you meant the worktree copy
(`<repo>/.claude/worktrees/<name>/plugins/foo`).

Tool set: exactly the live file-mutating tools — `Write`, `Edit`, `NotebookEdit`.
`MultiEdit` was removed from Claude Code (Edit absorbed the batch-edit case), so a
reference to it would be dead code. `NotebookEdit` carries its target in `notebook_path`,
not `file_path`, so it's read from there.

Design:
- No-op unless cwd is inside a `.claude/worktrees/<name>/` directory (scope decision,
  option a in #154): that gate is precisely what stops the guard from false-positiving on
  the primary checkout, and dev-kit's EnterWorktree always creates worktrees there. We
  deliberately do NOT try to guard "any linked worktree regardless of layout" — that would
  need a separate no-false-positive "am I in a worktree at all?" detector for a layout the
  workflow never produces.
- Roots are derived via `git rev-parse` (worktree root / parent-repo root / own git dir),
  not by string-parsing cwd or hand-parsing the `.git` pointer — correct on old git, and
  robust to path shapes the string form got wrong.
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
import subprocess
import sys


def _rev_parse(cwd: str) -> tuple[str, str, str] | None:
    """Resolve (worktree_root, parent_repo_root, own_gitdir) via git rev-parse.

    Returns absolute, normalized paths, or None on any failure (fail-open). git may print
    --git-common-dir / --git-dir relative to cwd, so each is resolved against cwd.
    """
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel", "--git-common-dir", "--git-dir"],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    lines = out.stdout.splitlines()
    if len(lines) != 3 or not all(lines):
        return None
    toplevel, common_dir, git_dir = lines

    # realpath (not just normpath): git already returns symlink-canonical paths, so the target
    # must be canonicalized the same way or a symlinked prefix (macOS /tmp → /private/tmp) would
    # cause a false miss. realpath also resolves a git output that's relative to cwd (older git).
    def resolve(p: str) -> str:
        return os.path.realpath(p if os.path.isabs(p) else os.path.join(cwd, p))

    worktree_root = resolve(toplevel)
    # --git-common-dir points at the parent repo's `.git`; its parent is the parent checkout.
    parent_repo_root = os.path.dirname(resolve(common_dir))
    own_gitdir = resolve(git_dir)
    return worktree_root, parent_repo_root, own_gitdir


def main() -> None:
    data = json.load(sys.stdin)

    tool = data.get("tool_name", "")
    if tool not in ("Write", "Edit", "NotebookEdit"):
        return  # allow

    cwd = data.get("cwd") or ""
    tool_input = data.get("tool_input") or {}
    # NotebookEdit's target is `notebook_path`; Write/Edit use `file_path`.
    if tool == "NotebookEdit":
        file_path = tool_input.get("notebook_path") or tool_input.get("file_path") or ""
    else:
        file_path = tool_input.get("file_path") or ""
    if not cwd or not file_path:
        return  # allow

    # Gate: only act when cwd is inside an EnterWorktree-style `.claude/worktrees/<name>/`
    # worktree (scope decision; see module docstring). Never false-positive on the main checkout.
    if not re.match(r"^.*/\.claude/worktrees/[^/]+(?:/|$)", cwd):
        return  # not in such a worktree -> allow

    roots = _rev_parse(cwd)
    if roots is None:
        return  # fail-open: git absent, not a repo, unexpected output, etc.
    worktree_root, parent_repo_root, own_gitdir = roots

    # Resolve the target to an absolute, symlink-canonical path (relative paths resolve
    # against cwd, matching how the tool would interpret them) — same canonicalization as the
    # rev-parse roots, so a symlinked prefix can't cause a false miss.
    target = os.path.realpath(file_path if os.path.isabs(file_path) else os.path.join(cwd, file_path))
    wt = worktree_root
    repo = parent_repo_root

    def under(path: str, root: str) -> bool:
        return path == root or path.startswith(root + os.sep)

    # Block only when the write lands in the parent repo's working tree — not in the worktree
    # itself, and not in the worktree's own git dir (this worktree's private metadata, which
    # tools legitimately write, e.g. /dev-kit:ship's `$(git rev-parse --git-dir)/ship/`).
    if under(target, repo) and not under(target, wt) and not under(target, own_gitdir):
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

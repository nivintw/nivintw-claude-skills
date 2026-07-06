# worktree-guard

<span data-version="worktree-guard"></span> · workflow · hook · git · worktree ·
[source ↗](https://github.com/nivintw/nivintw-claude-skills/tree/main/plugins/worktree-guard)

Git worktrees have a classic footgun: you're working in `.claude/worktrees/feat-x/`, but a
stray path edits the **main checkout's** copy of the file instead of the worktree's — either
a stray **absolute** path, or a **relative** path that happens to escape the worktree. This
plugin is a single **PreToolUse hook** that blocks exactly that, and nothing else.

## What it blocks

When — and only when — your session's working directory is inside a
`.claude/worktrees/<name>/` worktree, the hook denies a `Write`, `Edit`, or `MultiEdit`
whose target resolves **into the parent repository but outside the worktree**. That's the
write you almost never mean: touching `<repo>/plugins/foo` when you meant
`<repo>/.claude/worktrees/<name>/plugins/foo`. The target is resolved against `cwd` before
the check, so this catches both an absolute path *and* a relative one that walks up and out
of the worktree — the denial names both paths so the fix is obvious.

## What it allows

The guard is deliberately narrow — it protects the parent checkout's *working tree*, nothing
more:

- **The worktree's own files** — the whole point; edit freely.
- **The worktree's own git dir** — a linked worktree keeps its metadata at
  `<repo>/.git/worktrees/<name>/`, which sits outside the worktree tree but is still *this*
  worktree's private area. Tools that keep run state there (like
  [`/dev-kit:ship`](dev-kit/ship.md)) write to it freely; the guard resolves it from the
  worktree's `.git` pointer file.
- **Everything else** — scratch dirs, `~/.claude` memory, other repos, `/tmp`. Untouched.

!!! tip "Two safety properties by design"
    It is **inert** unless you're in a worktree (it can never false-positive on a normal
    checkout), and it is **fail-open** — any error or unexpected input lets the write
    through, so the guard can't wedge your session.

## Install

No commands to learn — install it and it just watches.

```text
# add the marketplace, then install the guard
/plugin marketplace add nivintw/nivintw-claude-skills
/plugin install worktree-guard@nivintw-claude-skills
```

The plugin ships one `PreToolUse` hook (matcher `Write|Edit|MultiEdit`, 10-second timeout);
once installed it runs automatically. It pairs naturally with
[`/dev-kit:ship`](dev-kit/ship.md), which does its work inside worktrees.

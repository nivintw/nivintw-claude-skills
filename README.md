<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

# nivintw-claude-skills

Tyler Nivin's [Claude Code](https://claude.com/claude-code) plugin marketplace.

## Plugins

### `castify`

**Scriptable [asciinema](https://asciinema.org/) recordings.** asciinema records
a live session you perform by hand; castify lets you *script* the session —
every keystroke and pause in a file — so a cast is **reproducible** (re-record it
after a UI change), **deterministic** (pacing is in the script, not your typing),
and **automatable**.

The enabling trick is the payoff, too: castify drives the recording through a
**tmux** pane with `tmux send-keys`, writing keystrokes into the session's real
PTY. That's the only way to script **interactive TUIs like `fzf`, `less`, or
`vim`** — they read the controlling TTY, not stdin, so you can't pipe input to
them. Turn the result into clean, embeddable casts. It's the pipeline behind the
"Commands" page of [nivintw/dotfiles](https://github.com/nivintw/dotfiles):
record → verify → embed.

It ships one skill — **record-terminal-casts** — plus a reusable recording
library and an end-to-end web-embedding guide:

| Piece | What it is |
|-------|------------|
| `skills/record-terminal-casts/SKILL.md` | The method and step-by-step process |
| `…/scripts/cast-lib.sh` | tmux-driven recording harness (`start_rec`/`type_in`/`key`/`pause`/`end_rec`) |
| `…/scripts/launch.sh` · `recprompt.fish` | Clean-shell recorder + on-brand prompt |
| `…/scripts/example-fixtures.sh` · `example-record.sh` | A complete, runnable worked example |
| `…/reference/embedding.md` | Vendoring asciinema-player + HTML/CSS/JS + REUSE licensing |

### `dev-kit`

**A Human + AI teaming development workflow.** Take a change from idea to a reviewed
pull request — with the human in control at the ends (plan sign-off, final merge)
and rigorous, token-aware work in the middle. It ships six composable commands;
`/dev-kit:ship` is the orchestrator and calls the others, but each stands alone:

| Command | What it does |
|---------|--------------|
| `/dev-kit:ship` | Idea → review-ready PR: plan in a worktree, implement with tiered subagent delegation, simplify, refresh docs, review, open the PR. Never auto-merges. |
| `/dev-kit:review-pr` | One review entry point — the full battery (code-review, security-review, pr-review-toolkit) plus a context-chosen adversarial pass, synthesized into one report. |
| `/dev-kit:generate-docs` | Reconcile the whole docs set against the whole codebase every run, catching drift and omission, and author a docs site shaped to the repo (file:// and GitHub Pages). |
| `/dev-kit:handle-task-tracking` | A repeatable workflow for tracking work as GitHub issues — the durable ledger `ship` delegates to. |
| `/dev-kit:open-work` | Read the open issues, call out any in-progress work to resume, then return a ranked "pick up next" shortlist with rationale — the select step between tracking and shipping. |
| `/dev-kit:cleanup-locally` | Prune merged branches and worktrees and bring the default branch up to date, without clobbering local work. |

### `worktree-guard`

**A safety net for git-worktree work.** A single `PreToolUse` hook that catches the classic
footgun: when your session is inside a `.claude/worktrees/<name>/` worktree, it blocks a
`Write`/`Edit`/`MultiEdit` that targets the **parent checkout** by absolute path — the main
copy you didn't mean to touch — while leaving the worktree's own files writable. It's inert
unless you're in a worktree, and fail-open on any error, so it can't get in your way
elsewhere. A natural companion to `/dev-kit:ship`, which works inside worktrees (and whose
run state, kept in the worktree's own git dir, the guard knows to allow).

## Install

```text
/plugin marketplace add nivintw/nivintw-claude-skills
/plugin install castify@nivintw-claude-skills
/plugin install dev-kit@nivintw-claude-skills
/plugin install worktree-guard@nivintw-claude-skills
```

Or from a local clone:

```text
/plugin marketplace add ~/workspace/nivintw-claude-skills
```

Then just ask Claude Code to record a terminal cast of a command — the skill
activates on its own.

## Use castify directly (no Claude Code)

The scripts stand alone. Requires `tmux` and `asciinema`.

```bash
cd plugins/castify/skills/record-terminal-casts/scripts
CAST_LAB=/tmp/castlab bash example-fixtures.sh
CAST_OUT=./casts CAST_LAB=/tmp/castlab bash example-record.sh
asciinema convert -f txt ./casts/fco.cast /dev/stdout   # verify
```

See `plugins/castify/skills/record-terminal-casts/reference/embedding.md` to put
the resulting `.cast` files on a web page.

A few hooks shell out to **system tools** prek can't bootstrap — CI installs them for
you, but install them locally too (most are in Homebrew): `hawkeye`, `taplo`.

## License

MIT — see [LICENSE](LICENSE). castify's embedding guide vendors
[asciinema-player](https://github.com/asciinema/asciinema-player), which is
Apache-2.0; the guide covers licensing it correctly in your own repo.

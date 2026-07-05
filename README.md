<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

# nivintw-claude-skills

Tyler Nivin's [Claude Code](https://claude.com/claude-code) plugin marketplace. Full docs:
[nivintw.github.io/nivintw-claude-skills](https://nivintw.github.io/nivintw-claude-skills/).

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
library, a noise-scrubbing script, and reference guides for viewing/exporting and
web-embedding a cast:

| Piece | What it is |
|-------|------------|
| `skills/record-terminal-casts/SKILL.md` | The method and step-by-step process |
| `…/scripts/cast-lib.sh` | tmux-driven recording harness (`start_rec`/`type_in`/`key`/`pause`/`end_rec`) |
| `…/scripts/launch.sh` · `recprompt.fish` | Clean-shell recorder + on-brand prompt |
| `…/scripts/example-fixtures.sh` · `example-record.sh` | A complete, runnable worked example |
| `…/scripts/cast-scrub.py` | Strip noisy output events from a recorded `.cast` without re-recording |
| `…/reference/viewing-casts.md` | Playing/quitting a cast, checking it without watching, exporting to GIF |
| `…/reference/embedding.md` | Vendoring asciinema-player onto a web page (MkDocs or hand-rolled) + REUSE licensing |

### `dev-kit`

**A Human + AI teaming development workflow.** Take a change from idea to a reviewed
pull request — with the human in control at the ends (plan sign-off, final merge)
and rigorous, token-aware work in the middle. `/dev-kit:ship` is the orchestrator
and calls the others, but each stands alone:

| Command | What it does |
|---------|--------------|
| `/dev-kit:ship` | Idea → review-ready PR: plan in a worktree, implement with tiered subagent delegation, simplify, refresh docs, review, open the PR. Never auto-merges — unless asked to `land`. |
| `/dev-kit:review-pr` | One review entry point — the full battery (code-review, security-review, pr-review-toolkit) plus a context-chosen adversarial pass, synthesized into one report. |
| `/dev-kit:generate-docs` | Reconcile the whole docs set against the whole codebase every run, catching drift and omission, and author an MkDocs Material site (Markdown + nav) shaped to the repo. |
| `/dev-kit:handle-task-tracking` | A repeatable workflow for tracking work as GitHub issues — the durable ledger `ship` delegates to. |
| `/dev-kit:open-work` | Read the open issues, call out any in-progress work to resume, then return a ranked "pick up next" shortlist with rationale — the select step between tracking and shipping. |
| `/dev-kit:cleanup-locally` | Prune merged branches and worktrees and bring the default branch up to date, without clobbering local work. |

Five more — `land` (a discoverable entry point to ship's merge verb),
`doctor`, `pre-public-hardening`, `dry-dock-overhaul`, and `template-reconcile` —
are occasional or standalone checks; see the
[full dev-kit docs](https://nivintw.github.io/nivintw-claude-skills/dev-kit/) for
all eleven.

### `worktree-guard`

**A safety net for git-worktree work.** A single `PreToolUse` hook that catches the classic
footgun: when your session is inside a `.claude/worktrees/<name>/` worktree, it blocks a
`Write`/`Edit`/`MultiEdit` whose path resolves into the **parent checkout** outside the
worktree — the main copy you didn't mean to touch, usually a stray absolute path, but a
relative path that walks out of the worktree is caught too — while
leaving the worktree's own files writable. It's inert
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
the resulting `.cast` files on a web page (including this repo's own MkDocs site).

A few hooks shell out to **system tools** prek can't bootstrap — CI installs them for
you, but install them locally too (most are in Homebrew): `hawkeye`, `taplo`.

## License

MIT — see [LICENSE](LICENSE). castify's embedding guide vendors
[asciinema-player](https://github.com/asciinema/asciinema-player), which is
Apache-2.0; the guide covers licensing it correctly in your own repo.

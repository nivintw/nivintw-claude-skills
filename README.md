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

## Install

```text
/plugin marketplace add nivintw/nivintw-claude-skills
/plugin install castify@nivintw-claude-skills
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

## License

MIT — see [LICENSE](LICENSE). castify's embedding guide vendors
[asciinema-player](https://github.com/asciinema/asciinema-player), which is
Apache-2.0; the guide covers licensing it correctly in your own repo.

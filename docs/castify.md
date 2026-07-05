# castify

<span data-version="castify"></span> · documentation · asciinema · tmux · fzf ·
[source ↗](https://github.com/nivintw/nivintw-claude-skills/tree/main/plugins/castify)

asciinema records a session you perform by hand. castify lets you **script** it — every
keystroke and pause in a file — so a cast is **reproducible** (re-record after a UI change),
**deterministic** (pacing lives in the script, not your typing), and **automatable**.

## Why tmux

The enabling trick is the payoff, too: castify drives the recording through a **tmux** pane
with `tmux send-keys`, writing keystrokes into the session's real PTY. That is the only way
to script **interactive TUIs like `fzf`, `less`, or `vim`** — they read the controlling TTY,
not stdin, so you cannot pipe input to them.

## Commands

One skill — it activates when you ask Claude Code to record a cast.

`/castify:record-terminal-casts` — script a terminal session keystroke by keystroke and
render it to a clean, embeddable asciinema cast, including interactive TUIs that can't be
driven by piping stdin. Ships a reusable tmux recording library, a clean-shell recorder, a
runnable worked example, a noise-scrubbing script for post-processing a recorded `.cast`, and
reference guides for both viewing/exporting a cast and embedding it on a web page.

Try: *"record a terminal cast of this command"* · *"demo this CLI as a recording"* · *"record
an fzf session"*.

## Use it without Claude Code

The scripts stand alone. Requires `tmux` and `asciinema`.

```text
# run the worked example, then verify the cast
cd plugins/castify/skills/record-terminal-casts/scripts
CAST_LAB=/tmp/castlab bash example-fixtures.sh
CAST_OUT=./casts CAST_LAB=/tmp/castlab bash example-record.sh
asciinema convert -f txt ./casts/fco.cast /dev/stdout
```

Noisy recording (a shell greeting, a stray notification)? Clean it up without re-recording
with `scripts/cast-scrub.py IN.cast OUT.cast [--pattern REGEX ...]` — it drops matching
output events from the `.cast` file and leaves the original untouched.

> Two reference guides round this out: `skills/record-terminal-casts/reference/viewing-casts.md`
> covers playing/quitting a cast, checking its duration or content without watching, and
> exporting to GIF or other formats; `skills/record-terminal-casts/reference/embedding.md` covers
> vendoring asciinema-player onto a web page (including an MkDocs-specific wiring section —
> `extra_css`/`extra_javascript` instead of per-page tags) and licensing it correctly.

---
name: record-terminal-casts
description: >-
  This skill should be used when the user asks to "record a terminal cast", "make an
  asciinema recording", "demo this CLI/TUI as a terminal recording", "record an
  fzf/less/vim session", or "embed a terminal recording in the docs/README". It makes
  asciinema recordings scriptable — every keystroke and pause lives in a file instead of
  being performed live — so casts are reproducible, deterministic, and re-recordable when
  the CLI changes, and so interactive TUIs like fzf, less, or vim (which can't be driven by
  piping stdin) can be recorded at all. It uses a tmux keystroke harness, then optionally
  embeds the casts on a static web page with a vendored asciinema-player. Reach for it to
  demo command-line tools, shell functions, or a TUI as a scrubbable terminal recording for
  docs, a README, or a docs site, rather than a screenshot or a GIF.
---

# Scriptable terminal casts

`asciinema rec` records a session performed **live, by hand**. This skill makes
that session **scriptable** — every keystroke and pause lives in a file — so a
cast becomes reproducible (re-record it after a UI change), deterministic (pacing
lives in the script, not in live typing), and automatable. The same mechanism is
also the only way to record **interactive** tools (fzf pickers, pagers, editors),
which the naive `asciinema rec -c "mytool"` can't drive.

## The core idea

Keystrokes can't be piped to a TUI: it reads the controlling **TTY**, not stdin.
The harness solves this with **tmux** — it runs the asciinema recording inside a
detached tmux pane and injects keystrokes from outside with `tmux send-keys`,
which writes into the pane's real PTY. asciinema, running inside the pane, records
an authentic session. The `sleep`s between keystrokes become the playback pacing,
because asciinema records wall-clock time. The whole demo lives in a script —
commit it, diff it, re-run it.

```text
tmux pane ── shell ── asciinema rec ── recorded shell ── your CLI/TUI
   ▲ tmux send-keys injects keys here (real PTY)        ▲ records what appears
```

## Prerequisites

`tmux` and `asciinema` (CLI). On macOS: `brew install tmux asciinema`. For web
embedding, also fetch the asciinema-player (see the reference below).

## Bundled scripts

In this skill's `scripts/` directory (read them before adapting):

- **`cast-lib.sh`** — the harness. Source it, then call `start_rec`, the per-character
  typing helpers `run_cmd` (a command) / `type_human` (text into a TUI), `key`, `pause`,
  `end_rec` — with `type_in` reserved for the rare instant-paste case (see the Process
  rules below). Configured by `CAST_OUT`, `CAST_CWD`, `CAST_SHELL`.
- **`launch.sh`** — starts one recording (asciicast **v2**, idle capped) of a
  clean shell. Invoked by the harness inside the pane.
- **`recprompt.fish`** — a clean recording prompt (single `❯`, no greeting/noise)
  sourced into the recorded fish shell *after* normal config, so the user's
  functions/aliases still load but the prompt chrome is tidy. Adapt the idea
  (a minimal `PS1`) for bash/zsh.
- **`example-fixtures.sh`** / **`example-record.sh`** — a complete worked batch:
  builds throwaway fixtures, then records five demos (a fuzzy git checkout, live
  ripgrep search, multi-repo status, cache cleanup, name resolution). Copy this
  shape.
- **`cast-scrub.py`** — post-process a `.cast` to delete output events matching a
  pattern (default: `direnv:` noise). A `.cast` is JSON with absolute timestamps,
  so dropping an event is safe — remaining timing is unchanged. Use it to remove
  shell-startup noise a recording caught without re-recording.

## Process

1. **Decide the demos.** One cast per command. Favor ones that are visual and
   safe; for destructive tools, demo `--dry-run`. Note required terminal size
   (90–96 cols reads well embedded).

2. **Build fixtures** so runs are reproducible and never touch real work — a repo
   with known branches, files with known search hits, a tree of repos, caches to
   clean. See `example-fixtures.sh`. Keep fixture git identity isolated
   (`GIT_CONFIG_GLOBAL=/dev/null`, dummy author).

3. **Write a driver per demo** as a short sequence of `run_cmd` / `type_human` /
   `key` / `pause`.
   Rules that matter:
   - **Type like a human, not a paste.** Use `run_cmd` (types char-by-char, holds
     a beat, presses Enter) for commands, and `type_human` for text typed into a
     TUI (an fzf query, etc.). The instant `type_in` dumps the whole string in one
     event — the viewer never sees it typed, so the command just *appears* and
     runs, which reads as disorienting. This per-character pacing is the single
     biggest quality lever; reserve `type_in` for when instant really is wanted.
   - Use `key` for actual keys (`Enter`, `Tab`, `Escape`, `C-c`); the `-l` typing
     helpers won't misinterpret words like "Enter" as key names.
   - Give each interactive tool time to come up before typing into it
     (`start_rec` already sleeps ~3s for asciinema+shell; add a `pause` after
     launching fzf/less/etc.).
   - For pickers: `type_in` the query, `pause`, then `key … Enter` to select.
     `Tab` marks items in fzf multi-select.
   - Avoid side effects in a cast: e.g. for an "open in $EDITOR" tool, `Escape`
     out instead of launching a GUI editor, and say so in the caption.

4. **Record the batch.** From a working dir where casts should land:

   ```bash
   CAST_LAB=/tmp/castlab bash scripts/example-fixtures.sh
   CAST_OUT=./casts CAST_LAB=/tmp/castlab bash scripts/example-record.sh
   ```

5. **Verify without watching.** The rendered player can't be eyeballed from a
   script, but content and pacing are confirmable from the text render:

   ```bash
   asciinema convert -f txt casts/fco.cast /dev/stdout
   ```

   Check the expected output appears (the branch list, the search hits, the kill
   confirmation) and that the prompt is clean (no greeting, no `direnv:` lines).
   Re-record if a `pause` was too short and a tool hadn't drawn yet.

6. **Embed (optional).** Vendor the player, add the `<figure class="cast">`
   markup, a small init script, and a no-JS fallback — full steps, including
   REUSE licensing for the Apache-2.0 player, in
   [`reference/embedding.md`](reference/embedding.md).

## Gotchas

- **asciicast v2, not v3.** asciinema 3.x records v3 by default; `launch.sh`
  forces `-f asciicast-v2` because released asciinema-player builds play v2
  everywhere. (v3 support varies by player version.)
- **Player is Apache-2.0**, not the repo's license — annotate it when running
  REUSE (see the embedding reference).
- **`.cast` files are JSON-lines** (first line a JSON header object). They can't
  carry a comment header — annotate them in REUSE config rather than stamping.
- **Pacing is wall-clock.** Keep pauses tight (0.6–2.2s). The `-i 2` idle cap
  prevents an accidental long gap from bloating the file.
- **Quote carefully** when nesting `fish -C '…'` inside `asciinema -c "…"` inside
  `tmux send-keys`. The bundled scripts avoid the worst of it by sourcing
  `recprompt.fish` from a file rather than inlining prompt code.

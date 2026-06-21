# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# shellcheck shell=bash
# cast-lib.sh — tmux-driven asciinema cast recording helpers.
#
# Why tmux: interactive TUIs (fzf, less, vim, …) read keys from the controlling
# TTY, not stdin. You can't pipe keystrokes to them. The trick is to run the
# recording inside a detached tmux pane and drive it from outside with
# `tmux send-keys`, which injects keys into the pane's real PTY. asciinema sits
# inside the pane recording everything it sees — so you capture an authentic run
# of the actual tool, paced by your sleeps.
#
# Usage: source this file from a recording script, then for each demo:
#     start_rec <name> <cols> <rows>     # opens pane, starts recording a shell
#     type_in   <name> "some text"       # types literal text (no Enter)
#     key       <name> Enter             # sends a key: Enter / Tab / Escape / C-c …
#     pause     <seconds>                # wall-clock gap → becomes playback pacing
#     end_rec   <name>                   # exits the shell, finalizes the .cast
#
# Config via environment (set before sourcing, or per call):
#     CAST_OUT    output dir for .cast files          (default: ./casts)
#     CAST_CWD    dir the recorded shell starts in     (default: $PWD)
#     CAST_SHELL  shell to record: fish|bash|zsh        (default: fish)
#
# Requires: tmux, asciinema (3.x ok — we force asciicast-v2 for player compat).

CAST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${CAST_OUT:=./casts}"
: "${CAST_CWD:=$PWD}"
export CAST_SHELL="${CAST_SHELL:-fish}"

# Start recording demo <name> in a fresh tmux pane sized <cols>x<rows>.
# The pane size is the terminal size baked into the cast — pick what reads well
# embedded (90–96 cols is a good web default).
start_rec() { # name cols rows
  command -v tmux >/dev/null     || { echo "cast-lib: tmux not found" >&2; return 1; }
  command -v asciinema >/dev/null || { echo "cast-lib: asciinema not found" >&2; return 1; }
  mkdir -p "$CAST_OUT"
  local s="cast_$1"
  tmux kill-session -t "$s" 2>/dev/null
  tmux new-session -d -s "$s" -x "$2" -y "$3" -c "$CAST_CWD"
  # Launch the recorder inside the pane. launch.sh picks a clean prompt.
  tmux send-keys -t "$s" "'$CAST_LIB_DIR/launch.sh' '$CAST_OUT/$1.cast'" Enter
  sleep 3   # let asciinema + the inner shell come up before the first keystroke
}

# Finalize: exit the recorded shell (asciinema writes the file), then kill the pane.
end_rec() { # name
  local s="cast_$1"
  sleep 0.6
  tmux send-keys -t "$s" "exit" Enter
  sleep 1.6
  tmux kill-session -t "$s" 2>/dev/null
  echo "wrote $CAST_OUT/$1.cast"
}

# Type literal text in ONE keystroke event (instant). Rarely what you want for a
# command — it appears all at once and the viewer never sees it typed. Prefer
# type_human for anything the viewer should watch being entered. The -l flag
# stops tmux interpreting words like "Enter" as key names.
type_in() { tmux send-keys -t "cast_$1" -l "$2"; }

# Type text one character at a time, so asciinema records the keystrokes spread
# over time and playback shows a typewriter effect instead of an instant paste.
# This is the single biggest difference between a cast that reads as "someone is
# using this tool" and one that's disorienting. CAST_TYPE_DELAY tunes the speed
# (seconds per char; ~0.045 ≈ a brisk human). Use it for commands AND for queries
# typed into a TUI (fzf filters, etc.).
: "${CAST_TYPE_DELAY:=0.045}"
type_human() { # name text
  local s="cast_$1" text="$2" i
  for (( i=0; i<${#text}; i++ )); do
    tmux send-keys -t "$s" -l "${text:i:1}"
    sleep "$CAST_TYPE_DELAY"
  done
}

# Type a command with type_human, hold a beat so it's readable, then press Enter.
# The pause-before-Enter (default 0.5s) is what lets a viewer actually read the
# command before output scrolls in.
run_cmd() { type_human "$1" "$2"; sleep "${3:-0.5}"; tmux send-keys -t "cast_$1" Enter; }

# Send a named key or chord: Enter, Tab, Escape, BSpace, C-c, C-d, Up, Down …
key() { tmux send-keys -t "cast_$1" "$2"; }

# A deliberate pause. Because asciinema records wall-clock timing, sleeps here
# are exactly the pauses a viewer sees on playback. Keep them tight (0.6–2.2s).
pause() { sleep "$1"; }

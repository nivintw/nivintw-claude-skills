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

# Type literal text into the recorded shell (the -l flag stops tmux interpreting
# words like "Enter" as key names).
type_in() { tmux send-keys -t "cast_$1" -l "$2"; }

# Send a named key or chord: Enter, Tab, Escape, BSpace, C-c, C-d, Up, Down …
key() { tmux send-keys -t "cast_$1" "$2"; }

# A deliberate pause. Because asciinema records wall-clock timing, sleeps here
# are exactly the pauses a viewer sees on playback. Keep them tight (0.6–2.2s).
pause() { sleep "$1"; }

#!/usr/bin/env bash
# launch.sh — start one asciinema recording of a clean shell.
#
# Run inside the tmux pane by cast-lib.sh's start_rec. $1 = output .cast path.
#
#   * asciicast-v2 output: asciinema 3.x defaults to v3; we force v2 because it's
#     what every released asciinema-player build plays without surprises.
#   * -i 2: cap idle time at 2s so accidental long gaps don't bloat the cast.
#   * Clean prompt: for fish we source recprompt.fish (a single ❯, no greeting,
#     no transient-prompt collapsing) so the cast is on-brand, not your full
#     personal prompt. The real functions/aliases still load.
#
# Override the shell with CAST_SHELL=bash|zsh. For bash/zsh, set a tidy PS1 in
# your own rc or extend the case below — the fish prompt override is fish-only.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SHELL_CMD="${CAST_SHELL:-fish}"

case "$SHELL_CMD" in
  fish) CMD="fish -C 'source \"$HERE/recprompt.fish\"'" ;;
  bash) CMD="bash --rcfile '$HERE/recprompt.bash'" ;;   # provide your own if used
  *)    CMD="$SHELL_CMD" ;;
esac

exec asciinema rec -f asciicast-v2 -i 2 --overwrite -c "$CMD" "$1"

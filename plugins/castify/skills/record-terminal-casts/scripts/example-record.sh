#!/usr/bin/env bash
# example-record.sh — record a batch of casts with the tmux harness.
#
# This is the exact shape that produced the dotfiles "Commands" page: one driver
# per demo, each a short script of type_in / key / pause calls. The commands here
# (fco, fif, fkill, gs-all, pyclean, wtfis) are fish functions from that repo —
# swap in your own. Run example-fixtures.sh first.
#
#   CAST_LAB=/tmp/castlab  bash example-fixtures.sh
#   CAST_OUT=./casts CAST_LAB=/tmp/castlab bash example-record.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="${CAST_LAB:-/tmp/castlab}"
export CAST_OUT="${CAST_OUT:-./casts}"
export CAST_CWD="$LAB"
# shellcheck source=cast-lib.sh
source "$HERE/cast-lib.sh"

# ---- wtfis: resolve a name to alias/function/builtin/binary ------------------
start_rec wtfis 92 16
run_cmd wtfis "wtfis ll gco git python" 0.5; pause 1.8
end_rec wtfis

# ---- fco: fuzzy-checkout a branch (interactive fzf) --------------------------
# Note type_human (not type_in) for the live fzf query too, so the filtering
# reads as someone typing, not an instant jump.
start_rec fco 92 22
run_cmd fco "cd demo" 0.3; pause 0.6
run_cmd fco "fco" 0.3;     pause 2.0     # fzf opens with log preview
type_human fco "login";    pause 1.6     # filter to feature/login (animated)
key fco Enter;             pause 1.4     # select → checkout
run_cmd fco "git branch --show-current" 0.4; pause 1.4
end_rec fco

# ---- fif: live ripgrep search (interactive fzf, reloads per keystroke) -------
start_rec fif 92 22
run_cmd fif "cd demo" 0.3; pause 0.6
run_cmd fif "fif" 0.3;     pause 2.0
type_human fif "log";      pause 1.2     # narrow as you type …
type_human fif "in";       pause 1.8     # … now "login"
key fif Escape;            pause 1.0     # dismiss (Enter would open $EDITOR)
end_rec fif

# ---- gs-all: git status across every repo in a tree --------------------------
start_rec gs-all 92 20
run_cmd gs-all "cd multi" 0.3; pause 0.6
run_cmd gs-all "gs-all" 0.4;   pause 2.2
end_rec gs-all

# ---- pyclean --dry-run: preview python cache cleanup -------------------------
start_rec pyclean 92 18
run_cmd pyclean "cd pyproj" 0.3; pause 0.6
run_cmd pyclean "pyclean --dry-run" 0.4; pause 2.2
end_rec pyclean

echo "ALL DONE — verify each with: asciinema convert -f txt $CAST_OUT/<name>.cast /dev/stdout"

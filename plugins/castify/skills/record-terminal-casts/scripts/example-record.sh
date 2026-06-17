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
type_in wtfis "wtfis ll gco git python"; pause 0.9; key wtfis Enter; pause 1.8
end_rec wtfis

# ---- fco: fuzzy-checkout a branch (interactive fzf) --------------------------
start_rec fco 92 22
type_in fco "cd demo"; key fco Enter; pause 0.8
type_in fco "fco";     key fco Enter; pause 2.0    # fzf opens with log preview
type_in fco "login";   pause 1.6                   # filter to feature/login
key fco Enter;         pause 1.4                   # select → checkout
type_in fco "git branch --show-current"; key fco Enter; pause 1.4
end_rec fco

# ---- fif: live ripgrep search (interactive fzf, reloads per keystroke) -------
start_rec fif 92 22
type_in fif "cd demo"; key fif Enter; pause 0.8
type_in fif "fif";     key fif Enter; pause 2.0
type_in fif "log";     pause 1.4                   # narrow as you type …
type_in fif "in";      pause 1.8                   # … now "login"
key fif Escape;        pause 1.0                   # dismiss (Enter would open $EDITOR)
end_rec fif

# ---- fkill: multi-select process killer (safe: only our own sleeps) ----------
/bin/sleep 31415 & P1=$!
/bin/sleep 31416 & P2=$!
start_rec fkill 92 22
type_in fkill "fkill"; key fkill Enter; pause 2.0
type_in fkill "sleep 3141"; pause 1.4              # filter to the two sleeps
key fkill Tab; pause 0.7                            # mark first
key fkill Tab; pause 0.9                            # mark second
key fkill Enter; pause 1.6                          # kill both
end_rec fkill
kill "$P1" "$P2" 2>/dev/null

# ---- gs-all: git status across every repo in a tree --------------------------
start_rec gs-all 92 20
type_in gs-all "cd multi"; key gs-all Enter; pause 0.8
type_in gs-all "gs-all";   key gs-all Enter; pause 2.2
end_rec gs-all

# ---- pyclean --dry-run: preview python cache cleanup -------------------------
start_rec pyclean 92 18
type_in pyclean "cd pyproj"; key pyclean Enter; pause 0.8
type_in pyclean "pyclean --dry-run"; key pyclean Enter; pause 2.2
end_rec pyclean

echo "ALL DONE — verify each with: asciinema convert -f txt $CAST_OUT/<name>.cast /dev/stdout"

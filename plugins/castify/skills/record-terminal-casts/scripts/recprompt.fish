# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# recprompt.fish — clean, on-brand prompt for cast recordings.
#
# Sourced into the recorded fish shell by launch.sh (via `fish -C`). It runs
# AFTER your normal config, so your functions, aliases, and abbreviations are
# all loaded — this only overrides the prompt *chrome* and silences shell noise
# that would clutter a demo:
#   * a single cyan ❯, no right prompt
#   * no fish greeting
#   * no tide transient-prompt collapsing (harmless if you don't use tide)
#   * direnv logging muted (harmless if you don't use direnv)

set -g fish_greeting ''
set -gx DIRENV_LOG_FORMAT ''

function fish_prompt
    set_color cyan
    printf '❯ '
    set_color normal
end

function fish_right_prompt
end

set -g tide_prompt_transient_enabled false

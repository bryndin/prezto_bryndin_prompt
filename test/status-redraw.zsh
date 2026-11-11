#!/usr/bin/env zsh
#
# The stale exit-status hook must clear the status and force a repaint when
# editing starts, must not loop, and must always return success so it cannot
# abort the rest of the line-pre-redraw chain.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

source "$theme"

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

# Record what the hook asks ZLE to do.  Stub reflow so this test only covers
# the status/repaint logic.
local -a zle_calls
function zle { zle_calls+=("$*") }
function prompt_bryndin_reflow { : }

_prompt_bryndin_header='header'
_prompt_bryndin_status_text='✘'

# No buffer: leave the status alone, do not reset, and return success.
BUFFER=''
prompt_bryndin_line_pre_redraw || fail "hook failed with an empty buffer"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared with an empty buffer"
(( $#zle_calls == 0 )) || fail "reset-prompt called with an empty buffer"

# First keystroke: clear the status and force a repaint.
BUFFER='l'
prompt_bryndin_line_pre_redraw || fail "hook failed on the first keystroke"
[[ -z $_prompt_bryndin_status_text ]] || fail "status not cleared"
(( $#zle_calls == 1 )) || fail "expected one reset-prompt, got $#zle_calls"
[[ $zle_calls[1] == 'reset-prompt' ]] || fail "wrong zle call: $zle_calls[1]"

# The redraw caused by reset-prompt must be a no-op, not a loop.
BUFFER='ls'
prompt_bryndin_line_pre_redraw || fail "hook failed on the reset redraw"
(( $#zle_calls == 1 )) || fail "reset-prompt looped"

# A later keystroke still returns success even with no status to clear.
BUFFER='lss'
prompt_bryndin_line_pre_redraw || fail "hook returned failure with no status"
(( $#zle_calls == 1 )) || fail "unexpected reset-prompt"

print "PASS: stale exit status hook clears once and returns success"

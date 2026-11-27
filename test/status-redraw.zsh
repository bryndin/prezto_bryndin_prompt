#!/usr/bin/env zsh
#
# The stale exit-status hook must clear the status and force a repaint when
# editing starts, must not loop, must leave the prompt alone during menu
# completion, and must always return success so it cannot abort the rest of the
# line-pre-redraw chain.  Reflow belongs to the SIGWINCH trap, not this hook.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv and colour overrides out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV NO_COLOR

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
local reflow_calls=0
function zle { zle_calls+=("$*") }
function prompt_bryndin_reflow { (( reflow_calls++ )) }

_prompt_bryndin_header='header'
_prompt_bryndin_status_text='✘'
KEYMAP=''

# No buffer: leave the status alone, do not reset, and return success.
BUFFER=''
prompt_bryndin_line_pre_redraw || fail "hook failed with an empty buffer"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared with an empty buffer"
(( $#zle_calls == 0 )) || fail "reset-prompt called with an empty buffer"

# Menu completion: leave the status alone; resetting here disturbs the menu.
KEYMAP='menuselect'
BUFFER='l'
prompt_bryndin_line_pre_redraw || fail "hook failed in menuselect"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared in menuselect"
(( $#zle_calls == 0 )) || fail "reset-prompt called in menuselect"

# Non-primary ZLE contexts (vared/cont) and isearch must also no-op.
KEYMAP=''
BUFFER='l'
CONTEXT='vared'
prompt_bryndin_line_pre_redraw || fail "hook failed in vared"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared in CONTEXT=vared"
CONTEXT='cont'
prompt_bryndin_line_pre_redraw || fail "hook failed in cont"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared in CONTEXT=cont"
CONTEXT='start'
ZLE_STATE='insert isearch'
prompt_bryndin_line_pre_redraw || fail "hook failed in isearch"
[[ $_prompt_bryndin_status_text == '✘' ]] || fail "status cleared in ZLE_STATE=isearch"
(( $#zle_calls == 0 )) || fail "reset-prompt called in non-start/isearch context"
ZLE_STATE='insert'

# First keystroke: clear the status and force a repaint.
KEYMAP=''
BUFFER='l'
prompt_bryndin_line_pre_redraw || fail "hook failed on the first keystroke"
[[ -z $_prompt_bryndin_status_text ]] || fail "status not cleared"
(( _prompt_bryndin_status_dismissed == 1 )) || fail "dismissed flag not set"
(( $#zle_calls == 1 )) || fail "expected one reset-prompt, got $#zle_calls"
[[ $zle_calls[1] == 'reset-prompt' ]] || fail "wrong zle call: $zle_calls[1]"

# Empty-line precmd calls after dismissal must NOT resurrect ✘ until preexec runs.
(( reflow_calls == 0 )) || fail "line-pre-redraw reflowed $reflow_calls times"
_prompt_bryndin_last_status=1
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_status_text ]] || fail "empty-line precmd resurrected dismissed status"
prompt_bryndin_preexec
(( _prompt_bryndin_status_dismissed == 0 )) || fail "preexec did not reset dismissed flag"
_prompt_bryndin_last_status=1
prompt_bryndin_precmd
[[ $_prompt_bryndin_status_text == *'✘'* ]] || fail "status did not appear after preexec + failed command"
reflow_calls=0

# Restore clean state for loop checks below.
_prompt_bryndin_status_text=''
zle_calls=(reset-prompt)

# The redraw caused by reset-prompt must be a no-op, not a loop.
BUFFER='ls'
prompt_bryndin_line_pre_redraw || fail "hook failed on the reset redraw"
(( $#zle_calls == 1 )) || fail "reset-prompt looped"

# A later keystroke still returns success even with no status to clear.
BUFFER='lss'
prompt_bryndin_line_pre_redraw || fail "hook returned failure with no status"
(( $#zle_calls == 1 )) || fail "unexpected reset-prompt"

(( reflow_calls == 0 )) || fail "line-pre-redraw reflowed $reflow_calls times"

print "PASS: stale exit status hook clears once and returns success"

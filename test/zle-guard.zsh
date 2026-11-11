#!/usr/bin/env zsh
#
# The resize handler must only call zle reset-prompt while ZLE is active.  The
# `zle` shell option is true for the whole interactive session, so it cannot be
# used as the active test.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'
source "$theme"

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

# Keep the test focused on the ZLE guard.
function prompt_bryndin_prepare_pwd { : }
function prompt_bryndin_reflow { : }

local zle_active=0
local -a zle_calls
function zle {
  if (( $# == 0 )); then
    return $(( ! zle_active ))
  fi
  zle_calls+=("$*")
  return 0
}

_prompt_bryndin_header='header'

prompt_bryndin_resize || fail "resize failed while ZLE was inactive"
(( $#zle_calls == 0 )) || fail "reset-prompt called while ZLE was inactive"

zle_active=1
prompt_bryndin_resize || fail "resize failed while ZLE was active"
(( $#zle_calls == 1 )) || fail "reset-prompt not called while ZLE was active"
[[ $zle_calls[1] == 'reset-prompt' ]] || fail "wrong zle call: $zle_calls[1]"

print "PASS: resize only resets the prompt while ZLE is active"

#!/usr/bin/env zsh
#
# The separator must be part of PROMPT rather than printed by precmd, so that
# zle redraws (clear-screen, reset-prompt, vi keymap switches) reproduce it.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT PROMPT_CR MULTIBYTE

# Keep the caller's virtualenv out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function coalesce {
  local a
  for a in "$@"; do [[ -n $a ]] && { print -rn -- "$a"; return 0 }; done
  return 1
}
function python-info { python_info=(virtualenv '') }

typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

source "$theme"

[[ $PROMPT == *'${_prompt_bryndin_header}'* ]] || {
  print -u2 "FAIL: header is not part of PROMPT"; exit 1
}

COLUMNS=80
local log=$(mktemp /tmp/opencode/bryndin-header.XXXXXX)
prompt_bryndin_precmd > "$log"
local emitted=$(<"$log")
[[ -z $emitted ]] || {
  print -u2 "FAIL: precmd still prints the header: $emitted"; exit 1
}
[[ -n $_prompt_bryndin_header ]] || {
  print -u2 "FAIL: header was not built"; exit 1
}

local rendered=$(print -P -- "$PROMPT")
[[ $rendered == *─* ]] || {
  print -u2 "FAIL: separator missing when PROMPT is rendered"; exit 1
}

print "PASS: header lives in PROMPT and survives redraws"

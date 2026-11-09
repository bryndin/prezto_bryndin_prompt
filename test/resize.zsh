#!/usr/bin/env zsh
#
# The header must be re-flowed when the terminal width changes, without having
# to run a command (precmd is not re-run on a redraw).
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

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

local width_of() {
  local s=$1
  local zero='%([BSUbfksu]|([FBK]|){*})'
  print -r -- ${#${(S%%)s//$~zero/}}
}

COLUMNS=80
prompt_bryndin_precmd
local before=$(width_of "$_prompt_bryndin_header")

COLUMNS=120
prompt_bryndin_line_pre_redraw
local after=$(width_of "$_prompt_bryndin_header")

(( after > before )) || {
  print -u2 "FAIL: header did not grow after resize ($before -> $after)"; exit 1
}
(( after <= 122 )) || {
  print -u2 "FAIL: header overflows after resize ($after > 122)"; exit 1
}

print "PASS: header re-flows on redraw after a terminal resize"

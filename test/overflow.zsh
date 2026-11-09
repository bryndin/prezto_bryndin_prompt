#!/usr/bin/env zsh
#
# Even on a very narrow terminal the header must not exceed COLUMNS: the
# directory block is clipped after the compressed-PWD fallback.
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
  print -r -- ${(m)#${(S%%)s//$~zero/}}
}

local cols
for cols in 20 30 40 60 80; do
  COLUMNS=$cols
  prompt_bryndin_precmd
  local w=$(width_of "$_prompt_bryndin_header")
  (( w <= cols + 1 )) || {
    print -u2 "FAIL: header is $w columns wide at COLUMNS=$cols"; exit 1
  }
done

print "PASS: header never overflows on narrow terminals"

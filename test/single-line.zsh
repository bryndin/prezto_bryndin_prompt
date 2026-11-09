#!/usr/bin/env zsh
#
# single-line mode drops the separator header entirely.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' single-line 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

[[ $PROMPT != *'_prompt_bryndin_header'* ]] || {
  print -u2 "FAIL: header still referenced by PROMPT: $PROMPT"; exit 1
}
local rendered=$(print -P -- "$PROMPT")
[[ $rendered != *─* ]] || {
  print -u2 "FAIL: separator rendered in single-line mode: $rendered"; exit 1
}

print "PASS: single-line mode hides the header"

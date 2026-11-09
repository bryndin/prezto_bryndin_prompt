#!/usr/bin/env zsh
#
# Dynamic text (virtualenv names) must be escaped before it reaches a prompt
# string, otherwise a '%' in the name is interpreted as a prompt escape.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function python-info { python_info=(virtualenv '') }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'
source "$theme"

VIRTUAL_ENV='/tmp/100%done'
local block=$(prompt_bryndin_prepare_virtualenv)
[[ $block == *'100%%done'* ]] || {
  print -u2 "FAIL: venv name not escaped: $block"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd
local rendered=$(print -P -- "$_prompt_bryndin_header")
[[ $rendered == *'100%done'* ]] || {
  print -u2 "FAIL: '%' in venv name was expanded: $rendered"; exit 1
}
[[ $rendered != *'100/'* ]] || {
  print -u2 "FAIL: '%d' expanded to the working directory"; exit 1
}

# $ and backticks must not survive as active substitutions.
local tricky='$(echo PWNED)'
local escaped=$(prompt_bryndin_escape "$tricky")
[[ $escaped == '\$(echo PWNED)' ]] || {
  print -u2 "FAIL: command substitution not escaped: $escaped"; exit 1
}

print "PASS: dynamic text is escaped for prompt expansion"

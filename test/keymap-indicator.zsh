#!/usr/bin/env zsh
#
# The ZLE keymap indicator (❯❯❯) is opt-in and off by default.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯❯❯' overwrite '')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' overwrite 'no'
prompt_newline=$'\n%{\r%}'
source "$theme"

[[ $PROMPT != *'editor_info[keymap]'* ]] || {
  print -u2 "FAIL: keymap indicator is on by default: $PROMPT"; exit 1
}
[[ $PROMPT == *'❯'* ]] || {
  print -u2 "FAIL: default non-root prompt has no prompt character: $PROMPT"; exit 1
}

zstyle ':prezto:module:prompt:bryndin' keymap-indicator 'yes'
prompt_bryndin_setup
[[ $PROMPT == *'${editor_info[keymap]}'* ]] || {
  print -u2 "FAIL: keymap-indicator=yes ignored: $PROMPT"; exit 1
}

print "PASS: keymap indicator is opt-in and a prompt character remains"

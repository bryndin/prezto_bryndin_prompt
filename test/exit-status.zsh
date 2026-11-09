#!/usr/bin/env zsh
#
# Exit status indicator and the framework-wide show-return-val style.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

source "$theme"

[[ $RPROMPT == *'%(?..'* ]] || {
  print -u2 "FAIL: no exit-status indicator: $RPROMPT"; exit 1
}
[[ $RPROMPT != *'%?'* ]] || {
  print -u2 "FAIL: numeric code shown by default"; exit 1
}

zstyle ':prezto:module:prompt' show-return-val 'yes'
prompt_bryndin_setup
[[ $RPROMPT == *'%?'* ]] || {
  print -u2 "FAIL: show-return-val ignored: $RPROMPT"; exit 1
}

zstyle ':prezto:module:prompt:bryndin' exit-status 'no'
prompt_bryndin_setup
[[ -z $RPROMPT ]] || {
  print -u2 "FAIL: exit-status=no ignored: $RPROMPT"; exit 1
}

print "PASS: exit status indicator works"

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

[[ $RPROMPT == *'_prompt_bryndin_status_text'* ]] || {
  print -u2 "FAIL: no exit-status indicator: $RPROMPT"; exit 1
}
[[ $RPROMPT != *'%?'* ]] || {
  print -u2 "FAIL: numeric code shown by default"; exit 1
}

# A failed command should produce the status indicator.
_prompt_bryndin_last_status=2
prompt_bryndin_precmd
[[ $_prompt_bryndin_status_text == *'✘'* ]] || {
  print -u2 "FAIL: failed status not rendered"; exit 1
}
[[ $_prompt_bryndin_status_text != *'2 '* ]] || {
  print -u2 "FAIL: numeric code shown by default"; exit 1
}

zstyle ':prezto:module:prompt' show-return-val 'yes'
prompt_bryndin_setup
_prompt_bryndin_last_status=2
prompt_bryndin_precmd
[[ $_prompt_bryndin_status_text == *'2 '* ]] || {
  print -u2 "FAIL: show-return-val ignored: $_prompt_bryndin_status_text"; exit 1
}

zstyle ':prezto:module:prompt:bryndin' exit-status 'no'
zstyle ':prezto:module:prompt:bryndin' jobs 'no'
zstyle ':prezto:module:prompt:bryndin' history 'no'
zstyle ':prezto:module:prompt:bryndin' duration 'no'
zstyle ':prezto:module:prompt:bryndin' vim 'no'
prompt_bryndin_setup
[[ $RPROMPT != *'✘'* ]] || {
  print -u2 "FAIL: exit-status=no ignored: $RPROMPT"; exit 1
}

print "PASS: exit status indicator works"

#!/usr/bin/env zsh
#
# Optional second-line indicators must be toggleable through zstyle.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

zstyle ':prezto:module:prompt:bryndin' jobs 'yes'
zstyle ':prezto:module:prompt:bryndin' history 'yes'
zstyle ':prezto:module:prompt:bryndin' duration 'yes'
zstyle ':prezto:module:prompt:bryndin' vim 'yes'
zstyle ':prezto:module:prompt:bryndin' overwrite 'yes'
source "$theme"

[[ $RPROMPT == *'%(1j.'* ]] || { print -u2 "FAIL: jobs indicator missing"; exit 1 }
[[ $RPROMPT == *'%!'* ]] || { print -u2 "FAIL: history indicator missing"; exit 1 }
[[ $RPROMPT == *'_prompt_bryndin_duration_text'* ]] || { print -u2 "FAIL: duration missing"; exit 1 }
[[ $RPROMPT == *'${VIM:'* ]] || { print -u2 "FAIL: VIM indicator missing"; exit 1 }
[[ $PROMPT == *'${editor_info[overwrite]}'* ]] || { print -u2 "FAIL: overwrite indicator missing"; exit 1 }

# preexec/precmd must produce a duration string.
SECONDS=100
prompt_bryndin_preexec
SECONDS=103
prompt_bryndin_precmd
[[ $_prompt_bryndin_duration_text == '3s ' ]] || {
  print -u2 "FAIL: duration text: '$_prompt_bryndin_duration_text'"; exit 1
}
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_duration_text ]] || {
  print -u2 "FAIL: duration was not cleared"; exit 1
}

# All off.
zstyle ':prezto:module:prompt:bryndin' jobs 'no'
zstyle ':prezto:module:prompt:bryndin' history 'no'
zstyle ':prezto:module:prompt:bryndin' duration 'no'
zstyle ':prezto:module:prompt:bryndin' vim 'no'
zstyle ':prezto:module:prompt:bryndin' overwrite 'no'
zstyle ':prezto:module:prompt:bryndin' exit-status 'no'
prompt_bryndin_setup
[[ -z $RPROMPT ]] || { print -u2 "FAIL: RPROMPT not empty with all off: $RPROMPT"; exit 1 }
[[ $PROMPT != *'editor_info[overwrite]'* ]] || { print -u2 "FAIL: overwrite not removed"; exit 1 }

print "PASS: optional indicators work"

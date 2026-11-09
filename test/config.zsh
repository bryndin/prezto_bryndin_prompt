#!/usr/bin/env zsh
#
# Verify that zstyle overrides reach the theme and that the `blocks` style
# really controls which header blocks are assembled.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

zstyle ':prezto:module:prompt:bryndin' color 'magenta'
zstyle ':prezto:module:prompt:bryndin' time-format '%D{%H:%M}'
zstyle ':prezto:module:prompt:bryndin' separator '='
zstyle ':prezto:module:prompt:bryndin' blocks 'time' 'git'

function pmodload { : }
function add-zsh-hook { : }

source "$theme"

[[ $_prompt_bryndin_color == magenta ]] || {
  print -u2 "FAIL: color override ignored ($_prompt_bryndin_color)"; exit 1
}
[[ $_prompt_bryndin_conf[time-format] == '%D{%H:%M}' ]] || {
  print -u2 "FAIL: time-format override ignored"; exit 1
}
[[ $_prompt_bryndin_conf[separator] == '=' ]] || {
  print -u2 "FAIL: separator override ignored"; exit 1
}
(( $#_prompt_bryndin_blocks == 2 )) || {
  print -u2 "FAIL: blocks override ignored ($_prompt_bryndin_blocks)"; exit 1
}
[[ $_prompt_bryndin_left != *'%n'* ]] || {
  print -u2 "FAIL: host block is still present"; exit 1
}

print "PASS: zstyle configuration is honoured"

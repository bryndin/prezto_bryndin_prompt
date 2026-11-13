#!/usr/bin/env zsh
#
# Verify that zstyle overrides reach the theme and that the `blocks` style
# really controls which header blocks are assembled.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

zstyle ':prezto:module:prompt:bryndin' main-color 'magenta'
zstyle ':prezto:module:prompt:bryndin' time-format '%D{%H:%M}'
zstyle ':prezto:module:prompt:bryndin' separator '='
zstyle ':prezto:module:prompt:bryndin' blocks 'time' 'git'

function pmodload { : }
function add-zsh-hook { : }

source "$theme"

[[ $_prompt_bryndin_fg[main-color] == '%F{magenta}' ]] || {
  print -u2 "FAIL: main-color override ignored ($_prompt_bryndin_fg[main-color])"; exit 1
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

# Theme-specific boolean spellings are normalised, and an explicit theme
# show-return-code wins over the framework-wide show-return-val.
zstyle ':prezto:module:prompt' show-return-val 'yes'
zstyle ':prezto:module:prompt:bryndin' show-return-code 'no'
zstyle ':prezto:module:prompt:bryndin' jobs 'true'
zstyle ':prezto:module:prompt:bryndin' history 'on'
zstyle ':prezto:module:prompt:bryndin' duration '1'
zstyle ':prezto:module:prompt:bryndin' exit-status 'off'
prompt_bryndin_load_config
[[ $_prompt_bryndin_conf[show-return-code] == no ]] || {
  print -u2 "FAIL: theme show-return-code=no lost to global show-return-val"; exit 1
}
[[ $_prompt_bryndin_conf[jobs] == yes ]] || {
  print -u2 "FAIL: jobs=true was not normalised: $_prompt_bryndin_conf[jobs]"; exit 1
}
[[ $_prompt_bryndin_conf[history] == yes ]] || {
  print -u2 "FAIL: history=on was not normalised: $_prompt_bryndin_conf[history]"; exit 1
}
[[ $_prompt_bryndin_conf[duration] == yes ]] || {
  print -u2 "FAIL: duration=1 was not normalised: $_prompt_bryndin_conf[duration]"; exit 1
}
[[ $_prompt_bryndin_conf[exit-status] == no ]] || {
  print -u2 "FAIL: exit-status=off was not normalised: $_prompt_bryndin_conf[exit-status]"; exit 1
}

# With no theme-specific value, the framework-wide style still applies.
zstyle -d ':prezto:module:prompt:bryndin' show-return-code
prompt_bryndin_load_config
[[ $_prompt_bryndin_conf[show-return-code] == yes ]] || {
  print -u2 "FAIL: global show-return-val was not used as a fallback"; exit 1
}

print "PASS: zstyle configuration is honoured"

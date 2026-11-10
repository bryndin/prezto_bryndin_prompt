#!/usr/bin/env zsh
#
# Regression: zstyle patterns match across colons, so a stock Prezto config's
# `zstyle ':prezto:*:*' color 'yes'` leaks into ':prezto:module:prompt:bryndin'.
# Theme options must not use reserved framework style names such as `color'.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

# Exactly what a stock .zpreztorc sets.
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:*:*' case-sensitive 'yes'
unset NO_COLOR
zstyle ':prezto:module:prompt:bryndin' colors '256'

source "$theme"

[[ $_prompt_bryndin_conf[main-color] == cyan ]] || {
  print -u2 "FAIL: main-color leaked from global style: $_prompt_bryndin_conf[main-color]"; exit 1
}
[[ $_prompt_bryndin_fg[main-color] == '%F{cyan}' ]] || {
  print -u2 "FAIL: main colour is not cyan: $_prompt_bryndin_fg[main-color]"; exit 1
}
[[ $_prompt_bryndin_fg[separator-color] == '%F{cyan}' ]] || {
  print -u2 "FAIL: separator colour is not cyan: $_prompt_bryndin_fg[separator-color]"; exit 1
}
[[ $_prompt_bryndin_fg[time-color] == '%F{27}' ]] || {
  print -u2 "FAIL: time colour changed: $_prompt_bryndin_fg[time-color]"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd
local rendered=$(print -P -- "$PROMPT")
[[ $rendered == *$'\e[36m'* ]] || {
  print -u2 "FAIL: header has no cyan SGR sequence"; exit 1
}

print "PASS: global :prezto:*:* styles do not leak into theme options"

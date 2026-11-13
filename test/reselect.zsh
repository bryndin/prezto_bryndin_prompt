#!/usr/bin/env zsh
#
# Regression test: promptinit calls prompt_<theme>_setup directly when the
# user switches away from and back to a theme.  It does not re-source the
# theme file, so every associative array (and other state) that teardown
# unsets must be re-declared by the setup path.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset VIRTUAL_ENV CONDA_DEFAULT_ENV
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

source "$theme"
prompt_bryndin_teardown

# Reselect the theme, as `prompt bryndin' does after another theme was active.
NO_COLOR=1
prompt_bryndin_setup

[[ ${(t)_prompt_bryndin_conf} == association ]] || {
  print -u2 "FAIL: config is ${(t)_prompt_bryndin_conf}, not an associative array"; exit 1
}
[[ ${(t)_prompt_bryndin_block_text} == association ]] || {
  print -u2 "FAIL: block text is ${(t)_prompt_bryndin_block_text}, not an associative array"; exit 1
}
[[ $_prompt_bryndin_conf[time-format] == '%T' ]] || {
  print -u2 "FAIL: config values were lost: $_prompt_bryndin_conf[time-format]"; exit 1
}
[[ -n $_prompt_bryndin_block_text[time] ]] || {
  print -u2 "FAIL: time block template was not rebuilt"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd

[[ ${(t)_prompt_bryndin_block_expanded} == association ]] || {
  print -u2 "FAIL: expanded blocks are ${(t)_prompt_bryndin_block_expanded}"; exit 1
}
[[ -n $_prompt_bryndin_block_expanded[time] ]] || {
  print -u2 "FAIL: time block was not expanded"; exit 1
}
(( _prompt_bryndin_monochrome == 1 )) || {
  print -u2 "FAIL: reselect ignored NO_COLOR"; exit 1
}
[[ -n $_prompt_bryndin_header ]] || {
  print -u2 "FAIL: header was not rebuilt after reselect"; exit 1
}
[[ $_prompt_bryndin_header != *'%F{'* ]] || {
  print -u2 "FAIL: monochrome reselect left colour escapes: $_prompt_bryndin_header"; exit 1
}

print "PASS: reselecting a theme after teardown rebuilds its arrays"

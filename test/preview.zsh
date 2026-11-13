#!/usr/bin/env zsh
#
# `prompt -p bryndin' must call editor-info after setup.  Otherwise the keymap
# indicator is rendered with the previous theme's formats.
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
git_info=(); python_info=(); editor_info=(keymap '' overwrite '')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' keymap-indicator 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

# A stand-in for Prezto's editor-info: it copies whatever keymap format is
# currently configured.  Before the fix, preview called this before setup and
# captured the previous theme's value.
function editor-info {
  emulate -L zsh
  local fmt
  zstyle -s ':prezto:module:editor:info:keymap:primary' format fmt
  editor_info=(keymap "$fmt" overwrite '')
}

# Pretend another theme left its keymap format in place.
zstyle ':prezto:module:editor:info:keymap:primary' format 'OLD-THEME'

# Minimal promptinit stand-in.  The built-in preview helper calls setup, then
# precmd, then prints the prompt; it does not call editor-info itself.
function prompt_preview_theme {
  emulate -L zsh
  local -a prompt_opts
  print -n "$1 theme:"
  prompt_${1}_setup
  prompt_bryndin_precmd
  print -P -- "${PS1}command arg1 arg2 ... argn"
}

COLUMNS=120
local output=$(prompt_bryndin_preview 2>&1)

[[ $output == *'bryndin theme'* ]] || {
  print -u2 "FAIL: preview did not identify the theme: $output"; exit 1
}
local visible=${output//$'\e'\[[0-9;]#m/}
[[ $visible == *'❯❯❯'* ]] || {
  print -u2 "FAIL: preview used the previous editor format: $output"; exit 1
}
[[ $output != *'OLD-THEME'* ]] || {
  print -u2 "FAIL: previous theme's keymap indicator leaked into preview: $output"; exit 1
}

print "PASS: preview initialises the editor indicator after setup"

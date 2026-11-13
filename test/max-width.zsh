#!/usr/bin/env zsh
#
# Regression test: when max-block-width already clipped the directory in the
# compressed-PWD fallback, the final overflow clipping must start from that
# clipped text rather than the full path.  Otherwise keep is computed from the
# full width and the header still overflows.
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
zstyle ':prezto:module:prompt:bryndin' colors 'none'
zstyle ':prezto:module:prompt:bryndin' compressed-pwd 'full'
zstyle ':prezto:module:prompt:bryndin' max-block-width '20'
zstyle ':prezto:module:prompt:bryndin' blocks 'time'
prompt_newline=$'\n%{\r%}'
source "$theme"

local deep=$(mktemp -d /tmp/opencode/bryndin-max-width.XXXXXX)
local component='verylongdirectoryname'
mkdir -p "${deep}/$(printf "$component%.0s" {1..4})" || exit 1
cd "$deep/$(printf "$component%.0s" {1..4})" || exit 1

COLUMNS=30
prompt_bryndin_precmd

local width_of() {
  local rendered=$(print -P -- "$1")
  rendered=${rendered//$'\e'\[[0-9;]#m/}
  print -r -- ${(m)#rendered}
}

# The directory block must respect max-block-width and the rendered header
# must still fit the terminal.
local dir_width=$(width_of "$_prompt_bryndin_cur_dir")
(( dir_width <= 20 )) || {
  print -u2 "FAIL: directory block is $dir_width columns, max-block-width is 20"; exit 1
}
local header_width=$(width_of "$_prompt_bryndin_header")
(( header_width <= 30 )) || {
  print -u2 "FAIL: header is $header_width columns at COLUMNS=30"; exit 1
}

# Wider terminal: the full path is used again.
COLUMNS=200
prompt_bryndin_prepare_pwd
prompt_bryndin_reflow
[[ $_prompt_bryndin_cur_dir == '%~' ]] || {
  print -u2 "FAIL: wide terminal did not restore %~: $_prompt_bryndin_cur_dir"; exit 1
}

print "PASS: max-block-width and overflow clipping cooperate"

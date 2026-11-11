#!/usr/bin/env zsh
#
# Resizing must re-fit both the header width and the directory compression:
# narrowing the terminal compresses/clips the path, widening restores it.
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
function coalesce {
  local a
  for a in "$@"; do [[ -n $a ]] && { print -rn -- "$a"; return 0 }; done
  return 1
}
function python-info { python_info=(virtualenv '') }

typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

source "$theme"

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

# Non-interactive: treat ZLE as inactive so the resize handler does not call
# the real widget.
function zle { return 1 }

local width_of() {
  local s=$1
  local zero='%([BSUbfksu]|([FBK]|){*})'
  print -r -- ${#${(S%%)s//$~zero/}}
}

local deep=$(mktemp -d /tmp/opencode/bryndin-resize.XXXXXX)
mkdir -p "$deep/alpha/beta/gamma"
cd "$deep/alpha/beta/gamma" || fail "could not enter the test directory"

COLUMNS=200
prompt_bryndin_precmd
[[ $_prompt_bryndin_cur_dir == '%~' ]] || \
  fail "wide header did not start from the full path: $_prompt_bryndin_cur_dir"
local wide_before=$(width_of "$_prompt_bryndin_header")
(( wide_before <= 200 )) || fail "wide header overflows: $wide_before > 200"

COLUMNS=40
prompt_bryndin_resize
[[ $_prompt_bryndin_cur_dir != '%~' ]] || \
  fail "narrow resize did not compress the path"
local narrow=$(width_of "$_prompt_bryndin_header")
(( narrow <= 40 )) || fail "narrow header overflows: $narrow > 40"

COLUMNS=200
prompt_bryndin_resize
[[ $_prompt_bryndin_cur_dir == '%~' ]] || \
  fail "wide resize did not restore the full path: $_prompt_bryndin_cur_dir"
local wide_after=$(width_of "$_prompt_bryndin_header")
(( wide_after <= 200 )) || fail "restored header overflows: $wide_after > 200"

print "PASS: header and PWD re-fit on terminal resize"

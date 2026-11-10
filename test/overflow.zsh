#!/usr/bin/env zsh
#
# Even on a very narrow terminal the header must not exceed COLUMNS: the
# directory block is clipped after the compressed-PWD fallback, and whole
# header blocks are dropped if it still does not fit.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

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

# Pin the virtualenv name so the test does not depend on the caller's
# environment (direnv, for example, may set VIRTUAL_ENV).
unset CONDA_DEFAULT_ENV
VIRTUAL_ENV='/tmp/bryndin-test-virtualenv'

source "$theme"

local width_of() {
  local s=$1
  local zero='%([BSUbfksu]|([FBK]|){*})'
  print -r -- ${(m)#${(S%%)s//$~zero/}}
}

local cols
for cols in 20 30 40 60 80; do
  COLUMNS=$cols
  prompt_bryndin_precmd
  local w=$(width_of "$_prompt_bryndin_header")
  (( w <= cols + 1 )) || {
    print -u2 "FAIL: header is $w columns wide at COLUMNS=$cols"; exit 1
  }
done

# Wide enough for everything: the virtualenv block is present.
COLUMNS=120
prompt_bryndin_precmd
[[ $_prompt_bryndin_header == *'bryndin-test-virtualenv'* ]] || {
  print -u2 "FAIL: virtualenv block missing on a wide terminal"; exit 1
}

# Very narrow: the block is dropped rather than overflowing.
COLUMNS=20
prompt_bryndin_precmd
[[ $_prompt_bryndin_header != *'bryndin-test-virtualenv'* ]] || {
  print -u2 "FAIL: virtualenv block was not dropped on a narrow terminal"; exit 1
}

print "PASS: header never overflows on narrow terminals"

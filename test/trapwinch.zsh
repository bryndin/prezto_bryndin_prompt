#!/usr/bin/env zsh
#
# SIGWINCH handling: the theme must install a resize trap, reflow the header
# on it, and restore any pre-existing trap when torn down.
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
git_info=(); python_info=(); editor_info=(keymap '❯' overwrite '')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

local width_of() {
  local s=$1
  local zero='%([BSUbfksu]|([FBK]|){*})'
  print -r -- ${#${(S%%)s//$~zero/}}
}

local marker='PROBE_USER_TRAP'
PROBE_USER_TRAP=0
TRAPWINCH() { PROBE_USER_TRAP=$(( PROBE_USER_TRAP + 1 )) }

source "$theme"

[[ $functions[TRAPWINCH] == *prompt_bryndin_resize* ]] || \
  fail "resize trap was not installed: $functions[TRAPWINCH]"
(( $+functions[_prompt_bryndin_user_trapwinch] )) || \
  fail "pre-existing trap was not saved for chaining"

COLUMNS=80
prompt_bryndin_precmd
local before=$(width_of "$_prompt_bryndin_header")

COLUMNS=120
prompt_bryndin_resize
local after=$(width_of "$_prompt_bryndin_header")
(( after > before )) || fail "header did not grow on resize ($before -> $after)"
(( PROBE_USER_TRAP == 1 )) || \
  fail "pre-existing TRAPWINCH was not chained (calls: $PROBE_USER_TRAP)"

prompt_bryndin_teardown
[[ $functions[TRAPWINCH] == *"$marker"* ]] || \
  fail "pre-existing TRAPWINCH was not restored: $functions[TRAPWINCH]"
(( $+functions[_prompt_bryndin_user_trapwinch] == 0 )) || \
  fail "saved trap helper was not removed"

# With no pre-existing trap, teardown must remove ours.
unfunction TRAPWINCH
source "$theme"
prompt_bryndin_teardown
(( $+functions[TRAPWINCH] == 0 )) || \
  fail "theme TRAPWINCH was not removed: $functions[TRAPWINCH]"

print "PASS: resize trap reflows, chains, and is restored on teardown"

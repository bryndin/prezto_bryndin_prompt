#!/usr/bin/env zsh
#
# The common precmd path must not fork for the directory or, when no
# virtualenv/conda environment is active, for the virtualenv block.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset VIRTUAL_ENV CONDA_DEFAULT_ENV

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'
source "$theme"

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

# Replace the work with cheap stubs so the test observes only the dispatch.
local pwd_calls=0
function prompt_bryndin_full_pwd_reply {
  (( pwd_calls++ ))
  REPLY='STUB-PWD'
}
function prompt_bryndin_virtualenv_reply {
  REPLY='STUB-VENV'
}

COLUMNS=200
prompt_bryndin_precmd >/dev/null 2>&1 || fail "precmd failed"
[[ $_prompt_bryndin_cur_dir == 'STUB-PWD' ]] || \
  fail "precmd did not use the reply helper: $_prompt_bryndin_cur_dir"
(( pwd_calls == 1 )) || fail "pwd helper called $pwd_calls times"
[[ -z $_prompt_bryndin_venv ]] || fail "unexpected virtualenv text: $_prompt_bryndin_venv"

VIRTUAL_ENV='/tmp/fake-venv'
prompt_bryndin_precmd >/dev/null 2>&1 || fail "precmd failed with a virtualenv"
[[ $_prompt_bryndin_venv == 'STUB-VENV' ]] || \
  fail "virtualenv helper not called with VIRTUAL_ENV set: $_prompt_bryndin_venv"

print "PASS: precmd avoids unnecessary subshell forks"

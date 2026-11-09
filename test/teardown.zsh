#!/usr/bin/env zsh
#
# Teardown must remove hooks, stop the async worker and clear theme state.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function async_stop_worker { typeset -g ASYNC_TEST_STOPPED=$1 }
function prompt_cleanup { typeset -g PROMPT_TEST_CLEANUP=$1 }

source "$theme"

[[ $PROMPT_TEST_CLEANUP == prompt_bryndin_teardown ]] || {
  print -u2 "FAIL: teardown not registered with prompt_cleanup"; exit 1
}

prompt_bryndin_teardown
[[ ${ASYNC_TEST_STOPPED:-} == prompt_bryndin ]] || {
  print -u2 "FAIL: async worker not stopped"; exit 1
}
(( $+_prompt_bryndin_conf == 0 )) || {
  print -u2 "FAIL: globals not cleared"; exit 1
}
zstyle -t ':prezto:module:prompt' managed && {
  print -u2 "FAIL: managed zstyle not removed"; exit 1
}

print "PASS: preview/teardown hooks work"

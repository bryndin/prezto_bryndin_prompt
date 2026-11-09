#!/usr/bin/env zsh
#
# Regression test: the git:info:keys format must defer $(coalesce ...) until
# git-info has substituted %b/%p/%c, so that detached HEAD states fall back to
# the commit hash instead of showing an empty git block.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

function pmodload { : }
function add-zsh-hook { : }
function coalesce {
  local a
  for a in "$@"; do
    [[ -n $a ]] && { print -rn -- "$a"; return 0 }
  done
  return 1
}

source "$theme"

local -a fmts
zstyle -a ':prezto:module:git:info:keys' format fmts || {
  print -u2 "FAIL: no git:info:keys format"; exit 1
}

local fmt=$fmts[2]
[[ $fmt == *'$(coalesce'* ]] || {
  print -u2 "FAIL: coalesce was evaluated at setup time: $fmt"; exit 1
}

# Simulate a detached HEAD: no branch, no position, a short commit.
typeset -gA git_info
zformat -f REPLY "$fmt" \
  "b:" "p:" "c::%F{green}1a2b3c4%f" \
  "s:" "A:" "B:" "S:" "a:" "d:" "m:" "r:" "U:" "u:"
local rendered=${(e)REPLY}

[[ $rendered == *1a2b3c4* ]] || {
  print -u2 "FAIL: commit fallback missing: $rendered"; exit 1
}

print "PASS: coalesce is deferred and falls back to the commit hash"

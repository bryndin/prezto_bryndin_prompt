#!/usr/bin/env zsh
#
# Regression test: a directory name containing '%' must not be interpreted as
# a prompt escape when the compressed PWD is inserted into the header.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

function pmodload { : }
function add-zsh-hook { : }

source "$theme"

local testdir=$(mktemp -d /tmp/opencode/bryndin-pct.XXXXXX)
mkdir -p "$testdir/100%done"
cd -q "$testdir/100%done"

local compressed=$(prompt_bryndin_prepare_compressed_pwd)

[[ $compressed == *'%%'* ]] || {
  print -u2 "FAIL: compressed PWD is not escaped: $compressed"; exit 1
}

local rendered=$(print -P -- "[$compressed]")
[[ $rendered == *'100%done'* ]] || {
  print -u2 "FAIL: '%' was interpreted as a prompt escape: $rendered"; exit 1
}
[[ $rendered != *'100/'* ]] || {
  print -u2 "FAIL: '%d' expanded to the working directory: $rendered"; exit 1
}

print "PASS: literal '%' in directory names survives prompt expansion"

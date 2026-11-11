#!/usr/bin/env zsh
#
# A remote root prompt must keep the hostname.  It used to live inside the
# non-root branch of %(!...), so `sudo -s', `su' and SSH root sessions showed
# only the username.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}

if (( EUID != 0 )); then
  if ! command -v unshare >/dev/null 2>&1 || ! unshare -r true 2>/dev/null; then
    print "SKIP: root user namespace unavailable"
    exit 0
  fi
  # Re-run in a user namespace so prompt expansion sees EUID 0.
  exec unshare -r zsh "$0" "$theme"
fi

function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
zstyle ':prezto:module:prompt:bryndin' host 'always'
zstyle ':prezto:module:prompt:bryndin' blocks 'host'
prompt_newline=$'\n%{\r%}'
source "$theme"

local rendered=$(print -P -- "$_prompt_bryndin_block_text[host]")
[[ $rendered == *'@'* ]] || {
  print -u2 "FAIL: root host block lost the hostname: $rendered"; exit 1
}
[[ $rendered == *'root'* ]] || {
  print -u2 "FAIL: root host block has no root user: $rendered"; exit 1
}

print "PASS: root host block keeps the hostname"

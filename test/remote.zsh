#!/usr/bin/env zsh
#
# Host block visibility: SSH_TTY / SSH_CLIENT / SSH_CONNECTION and explicit
# always/never overrides.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

local check() {
  local expect=$1 label=$2
  if [[ $expect == yes ]]; then
    [[ $_prompt_bryndin_left == *'@%m'* ]] || {
      print -u2 "FAIL: $label: host block missing"; exit 1
    }
  else
    [[ $_prompt_bryndin_left != *'@%m'* ]] || {
      print -u2 "FAIL: $label: host block should be hidden"; exit 1
    }
  fi
}

# No SSH variables: hidden by default.
unset SSH_TTY SSH_CLIENT SSH_CONNECTION
source "$theme"
check no "auto without ssh"

# Re-run setup after changing the environment / styles.
SSH_CONNECTION='10.0.0.1 1234 10.0.0.2 22'
prompt_bryndin_setup
check yes "SSH_CONNECTION"

SSH_CONNECTION=''
SSH_TTY=/dev/pts/0
prompt_bryndin_setup
check yes "SSH_TTY"

zstyle ':prezto:module:prompt:bryndin' host 'never'
prompt_bryndin_setup
check no "host=never overrides ssh"

zstyle ':prezto:module:prompt:bryndin' host 'always'
unset SSH_TTY SSH_CLIENT SSH_CONNECTION
prompt_bryndin_setup
check yes "host=always forces the host"

print "PASS: remote detection works"

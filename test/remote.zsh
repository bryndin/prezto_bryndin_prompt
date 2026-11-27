#!/usr/bin/env zsh
#
# Host block visibility: SSH_TTY / SSH_CLIENT / SSH_CONNECTION and explicit
# always/never overrides.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset NO_COLOR VIRTUAL_ENV CONDA_DEFAULT_ENV
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

# No SSH/su variables: hidden by default.
unset SSH_TTY SSH_CLIENT SSH_CONNECTION SUDO_USER LOGNAME
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

# sudo -s: USER is still root, but SUDO_USER records the invoking account.
unset SSH_TTY SSH_CLIENT SSH_CONNECTION
SUDO_USER='someone-else'
prompt_bryndin_setup
check yes "SUDO_USER"
unset SUDO_USER

# LOGNAME != USER triggers remote detection without forking `logname`.
LOGNAME='other-login'
prompt_bryndin_setup
check yes "LOGNAME != USER"
unset LOGNAME

zstyle ':prezto:module:prompt:bryndin' host 'never'
prompt_bryndin_setup
check no "host=never overrides ssh"

zstyle ':prezto:module:prompt:bryndin' host 'always'
unset SSH_TTY SSH_CLIENT SSH_CONNECTION
prompt_bryndin_setup
check yes "host=always forces the host"

# `user` zstyle: always | auto | never.
zstyle ':prezto:module:prompt:bryndin' host 'auto'
zstyle ':prezto:module:prompt:bryndin' user 'auto'
prompt_bryndin_setup
[[ -z $_prompt_bryndin_block_text[host] ]] || {
  print -u2 "FAIL: user=auto on local non-root shell should hide host block: $_prompt_bryndin_block_text[host]"; exit 1
}

SSH_TTY=/dev/pts/0
prompt_bryndin_setup
[[ $_prompt_bryndin_block_text[host] == *'%n'*'@%m'* ]] || {
  print -u2 "FAIL: user=auto on remote shell lost user@host: $_prompt_bryndin_block_text[host]"; exit 1
}
unset SSH_TTY

zstyle ':prezto:module:prompt:bryndin' user 'never'
zstyle ':prezto:module:prompt:bryndin' host 'always'
prompt_bryndin_setup
[[ $_prompt_bryndin_block_text[host] == *'%m'* && $_prompt_bryndin_block_text[host] != *'%n'* && $_prompt_bryndin_block_text[host] != *'@'* ]] || {
  print -u2 "FAIL: user=never with host=always wrong: $_prompt_bryndin_block_text[host]"; exit 1
}

zstyle ':prezto:module:prompt:bryndin' host 'never'
prompt_bryndin_setup
[[ -z $_prompt_bryndin_block_text[host] ]] || {
  print -u2 "FAIL: user=never with host=never should hide host block: $_prompt_bryndin_block_text[host]"; exit 1
}

if (( EUID != 0 )) && command -v unshare >/dev/null 2>&1 && unshare -r true 2>/dev/null; then
  local root_user_auto=$(unshare -r zsh -fc "
    emulate -LR zsh; zmodload -i zsh/zutil
    setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE
    unset SSH_TTY SSH_CLIENT SSH_CONNECTION SUDO_USER LOGNAME NO_COLOR VIRTUAL_ENV CONDA_DEFAULT_ENV
    function pmodload { : }; function add-zsh-hook { : }; function add-zle-hook-widget { : }
    zstyle ':prezto:module:prompt:bryndin' async 'no'
    zstyle ':prezto:module:prompt:bryndin' colors 'none'
    zstyle ':prezto:module:prompt:bryndin' user 'auto'
    zstyle ':prezto:module:prompt:bryndin' host 'auto'
    source '$theme'
    print -P -- \"\$_prompt_bryndin_block_text[host]\"
  ")
  [[ $root_user_auto == *'root'* && $root_user_auto != *'@'* ]] || {
    print -u2 "FAIL: user=auto on local root should show root without @host: $root_user_auto"; exit 1
  }
fi

print "PASS: remote detection and user visibility work"

#!/usr/bin/env zsh
#
# Directory display: the full mode must use %~, the configurable styles must be
# honoured, and Prezto's prompt-pwd helper must be preferred when it exists.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

# Put a fake prompt-pwd in fpath so the delegation path is exercised.
local helper_dir=$(mktemp -d /tmp/opencode/bryndin-pwd.XXXXXX)
print -r -- 'print -r -- "FROM-PROMPT-PWD"' > "$helper_dir/prompt-pwd"
fpath=( "$helper_dir" $fpath )

source "$theme"

[[ $(prompt_bryndin_prepare_full_pwd) == *'%~'* ]] || {
  print -u2 "FAIL: full PWD does not use %~"; exit 1
}
prompt_bryndin_full_pwd_reply
[[ $REPLY == *'%~'* ]] || {
  print -u2 "FAIL: REPLY did not receive %~: $REPLY"; exit 1
}
[[ $(prompt_bryndin_prepare_full_pwd) == "$REPLY" ]] || {
  print -u2 "FAIL: print and REPLY forms disagree: $(prompt_bryndin_prepare_full_pwd) != $REPLY"; exit 1
}

# default style delegates to prompt-pwd
[[ $(prompt_bryndin_pwd_text) == 'FROM-PROMPT-PWD' ]] || {
  print -u2 "FAIL: prompt-pwd helper was not used: $(prompt_bryndin_pwd_text)"; exit 1
}

_prompt_bryndin_conf[compressed-pwd]='tilde'
local expected=${PWD/#$HOME/\~}
[[ $(prompt_bryndin_pwd_text) == "$expected" ]] || {
  print -u2 "FAIL: tilde style: $(prompt_bryndin_pwd_text) != $expected"; exit 1
}

_prompt_bryndin_conf[compressed-pwd]='full'
[[ $(prompt_bryndin_pwd_text) == "$PWD" ]] || {
  print -u2 "FAIL: full style: $(prompt_bryndin_pwd_text) != $PWD"; exit 1
}

# A wide header keeps the full %~ path; the style is the overflow fallback.
_prompt_bryndin_conf[compressed-pwd]='tilde'
COLUMNS=200
prompt_bryndin_precmd
[[ $_prompt_bryndin_cur_dir == *'%~'* ]] || {
  print -u2 "FAIL: wide header did not use %~: $_prompt_bryndin_cur_dir"; exit 1
}

# `pwd' remains an alias for `compressed-pwd'.
zstyle -d ':prezto:module:prompt:bryndin' pwd
zstyle -d ':prezto:module:prompt:bryndin' compressed-pwd
zstyle ':prezto:module:prompt:bryndin' pwd 'tilde'
prompt_bryndin_load_config
[[ $_prompt_bryndin_conf[compressed-pwd] == 'tilde' ]] || {
  print -u2 "FAIL: pwd alias not honoured: $_prompt_bryndin_conf[compressed-pwd]"; exit 1
}

# The explicit `compressed-pwd' style wins over the alias.
zstyle ':prezto:module:prompt:bryndin' compressed-pwd 'full'
prompt_bryndin_load_config
[[ $_prompt_bryndin_conf[compressed-pwd] == 'full' ]] || {
  print -u2 "FAIL: compressed-pwd did not override pwd: $_prompt_bryndin_conf[compressed-pwd]"; exit 1
}

# A sibling directory with the same prefix as HOME must not become "~...".
local base=$(mktemp -d /tmp/opencode/bryndin-home.XXXXXX)
mkdir -p "$base/alex/sub" "$base/alexander"
local old_home=$HOME
HOME="$base/alex"
_prompt_bryndin_conf[compressed-pwd]='tilde'
cd "$base/alexander" || exit 1
[[ $(prompt_bryndin_pwd_text 0) == "$base/alexander" ]] || {
  print -u2 "FAIL: sibling path was treated as HOME: $(prompt_bryndin_pwd_text 0)"; exit 1
}
cd "$HOME" || exit 1
[[ $(prompt_bryndin_pwd_text 0) == '~' ]] || {
  print -u2 "FAIL: exact HOME did not render as ~: $(prompt_bryndin_pwd_text 0)"; exit 1
}
cd "$HOME/sub" || exit 1
[[ $(prompt_bryndin_pwd_text 0) == '~/sub' ]] || {
  print -u2 "FAIL: HOME child did not render as ~/sub: $(prompt_bryndin_pwd_text 0)"; exit 1
}
HOME=$old_home

print "PASS: PWD styles and prompt-pwd delegation work"

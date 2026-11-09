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

# default style delegates to prompt-pwd
[[ $(prompt_bryndin_pwd_text) == 'FROM-PROMPT-PWD' ]] || {
  print -u2 "FAIL: prompt-pwd helper was not used: $(prompt_bryndin_pwd_text)"; exit 1
}

_prompt_bryndin_conf[pwd]='tilde'
local expected=${PWD/#$HOME/\~}
[[ $(prompt_bryndin_pwd_text) == "$expected" ]] || {
  print -u2 "FAIL: tilde style: $(prompt_bryndin_pwd_text) != $expected"; exit 1
}

_prompt_bryndin_conf[pwd]='full'
[[ $(prompt_bryndin_pwd_text) == "$PWD" ]] || {
  print -u2 "FAIL: full style: $(prompt_bryndin_pwd_text) != $PWD"; exit 1
}

print "PASS: PWD styles and prompt-pwd delegation work"

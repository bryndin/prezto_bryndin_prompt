#!/usr/bin/env zsh
#
# The ZLE keymap indicator (❯❯❯) is opt-in and off by default.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset NO_COLOR VIRTUAL_ENV CONDA_DEFAULT_ENV
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯❯❯' overwrite '')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' overwrite 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

[[ $PROMPT != *'editor_info[keymap]'* ]] || {
  print -u2 "FAIL: keymap indicator is on by default: $PROMPT"; exit 1
}
[[ $PROMPT == *'❯'* ]] || {
  print -u2 "FAIL: default non-root prompt has no prompt character: $PROMPT"; exit 1
}
local strip_esc() {
  local s=$1
  s=${s//$'\e'(\[[0-9;?]#[a-zA-Z]|[()][0-9A-Za-z]|[=>78])/}
  s=${s//$'\017'/}
  print -r -- "$s"
}

local rendered=$(strip_esc "$(print -P -- "$PROMPT")")
[[ $rendered == *'❯ ' ]] || {
  print -u2 "FAIL: default non-root prompt missing trailing space: <$rendered>"; exit 1
}
[[ $rendered != *'  ' ]] || {
  print -u2 "FAIL: default prompt has double trailing space: <$rendered>"; exit 1
}

editor_info[overwrite]=' ♺'
rendered=$(strip_esc "$(print -P -- "$PROMPT")")
[[ $rendered == *'❯ ♺ ' ]] || {
  print -u2 "FAIL: overwrite spacing wrong: <$rendered>"; exit 1
}
editor_info[overwrite]=''

zstyle ':prezto:module:prompt:bryndin' keymap-indicator 'yes'
prompt_bryndin_setup
[[ $PROMPT == *'${editor_info[keymap]}'* ]] || {
  print -u2 "FAIL: keymap-indicator=yes ignored: $PROMPT"; exit 1
}
rendered=$(strip_esc "$(print -P -- "$PROMPT")")
[[ $rendered == *'❯❯❯ ' ]] || {
  print -u2 "FAIL: keymap indicator missing trailing space: <$rendered>"; exit 1
}
editor_info[overwrite]=' ♺'
rendered=$(strip_esc "$(print -P -- "$PROMPT")")
[[ $rendered == *'❯❯❯ ♺ ' ]] || {
  print -u2 "FAIL: keymap overwrite spacing wrong: <$rendered>"; exit 1
}

if command -v unshare >/dev/null 2>&1 && unshare -r true 2>/dev/null; then
  local root_out=$(unshare -r zsh -fc "
    emulate -LR zsh; zmodload -i zsh/zutil
    setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE
    function pmodload { : }; function add-zsh-hook { : }; function add-zle-hook-widget { : }
    typeset -gA git_info python_info editor_info
    git_info=(); python_info=(); editor_info=(keymap '❯❯❯' overwrite '')
    zstyle ':prezto:module:prompt:bryndin' async 'no'
    zstyle ':prezto:module:prompt:bryndin' single-line 'yes'
    source '$theme'
    r=\$(print -P -- \"\$PROMPT\")
    r=\${r//\$'\e'(\\[[0-9;?]#[a-zA-Z]|[()][0-9A-Za-z]|[=>78])/}
    print -r -- \"def=<\${r//\$'\017'/}>\"
    zstyle ':prezto:module:prompt:bryndin' keymap-indicator 'yes'
    prompt_bryndin_setup
    r=\$(print -P -- \"\$PROMPT\")
    r=\${r//\$'\e'(\\[[0-9;?]#[a-zA-Z]|[()][0-9A-Za-z]|[=>78])/}
    print -r -- \"km=<\${r//\$'\017'/}>\"
  ")
  [[ $root_out == *'def=<# >'* && $root_out == *'km=<# ❯❯❯ >'* ]] || {
    print -u2 "FAIL: root prompt spacing wrong: $root_out"; exit 1
  }
fi

print "PASS: keymap indicator and prompt spacing work"

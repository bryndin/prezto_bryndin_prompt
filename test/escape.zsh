#!/usr/bin/env zsh
#
# Dynamic text (virtualenv names) must be escaped before it reaches a prompt
# string, otherwise a '%' in the name is interpreted as a prompt escape.
# Dollar signs, backslashes and backticks are literal text: they are inserted
# through a parameter expansion and are not re-parsed by prompt_subst, so
# escaping them would add visible backslashes and inflate the measured width.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset VIRTUAL_ENV CONDA_DEFAULT_ENV NO_COLOR
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function python-info { python_info=(virtualenv '') }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' colors '256'
prompt_newline=$'\n%{\r%}'
source "$theme"

VIRTUAL_ENV='/tmp/100%done'
prompt_bryndin_virtualenv_reply
[[ $REPLY == *'100%%done'* ]] || {
  print -u2 "FAIL: venv name not escaped: $REPLY"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd
local rendered=$(print -P -- "$_prompt_bryndin_header")
[[ $rendered == *'100%done'* ]] || {
  print -u2 "FAIL: '%' in venv name was expanded: $rendered"; exit 1
}
[[ $rendered != *'100/'* ]] || {
  print -u2 "FAIL: '%d' expanded to the working directory"; exit 1
}

# $, backticks and backslashes are literal: no defence-in-depth backslashes.
local tricky='$(echo PWNED)'
prompt_bryndin_escape_reply "$tricky"
[[ $REPLY == "$tricky" ]] || {
  print -u2 "FAIL: dollar sign was escaped: $REPLY"; exit 1
}
prompt_bryndin_escape_reply 'x\y'
[[ $REPLY == 'x\y' ]] || {
  print -u2 "FAIL: backslash was escaped: $REPLY"; exit 1
}
prompt_bryndin_escape_reply 'x`y'
[[ $REPLY == 'x`y' ]] || {
  print -u2 "FAIL: backtick was escaped: $REPLY"; exit 1
}

# A command substitution in a venv name is displayed literally and never run,
# including during width measurement in precmd.
local marker="bryndin_escape_pwned_$$"
VIRTUAL_ENV="/tmp/\$(touch $marker)"
prompt_bryndin_precmd
[[ ! -e $marker ]] || {
  print -u2 "FAIL: venv name executed a command substitution"; exit 1
}
[[ $_prompt_bryndin_header == *'$(touch '"$marker"')'* ]] || {
  print -u2 "FAIL: command substitution was not kept literal: $_prompt_bryndin_header"; exit 1
}

print "PASS: dynamic text is escaped for prompt expansion"

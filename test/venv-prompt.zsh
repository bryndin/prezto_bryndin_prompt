#!/usr/bin/env zsh
#
# virtualenv's activate scripts prefix $PS1 -- the same parameter as $PROMPT
# in zsh, i.e. this very theme -- with `(.venv) ' while
# VIRTUAL_ENV_DISABLE_PROMPT is unset.  Prezto's python module exports it only
# when virtualenvwrapper is initialised, so setup must adopt the disabling
# sentinel itself, without clobbering other themes' or the user's own values.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function async_stop_worker { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=()
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

# Faithful copy of the prompt guard from Python's venv / virtualenv activate
# scripts (see `bin/activate' in either of them).
function _activate_prompt {
  if [ -z "${VIRTUAL_ENV_DISABLE_PROMPT:-}" ] ; then
    PS1='(.venv) '"${PS1:-}"
  fi
}

# Unset variable (the plain `venv' case): setup must adopt the sentinel.
unset VIRTUAL_ENV_DISABLE_PROMPT
source "$theme"
[[ ${VIRTUAL_ENV_DISABLE_PROMPT-} == 20 ]] || {
  print -u2 "FAIL: sentinel not set, got '${VIRTUAL_ENV_DISABLE_PROMPT-}'"; exit 1
}
_activate_prompt
[[ $PROMPT != '(.venv) '* ]] || {
  print -u2 "FAIL: activate script prefixed the prompt"; exit 1
}
[[ $PS1 == $PROMPT ]] || {
  print -u2 "FAIL: PS1 and PROMPT diverged: ($PS1) vs ($PROMPT)"; exit 1
}

# A user's own non-sentinel value must survive untouched.
export VIRTUAL_ENV_DISABLE_PROMPT='1'
source "$theme"
[[ $VIRTUAL_ENV_DISABLE_PROMPT == '1' ]] || {
  print -u2 "FAIL: user value clobbered, got '${VIRTUAL_ENV_DISABLE_PROMPT}'"; exit 1
}
_activate_prompt
[[ $PROMPT != '(.venv) '* ]] || {
  print -u2 "FAIL: user value failed to disable the prefix"; exit 1
}

# The pure / python-module sentinel is simply kept.
export VIRTUAL_ENV_DISABLE_PROMPT=20
source "$theme"
[[ $VIRTUAL_ENV_DISABLE_PROMPT == 20 ]] || {
  print -u2 "FAIL: sentinel clobbered, got '${VIRTUAL_ENV_DISABLE_PROMPT}'"; exit 1
}

# An empty value behaves like unset for the activate scripts; pure replaces it
# with the sentinel too, so accepting that here is harmless.
export VIRTUAL_ENV_DISABLE_PROMPT=''
source "$theme"
[[ ${VIRTUAL_ENV_DISABLE_PROMPT-} == 20 ]] || {
  print -u2 "FAIL: empty value not treated as unset"; exit 1
}
_activate_prompt
[[ $PROMPT != '(.venv) '* ]] || {
  print -u2 "FAIL: empty value failed to disable the prefix"; exit 1
}

print "PASS: venv activate scripts cannot prefix the prompt"

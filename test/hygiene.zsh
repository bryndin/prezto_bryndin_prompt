#!/usr/bin/env zsh
#
# Framework hygiene: user options such as NO_UNSET and KSH_ARRAYS must not
# leak into the theme's prompt hooks, COLUMNS must have a sane fallback, and
# the file must be loadable outside a Prezto session.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset VIRTUAL_ENV CONDA_DEFAULT_ENV
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'

local child=$(mktemp /tmp/opencode/bryndin-hygiene.XXXXXX)
local out option

for option in NO_UNSET KSH_ARRAYS WARN_CREATE_GLOBAL; do
  cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE $option
unset VIRTUAL_ENV CONDA_DEFAULT_ENV NO_COLOR
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
source "$theme"
COLUMNS=80
prompt_bryndin_precmd
prompt_bryndin_teardown
prompt_bryndin_setup
prompt_bryndin_precmd
print OK
EOF
  out=$(zsh "$child" 2>&1)
  [[ $out == *OK* ]] || {
    print -u2 "FAIL: precmd failed with $option: $out"; exit 1
  }
  [[ $out != *'parameter not set'* && $out != *'bad output format'* && $out != *'created globally'* ]] || {
    print -u2 "FAIL: $option leaked into the theme: $out"; exit 1
  }
done

# COLUMNS may be unset outside an interactive shell; use a usable default
# instead of treating the left side as zero columns.
cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE
unset VIRTUAL_ENV CONDA_DEFAULT_ENV COLUMNS
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
source "$theme"
prompt_bryndin_measure 'abc' ''
print -r -- "filler=\$_prompt_bryndin_filler_width"
EOF
out=$(zsh "$child" 2>&1)
[[ $out == *'filler=77'* ]] || {
  print -u2 "FAIL: unset COLUMNS did not fall back to 80: $out"; exit 1
}

# Source without Prezto's pmodload.  Missing optional modules must not be an
# error; the theme guards git-info and python-info itself.
cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE
unset VIRTUAL_ENV CONDA_DEFAULT_ENV
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
source "$theme"
print OK
EOF
out=$(zsh "$child" 2>&1)
[[ $out == *OK* ]] || {
  print -u2 "FAIL: theme cannot be sourced without pmodload: $out"; exit 1
}
[[ $out != *'command not found'* ]] || {
  print -u2 "FAIL: missing pmodload was not guarded: $out"; exit 1
}

print "PASS: theme respects user options and optional modules"

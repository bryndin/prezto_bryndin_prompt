#!/usr/bin/env zsh
#
# Smoke tests for the bryndin Prezto prompt.
#
# Usage: zsh test/smoke.zsh [path/to/prompt_bryndin_setup]
#
# The theme is loaded in a stripped-down, non-interactive shell with the Prezto
# modules it depends on stubbed out.  Its precmd hook is invoked and PROMPT is
# rendered.  The checks below are deliberately generic: they must hold for the
# minimal theme as well as for every optional feature built on top of it, so
# that the harness is useful at every point in the commit history.
#
emulate -LR zsh
zmodload -i zsh/zutil

setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT PROMPT_CR MULTIBYTE
unsetopt KSH_ARRAYS

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
[[ -r $theme ]] || { print -u2 "cannot read $theme"; exit 1 }

local testdir=$(mktemp -d /tmp/opencode/bryndin.XXXXXX)
local setup_err=$testdir/setup.err
: > "$setup_err"

# --------------------------------------------------------------------------
# Prezto stubs
# --------------------------------------------------------------------------
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function async { : }
function async_start_worker { : }
function async_register_callback { : }
function async_flush_jobs { : }
function async_job { : }

function coalesce {
  local a
  for a in "$@"; do
    [[ -n $a ]] && { print -rn -- "$a"; return 0 }
  done
  return 1
}

function escape-eval {
  emulate -L zsh
  setopt EXTENDED_GLOB
  print -r -- "${1//(#m)[\\\$\`]/\\$MATCH}"
}

# A minimal stand-in for Prezto's prompt-pwd.  Kept local to this harness so
# the tests do not require a Prezto installation.
function prompt-pwd {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local current_pwd="${PWD/#$HOME/~}"
  local ret
  if [[ "$current_pwd" == (#m)[/~] ]]; then
    ret="$MATCH"
  else
    ret="${${${${(@j:/:M)${(@s:/:)current_pwd}##.#?}:h}%/}//\%/%%}/${${current_pwd:t}//\%/%%}"
  fi
  print -r -- "$ret"
}

typeset -gA git_info python_info editor_info
git_info=()
python_info=()
editor_info=(keymap '❯❯❯')

# Exercise the configured git:info:keys format the way real git-info does:
# zformat substitutes %b/%p/%c/... and leaves $(...) for later evaluation.
function git-info {
  emulate -L zsh
  local -a fmts
  local key fmt
  git_info=()
  zstyle -a ':prezto:module:git:info:keys' format fmts || return 1
  for key fmt in "$fmts[@]"; do
    zformat -f REPLY "$fmt" \
      "b::%F{green}main%f" "p:" "c::%F{green}1a2b3c4%f" \
      "s:" "A:" "B:" "S:" "a:" "d:" "m:" "r:" "U:" "u:" \
      "C:" "D:" "R:" "i:" "I:"
    git_info[$key]="$REPLY"
  done
  unset REPLY
}

function python-info {
  python_info=(virtualenv '%F{yellow}(venv)%f')
}

# Prevent an opt-in async worker from being started in the test shell.
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' colors '256'
zstyle ':prezto:module:prompt:bryndin' duration 'no'
zstyle ':prezto:module:prompt:bryndin' history 'no'
prompt_newline=$'\n%{\r%}'

# --------------------------------------------------------------------------
# Load
# --------------------------------------------------------------------------
local -a failures
local output

zsh -n "$theme" || failures+=("zsh -n failed")

source "$theme" 2> "$setup_err"

COLUMNS=80
mkdir -p "$testdir/work"
cd -q "$testdir/work"

# Run the precmd hook and render PROMPT, capturing everything the theme emits.
output=$(prompt_bryndin_precmd 2>&1; print -P -- "$PROMPT" 2>&1)
output+="$(<"$setup_err")"

# Strip SGR/CSI sequences so widths are computed on visible text.
local visible=${output//$'\e'\[[0-9;]#m/}
visible=${visible//$'\r'/}

# --------------------------------------------------------------------------
# Invariants
# --------------------------------------------------------------------------
[[ $output == *"command not found"* ]] && failures+=("undefined function called")
[[ $output == *"bad option"* ]]       && failures+=("bad print option")
[[ $output == *"no such file"* ]]     && failures+=("missing dependency")
[[ $output == *"\${"* ]]             && failures+=("unexpanded parameter in prompt")
[[ $output == *"PWNED"* ]]           && failures+=("unexpected command substitution")

# The separator must be present and must not exceed the terminal width by more
# than a couple of columns (a trailing wide glyph can round up by one).
local line max_width=0 width
for line in ${(f)visible}; do
  width=${(m)#line}
  (( width > max_width )) && max_width=$width
done
(( max_width > COLUMNS + 2 )) && failures+=("header overflows: $max_width > $COLUMNS")
[[ $visible != *─* ]] && failures+=("separator glyph missing")

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
if (( $#failures )); then
  print -u2 "FAIL:"
  for line in $failures; do print -u2 "  - $line"; done
  print -u2 "--- rendered ---"
  print -u2 -- "$output"
  exit 1
fi

print "PASS: $theme"
exit 0

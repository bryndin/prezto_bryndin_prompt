#!/usr/bin/env zsh
#
# Colour capability detection: NO_COLOR / colors=none must produce a plain
# header, and a 16-colour terminal must downgrade numeric 256-colour indexes.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

# --- monochrome via NO_COLOR ------------------------------------------------
NO_COLOR=1
source "$theme"
(( _prompt_bryndin_monochrome == 1 )) || {
  print -u2 "FAIL: NO_COLOR did not enable monochrome mode"; exit 1
}
[[ -z $_prompt_bryndin_fg[main-color] ]] || {
  print -u2 "FAIL: colours still emitted in monochrome mode"; exit 1
}
[[ -z $_prompt_bryndin_fg[reset] ]] || {
  print -u2 "FAIL: reset still emitted in monochrome mode"; exit 1
}
COLUMNS=80
prompt_bryndin_precmd
[[ $_prompt_bryndin_header != *'%F{'* ]] || {
  print -u2 "FAIL: header still contains %F escapes: $_prompt_bryndin_header"; exit 1
}
[[ $SPROMPT != *'%F{'* ]] || {
  print -u2 "FAIL: SPROMPT still contains %F escapes"; exit 1
}
local keymap
zstyle -s ':prezto:module:editor:info:keymap:primary' format keymap
[[ $keymap != *'%F{'* ]] || {
  print -u2 "FAIL: editor keymap still contains %F escapes: $keymap"; exit 1
}

# --- 16-colour downgrade ---------------------------------------------------
# Reload in a clean child so the earlier zstyles/variables do not leak.
local child=$(mktemp /tmp/opencode/bryndin-colors.XXXXXX)
cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT
zstyle ':prezto:module:prompt:bryndin' colors '16'
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
source "$theme"
print -r -- "\$_prompt_bryndin_fg[time-color] \$_prompt_bryndin_fg[dir-color]"
EOF
local downgraded=$(zsh "$child")
[[ $downgraded == '%F{4}'* ]] || {
  print -u2 "FAIL: numeric 256-colour index was not downgraded: $downgraded"; exit 1
}

print "PASS: NO_COLOR and 16-colour downgrade work"

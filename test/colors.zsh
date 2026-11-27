#!/usr/bin/env zsh
#
# Colour capability detection: NO_COLOR / colors=none must produce a plain
# header, and a 16-colour terminal must downgrade numeric 256-colour indexes.
#
emulate -LR zsh
zmodload -i zsh/zutil
zmodload -i zsh/terminfo
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv and colour overrides out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV COLORTERM NO_COLOR

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
local keymap git_renamed git_unmerged
zstyle -s ':prezto:module:editor:info:keymap:primary' format keymap
[[ $keymap != *'%F{'* ]] || {
  print -u2 "FAIL: editor keymap still contains %F escapes: $keymap"; exit 1
}
zstyle -s ':prezto:module:git:info:renamed' format git_renamed
zstyle -s ':prezto:module:git:info:unmerged' format git_unmerged
[[ $git_renamed != *'%F{'* && $git_unmerged != *'%F{'* ]] || {
  print -u2 "FAIL: git formats still contain %F escapes in monochrome mode"; exit 1
}

# Literal escaped percent pairs must survive monochrome stripping: a directory
# named "%F{red}" is text, not a colour escape.
prompt_bryndin_strip_colors_reply 'x%%F{red}y'
[[ $REPLY == 'x%%F{red}y' ]] || {
  print -u2 "FAIL: monochrome strip corrupted a literal escape: $REPLY"; exit 1
}
prompt_bryndin_strip_colors_reply 'x%F{red}y'
[[ $REPLY == 'xy' ]] || {
  print -u2 "FAIL: monochrome strip left a real colour escape: $REPLY"; exit 1
}

local saved_left=$_prompt_bryndin_left_expanded
local saved_right=$_prompt_bryndin_right_expanded
_prompt_bryndin_left_expanded=''
_prompt_bryndin_right_expanded='[x%%F{red}y]'
COLUMNS=40
prompt_bryndin_reflow
[[ $_prompt_bryndin_header == *'x%%F{red}y'* ]] || {
  print -u2 "FAIL: reflow stripped a literal escape: $_prompt_bryndin_header"; exit 1
}
local header_rendered=$(print -P -- "$_prompt_bryndin_header")
[[ $header_rendered == *'x%F{red}y'* ]] || {
  print -u2 "FAIL: literal escape did not render: $header_rendered"; exit 1
}
_prompt_bryndin_left_expanded=$saved_left
_prompt_bryndin_right_expanded=$saved_right

# --- 16-colour downgrade ---------------------------------------------------
# Reload in a clean child so the earlier zstyles/variables do not leak.
local child=$(mktemp /tmp/opencode/bryndin-colors.XXXXXX)
cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
zmodload -i zsh/terminfo
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT
export TERM=xterm-256color
unset COLORTERM
zstyle ':prezto:module:prompt:bryndin' colors '16'
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
source "$theme"
print -r -- "time=\$_prompt_bryndin_fg[time-color]"
for spec in 1 4 15 16 21 231 232 244 255 256; do
  prompt_bryndin_color_escape_reply \$spec
  print -r -- "\$spec=\$REPLY"
done
EOF
local downgraded=$(zsh "$child")
[[ $downgraded == *'time=%F{4}'* ]] || {
  print -u2 "FAIL: numeric 256-colour index was not downgraded: $downgraded"; exit 1
}
local line
for line in \
  '1=%F{1}' '4=%F{4}' '15=%F{15}' \
  '16=%F{0}' '21=%F{4}' '231=%F{7}' \
  '232=%F{8}' '244=%F{7}' '255=%F{7}' '256=%F{default}'; do
  [[ $downgraded == *"$line"* ]] || {
    print -u2 "FAIL: 16-colour downgrade wrong for $line: $downgraded"; exit 1
  }
done

# --- 8-colour downgrade and COLORTERM=truecolor ----------------------------
local child8=$(mktemp /tmp/opencode/bryndin-colors8.XXXXXX)
cat > "$child8" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
zmodload -i zsh/terminfo
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT
export TERM=xterm
unset COLORTERM
zstyle ':prezto:module:prompt:bryndin' colors 'auto'
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
source "$theme"
print -r -- "ncolors=\${terminfo[colors]:-0}"
for spec in 8 9 15 16 232 244 27; do
  prompt_bryndin_color_escape_reply \$spec
  print -r -- "\$spec=\$REPLY"
done
COLORTERM=truecolor
prompt_bryndin_color_escape_reply 27
print -r -- "truecolor=\$REPLY"
EOF
local out8=$(zsh "$child8")
if [[ $out8 == *'ncolors=8'* ]]; then
  for line in \
    '8=%F{0}' '9=%F{1}' '15=%F{7}' \
    '16=%F{0}' '232=%F{0}' '244=%F{7}' '27=%F{4}'; do
    [[ $out8 == *"$line"* ]] || {
      print -u2 "FAIL: 8-colour downgrade wrong for $line: $out8"; exit 1
    }
  done
  # A truecolor-capable terminal is not downgraded just because terminfo says 8.
  [[ $out8 == *'truecolor=%F{27}'* ]] || {
    print -u2 "FAIL: COLORTERM=truecolor was downgraded: $out8"; exit 1
  }
else
  print "SKIP: TERM=xterm does not advertise 8 colours here"
fi

print "PASS: NO_COLOR and 16-colour downgrade work"

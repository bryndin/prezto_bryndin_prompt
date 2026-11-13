#!/usr/bin/env zsh
#
# Widths must be measured in display columns, not characters, and clipping
# must respect those columns.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
source "$theme"

local wide='日本語'
(( ${(m)#wide} == 6 )) || {
  print -u2 "FAIL: zsh is not counting display columns"; exit 1
}

# AB日本語 occupies 8 display columns (2 + 3*2), leaving 12 of 20.
COLUMNS=20
_prompt_bryndin_left_expanded='AB日本語'
_prompt_bryndin_right_expanded=''
prompt_bryndin_measure "$_prompt_bryndin_left_expanded" "$_prompt_bryndin_right_expanded"
(( _prompt_bryndin_filler_width == 12 )) || {
  print -u2 "FAIL: wide chars not counted in display columns (filler=$_prompt_bryndin_filler_width)"; exit 1
}

local clipped=$(prompt_bryndin_clip 'abcdefghij' 5)
(( ${(m)#clipped} == 5 )) || {
  print -u2 "FAIL: clip produced $clipped (width ${(m)#clipped})"; exit 1
}
[[ $clipped == *'…'* ]] || {
  print -u2 "FAIL: clipped text has no ellipsis"; exit 1
}
prompt_bryndin_clip_reply 'abcdefghij' 5
[[ $REPLY == "$clipped" ]] || {
  print -u2 "FAIL: clip reply differs: $REPLY != $clipped"; exit 1
}

# Optional right margin.
COLUMNS=20
_prompt_bryndin_conf[margin]='1'
_prompt_bryndin_left_expanded='AB'
_prompt_bryndin_right_expanded=''
prompt_bryndin_measure "$_prompt_bryndin_left_expanded" "$_prompt_bryndin_right_expanded"
(( _prompt_bryndin_filler_width == 17 )) || {
  print -u2 "FAIL: margin not applied (filler=$_prompt_bryndin_filler_width)"; exit 1
}

# Literal prompt-escape lookalikes in dynamic text are visible characters, not
# zero-width escapes.  %%f renders as "%f" (2 columns), and a literal
# %{...%} pair is likewise text rather than a zero-width marker.
COLUMNS=20
_prompt_bryndin_conf[margin]='0'
local measure_case
for measure_case in '%%f:2' '%%B:2' '%%d:2' '%%F{red}:7' '%%{abc%%}:7' '100%%done:8' 'A%{one%}B%{two%}C:3'; do
  local text=${measure_case%:*}
  local expected=${measure_case##*:}
  prompt_bryndin_measure "$text" ''
  local got=$(( 20 - _prompt_bryndin_filler_width ))
  (( got == expected )) || {
    print -u2 "FAIL: width of <$text> is $got, expected $expected"; exit 1
  }
done

# Real prompt escapes are still zero-width or expanded normally.
prompt_bryndin_measure '%F{red}' ''
(( _prompt_bryndin_filler_width == 20 )) || {
  print -u2 "FAIL: colour escape was counted as visible (filler=$_prompt_bryndin_filler_width)"; exit 1
}
prompt_bryndin_measure '%{abc%}' ''
(( _prompt_bryndin_filler_width == 20 )) || {
  print -u2 "FAIL: %{...%} was counted as visible (filler=$_prompt_bryndin_filler_width)"; exit 1
}

# Non-CSI terminal resets (e.g. ESC ( B) are zero-width too.
prompt_bryndin_visible_width $'\e(B'
(( REPLY == 0 )) || {
  print -u2 "FAIL: non-CSI terminal reset counted as $REPLY columns"; exit 1
}

# `%b' can expand through terminfo to a reset containing a non-CSI sequence
# (linux is one such entry).  Measurement must still report zero columns.
local child=$(mktemp /tmp/opencode/bryndin-width.XXXXXX)
cat > "$child" <<EOF
emulate -LR zsh
zmodload -i zsh/zutil
zmodload -i zsh/terminfo
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
source "$theme"
COLUMNS=20
prompt_bryndin_measure '%b' ''
print -r -- "filler=\$_prompt_bryndin_filler_width"
print -r -- "sgr0=\${(V)terminfo[sgr0]}"
EOF
local linux_out=$(TERM=linux zsh "$child" 2>&1)
if [[ $linux_out == *'sgr0='*'^O'* || $linux_out == *'sgr0='*'^[(B'* ]]; then
  [[ $linux_out == *'filler=20'* ]] || {
    print -u2 "FAIL: terminfo reset was counted as visible: $linux_out"; exit 1
  }
else
  print "SKIP: TERM=linux has no non-CSI reset sequence here"
fi

print "PASS: display-column widths and clipping work"

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

print "PASS: display-column widths and clipping work"

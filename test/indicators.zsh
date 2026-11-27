#!/usr/bin/env zsh
#
# Optional second-line indicators must be toggleable through zstyle.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv, VIM and colour overrides out of the prompt.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV VIM NO_COLOR

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

zstyle ':prezto:module:prompt:bryndin' jobs 'yes'
zstyle ':prezto:module:prompt:bryndin' history 'yes'
zstyle ':prezto:module:prompt:bryndin' duration 'yes'
zstyle ':prezto:module:prompt:bryndin' vim 'yes'
zstyle ':prezto:module:prompt:bryndin' overwrite 'yes'
source "$theme"

[[ $RPROMPT == *'%(1j.'* ]] || { print -u2 "FAIL: jobs indicator missing"; exit 1 }
[[ $RPROMPT == *'%!'* ]] || { print -u2 "FAIL: history indicator missing"; exit 1 }
[[ $RPROMPT == *'_prompt_bryndin_duration_text'* ]] || { print -u2 "FAIL: duration missing"; exit 1 }
[[ $RPROMPT == *'${VIM:'* ]] || { print -u2 "FAIL: VIM indicator missing"; exit 1 }
[[ $PROMPT == *'${editor_info[overwrite]}'* ]] || { print -u2 "FAIL: overwrite indicator missing"; exit 1 }

# Verify EPOCHREALTIME is loaded and captured by preexec.
(( $+EPOCHREALTIME )) || {
  print -u2 "FAIL: EPOCHREALTIME was not loaded by setup"; exit 1
}
prompt_bryndin_preexec
[[ $_prompt_bryndin_cmd_start == *.* ]] || {
  print -u2 "FAIL: preexec did not capture float EPOCHREALTIME: '$_prompt_bryndin_cmd_start'"; exit 1
}

# Live EPOCHREALTIME path: < duration-min (default 2s) is hidden, >= 2s shows.
_prompt_bryndin_cmd_start=$(( EPOCHREALTIME - 1.5 ))
_prompt_bryndin_last_status=0
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_duration_text ]] || {
  print -u2 "FAIL: 1.5s duration shown below duration-min=2: '$_prompt_bryndin_duration_text'"; exit 1
}

_prompt_bryndin_cmd_start=$(( EPOCHREALTIME - 5.2 ))
prompt_bryndin_precmd
[[ $_prompt_bryndin_duration_text == ' 5s' ]] || {
  print -u2 "FAIL: duration text: '$_prompt_bryndin_duration_text'"; exit 1
}
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_duration_text ]] || {
  print -u2 "FAIL: duration was not cleared"; exit 1
}

# Float precision boundary and SECONDS == 0 fallback when EPOCHREALTIME is absent.
zmodload -F zsh/datetime -p:EPOCHREALTIME 2>/dev/null
_prompt_bryndin_cmd_start='1.99'
# Simulate 2.01s using SECONDS or direct helper/float fallback:
local -F saved_now=2.01
(( ${EPOCHREALTIME:-0} == 0 )) || { print -u2 "FAIL: EPOCHREALTIME still active"; exit 1 }
SECONDS=0
prompt_bryndin_preexec
[[ $_prompt_bryndin_cmd_start == '0' ]] || {
  print -u2 "FAIL: SECONDS=0 was not recorded: '$_prompt_bryndin_cmd_start'"; exit 1
}
SECONDS=3
prompt_bryndin_precmd
[[ $_prompt_bryndin_duration_text == ' 3s' ]] || {
  print -u2 "FAIL: SECONDS=0 -> 3 duration failed: '$_prompt_bryndin_duration_text'"; exit 1
}

# Float precision boundary via zsh/datetime unloaded + float SECONDS-free check:
# 1.99 -> 2.01 = 0.02s must stay hidden.
function _test_float_boundary {
  local -F SECONDS=1.99
  prompt_bryndin_preexec
  SECONDS=2.01
  prompt_bryndin_precmd
}
_test_float_boundary
[[ -z $_prompt_bryndin_duration_text ]] || {
  print -u2 "FAIL: 0.02s boundary (1.99 -> 2.01) was shown: '$_prompt_bryndin_duration_text'"; exit 1
}

# Duration formatting (Xs, Xm, Xm Ys, Xh, Xh Ym) and custom duration-min.
local d_sec d_exp
for d_sec d_exp in 5 '5s' 120 '2m' 125 '2m 5s' 3600 '1h' 4320 '1h 12m'; do
  prompt_bryndin_format_duration_reply $d_sec
  [[ $REPLY == "$d_exp" ]] || {
    print -u2 "FAIL: format_duration($d_sec) = '$REPLY', expected '$d_exp'"; exit 1
  }
done

zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null
zstyle ':prezto:module:prompt:bryndin' duration-min '5'
prompt_bryndin_setup
_prompt_bryndin_cmd_start=$(( EPOCHREALTIME - 3.5 ))
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_duration_text ]] || {
  print -u2 "FAIL: 3.5s shown when duration-min=5: '$_prompt_bryndin_duration_text'"; exit 1
}
_prompt_bryndin_cmd_start=$(( EPOCHREALTIME - 125.2 ))
prompt_bryndin_precmd
[[ $_prompt_bryndin_duration_text == ' 2m 5s' ]] || {
  print -u2 "FAIL: formatted duration wrong: '$_prompt_bryndin_duration_text'"; exit 1
}

# RPROMPT segments are separated by exactly one space and do not leave a
# trailing gap against the right edge.
zstyle ':prezto:module:prompt:bryndin' duration-min '2'
zstyle ':prezto:module:prompt:bryndin' history 'no'
zstyle ':prezto:module:prompt:bryndin' jobs 'no'
prompt_bryndin_setup
_prompt_bryndin_cmd_start=$(( EPOCHREALTIME - 4.2 ))
_prompt_bryndin_last_status=0
prompt_bryndin_precmd
VIM=1
local rprompt=$(print -P -- "$RPROMPT")
rprompt=${rprompt//$'\e'(\[[0-9;?]#[a-zA-Z]|[()][0-9A-Za-z]|[=>78])/}
rprompt=${rprompt//$'\017'/}
[[ $rprompt == ' 4s V' ]] || {
  print -u2 "FAIL: duration/VIM spacing: <$rprompt>"; exit 1
}
[[ $rprompt != *'  '* ]] || {
  print -u2 "FAIL: double space in RPROMPT: <$rprompt>"; exit 1
}
[[ $rprompt != *' ' ]] || {
  print -u2 "FAIL: trailing space in RPROMPT: <$rprompt>"; exit 1
}
unset VIM

# All off.
zstyle ':prezto:module:prompt:bryndin' jobs 'no'
zstyle ':prezto:module:prompt:bryndin' history 'no'
zstyle ':prezto:module:prompt:bryndin' duration 'no'
zstyle ':prezto:module:prompt:bryndin' vim 'no'
zstyle ':prezto:module:prompt:bryndin' overwrite 'no'
zstyle ':prezto:module:prompt:bryndin' exit-status 'no'
prompt_bryndin_setup
[[ -z $RPROMPT ]] || { print -u2 "FAIL: RPROMPT not empty with all off: $RPROMPT"; exit 1 }
[[ $PROMPT != *'editor_info[overwrite]'* ]] || { print -u2 "FAIL: overwrite not removed"; exit 1 }

print "PASS: optional indicators work"

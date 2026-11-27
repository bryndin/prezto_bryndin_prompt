#!/usr/bin/env zsh
#
# Regression test: when max-block-width already clipped the directory in the
# compressed-PWD fallback, the final overflow clipping must start from that
# clipped text rather than the full path.  Otherwise keep is computed from the
# full width and the header still overflows.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset VIRTUAL_ENV CONDA_DEFAULT_ENV NO_COLOR
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' colors 'none'
zstyle ':prezto:module:prompt:bryndin' compressed-pwd 'full'
zstyle ':prezto:module:prompt:bryndin' max-block-width '20'
zstyle ':prezto:module:prompt:bryndin' blocks 'time' 'host' 'virtualenv' 'git'
zstyle ':prezto:module:prompt:bryndin' host 'always'
zstyle ':prezto:module:prompt:bryndin' time-format '%F{red}1234567890123456789012345%f'
prompt_newline=$'\n%{\r%}'

function git-info { : }
source "$theme"

local deep=$(mktemp -d /tmp/opencode/bryndin-max-width.XXXXXX)
local component='verylongdirectoryname'
mkdir -p "${deep}/$(printf "$component%.0s" {1..4})" || exit 1
cd "$deep/$(printf "$component%.0s" {1..4})" || exit 1

COLUMNS=30
prompt_bryndin_precmd

local width_of() {
  local rendered=$(print -P -- "$1")
  rendered=${rendered//$'\e'\[[0-9;]#m/}
  print -r -- ${(m)#rendered}
}

# The directory block must respect max-block-width and the rendered header
# must still fit the terminal.
local dir_width=$(width_of "$_prompt_bryndin_cur_dir")
(( dir_width <= 20 )) || {
  print -u2 "FAIL: directory block is $dir_width columns, max-block-width is 20"; exit 1
}
local header_width=$(width_of "$_prompt_bryndin_header")
(( header_width <= 30 )) || {
  print -u2 "FAIL: header is $header_width columns at COLUMNS=30"; exit 1
}

# Wider terminal: max-block-width still caps long full %~ paths, while short
# paths keep %~ and disabling max-block-width restores %~.
COLUMNS=200
prompt_bryndin_prepare_pwd
prompt_bryndin_reflow
dir_width=$(width_of "$_prompt_bryndin_cur_dir")
(( dir_width == 20 )) || {
  print -u2 "FAIL: full %~ was not clipped to max-block-width=20: $dir_width ($_prompt_bryndin_cur_dir)"; exit 1
}

# Time block with %F{...} escapes is clipped to 20 visible columns cleanly.
local time_width=$(width_of "$_prompt_bryndin_time")
(( time_width == 20 )) || {
  print -u2 "FAIL: time block not clipped to 20 columns: $time_width ($_prompt_bryndin_time)"; exit 1
}
[[ $_prompt_bryndin_time == *… ]] || {
  print -u2 "FAIL: clipped time block missing ellipsis: $_prompt_bryndin_time"; exit 1
}

# Virtualenv clipped to max-block-width.
VIRTUAL_ENV='/tmp/very-long-virtualenv-name-exceeding-limit'
prompt_bryndin_virtualenv_reply
local venv_plain=${REPLY#─<}
venv_plain=${venv_plain%>}
(( ${(m)#venv_plain} == 20 )) || {
  print -u2 "FAIL: virtualenv not clipped to 20 columns: $venv_plain (${(m)#venv_plain})"; exit 1
}
unset VIRTUAL_ENV

# Host block clipped to max-block-width (user@host is at least 3 chars, so 2 always clips).
zstyle ':prezto:module:prompt:bryndin' max-block-width '2'
prompt_bryndin_load_config
prompt_bryndin_build_host_block_reply
local host_w=$(width_of "$REPLY")
# `─(` + 2 + `)` = 5 columns
(( host_w == 5 )) || {
  print -u2 "FAIL: host block not clipped to max-block-width=2: $REPLY (width $host_w)"; exit 1
}

# Git ref with %, quotes, and CJK characters clipped safely to max-block-width=10.
zstyle ':prezto:module:prompt:bryndin' max-block-width '10'
prompt_bryndin_load_config
git_info=(
  bryndin-git-prefix '─(git'
  bryndin-git-suffix ')'
  bryndin-branch 'feat%\"日本語branch-long'
)
prompt_bryndin_git_reply
local git_w=$(width_of "$REPLY")
# `─(git:` (6) + <=10 + `)` (1) = <= 17
(( git_w <= 17 )) || {
  print -u2 "FAIL: git block exceeded max-block-width=10: $REPLY (width $git_w)"; exit 1
}
local git_rendered=$(print -P -- "$REPLY")
[[ $git_rendered == *'feat%"'* && $git_rendered == *'…)' ]] || {
  print -u2 "FAIL: git ref clipped improperly: $git_rendered"; exit 1
}

# With max-block-width=0, widening restores %~.
zstyle ':prezto:module:prompt:bryndin' max-block-width '0'
prompt_bryndin_setup
COLUMNS=30
prompt_bryndin_precmd
COLUMNS=200
prompt_bryndin_prepare_pwd
prompt_bryndin_reflow
[[ $_prompt_bryndin_cur_dir == '%~' ]] || {
  print -u2 "FAIL: wide terminal did not restore %~ with max-block-width=0: $_prompt_bryndin_cur_dir"; exit 1
}

print "PASS: max-block-width and overflow clipping cooperate"

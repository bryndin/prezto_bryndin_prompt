#!/usr/bin/env zsh
#
# Even on a very narrow terminal the header must not exceed COLUMNS: the
# directory block is clipped after the compressed-PWD fallback, and whole
# header blocks are dropped if it still does not fit.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

unset NO_COLOR CONDA_DEFAULT_ENV
local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }
function python-info { python_info=(virtualenv '') }
typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' colors 'none'
zstyle ':prezto:module:prompt:bryndin' time-format '12:34:56'
zstyle ':prezto:module:prompt:bryndin' compressed-pwd 'full'
prompt_newline=$'\n%{\r%}'

function git-info {
  git_info=(
    bryndin-git-prefix '─(git'
    bryndin-git-suffix ')'
    bryndin-branch 'main'
  )
}

# Pin the virtualenv name so the test does not depend on the caller's
# environment (direnv, for example, may set VIRTUAL_ENV).
VIRTUAL_ENV='/tmp/bryndin-test-virtualenv'

source "$theme"

local width_of() {
  local s=$1
  local zero='%([BSUbfksu]|([FBK]|){*})'
  print -r -- ${(m)#${(S%%)s//$~zero/}}
}

local deep=$(mktemp -d /tmp/opencode/bryndin-overflow.XXXXXX)
mkdir -p "$deep/project/subdir"
cd "$deep/project/subdir"

local cols
for cols in 10 20 30 40 60 80; do
  COLUMNS=$cols
  prompt_bryndin_precmd
  local w=$(width_of "$_prompt_bryndin_header")
  (( w <= cols )) || {
    print -u2 "FAIL: header is $w columns wide at COLUMNS=$cols"; exit 1
  }
done

# Wide enough for everything: all blocks are present.
COLUMNS=140
prompt_bryndin_precmd
[[ $_prompt_bryndin_header == *'12:34:56'* && $_prompt_bryndin_header == *'bryndin-test-virtualenv'* && $_prompt_bryndin_header == *'git:main'* ]] || {
  print -u2 "FAIL: blocks missing on wide terminal: $_prompt_bryndin_header"; exit 1
}

# Narrow terminal overflow priority: time drops first, keeping git/virtualenv,
# and pwd re-expands past the 15-column floor into freed space (not left at `…`).
# Calculate a width where compressed-pwd (~35 cols) + git (11) + venv (26) fits
# once time (11) + host (~8) are dropped, without crushing pwd to `[…]`.
COLUMNS=68
prompt_bryndin_precmd
[[ $_prompt_bryndin_header != *'12:34:56'* ]] || {
  print -u2 "FAIL: time block was not dropped first: $_prompt_bryndin_header"; exit 1
}
[[ $_prompt_bryndin_header == *'git:main'* ]] || {
  print -u2 "FAIL: git block was dropped prematurely: $_prompt_bryndin_header"; exit 1
}
# With 15-column floor protection, dropping time/host frees space so pwd is not crushed to `[…]`.
[[ $_prompt_bryndin_cur_dir != '…' ]] || {
  print -u2 "FAIL: directory crushed to ellipsis prematurely"; exit 1
}

# Explicit check of drop order: time -> host -> virtualenv -> git.
local pdir=$(mktemp -d /tmp/opencode/bryndin-drop.XXXXXX)
mkdir -p "$pdir/123456789012345"
cd "$pdir/123456789012345"
_prompt_bryndin_conf[compressed-pwd]='tilde'
zstyle ':prezto:module:prompt:bryndin' host 'never'
prompt_bryndin_setup
# right = `[` + `/tmp/opencode/...` (~40 chars); set a synthetic short compressed-pwd path via HOME.
local saved_home=$HOME
HOME=$pdir
# Now %~ is `~/123456789012345` (17 cols), right is `[~/123456789012345]─` (20 cols).
# time=11 (`─(12:34:56)`), host=4..15 (`─($USER)`), venv=26 (`─<bryndin-test-virtualenv>`), git=11 (`─(git:main)`).
COLUMNS=56
prompt_bryndin_precmd
# With COLUMNS=56 and right=20, budget for left is 36. git(11)+venv(26)=37 > 36, wait:
# drop time -> host+venv+git; drop host -> venv+git=37 > 36 -> drop venv -> git(11)+right(20)=31 <= 56.
[[ $_prompt_bryndin_header == *'git:main'* && $_prompt_bryndin_header != *'12:34:56'* ]] || {
  print -u2 "FAIL: default drop-order did not preserve git: $_prompt_bryndin_header"; exit 1
}

# Custom drop-order: drop git first, keep time.
zstyle ':prezto:module:prompt:bryndin' drop-order 'git' 'virtualenv' 'host' 'time'
prompt_bryndin_setup
COLUMNS=56
prompt_bryndin_precmd
[[ $_prompt_bryndin_header == *'12:34:56'* && $_prompt_bryndin_header != *'git:main'* ]] || {
  print -u2 "FAIL: custom drop-order was not respected: $_prompt_bryndin_header"; exit 1
}
HOME=$saved_home

# Very narrow: all blocks dropped rather than overflowing, and pwd re-expands to fit.
COLUMNS=20
prompt_bryndin_precmd
[[ $_prompt_bryndin_header != *'bryndin-test-virtualenv'* && $_prompt_bryndin_header != *'git:main'* ]] || {
  print -u2 "FAIL: blocks not dropped at COLUMNS=20: $_prompt_bryndin_header"; exit 1
}
local w20=$(width_of "$_prompt_bryndin_header")
(( w20 == 20 )) || {
  print -u2 "FAIL: pwd did not re-expand to fill COLUMNS=20 (got $w20): $_prompt_bryndin_header"; exit 1
}

print "PASS: header never overflows on narrow terminals"

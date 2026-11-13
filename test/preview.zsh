#!/usr/bin/env zsh
#
# `prompt -p bryndin' must call editor-info after setup.  Otherwise the keymap
# indicator is rendered with the previous theme's formats.
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
git_info=(); python_info=(); editor_info=(keymap '' overwrite '')
zstyle ':prezto:module:prompt:bryndin' async 'no'
zstyle ':prezto:module:prompt:bryndin' keymap-indicator 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

# A stand-in for Prezto's editor-info: it copies whatever keymap format is
# currently configured.  Before the fix, preview called this before setup and
# captured the previous theme's value.
function editor-info {
  emulate -L zsh
  local fmt
  zstyle -s ':prezto:module:editor:info:keymap:primary' format fmt
  editor_info=(keymap "$fmt" overwrite '')
}

# Populate the raw git keys so preview can render a synchronous git block.
function git-info {
  emulate -L zsh
  local -A formats
  local key fmt
  git_info=()
  zstyle -a ':prezto:module:git:info:keys' format formats
  for key fmt in "${(@kv)formats}"; do
    zformat -f REPLY "$fmt" \
      "b:main" "p:" "c:" "s:" "A:" "B:" "S:" "a:" "d:" "m:" "r:" "U:" "u:"
    git_info[$key]=$REPLY
  done
}

# Pretend another theme left its keymap format in place.
zstyle ':prezto:module:editor:info:keymap:primary' format 'OLD-THEME'

# Minimal promptinit stand-in.  The built-in preview helper calls setup, then
# precmd, then prints the prompt; it does not call editor-info itself.
function prompt_preview_theme {
  emulate -L zsh
  local -a prompt_opts
  print -n "$1 theme:"
  prompt_${1}_setup
  prompt_bryndin_precmd
  print -P -- "${PS1}command arg1 arg2 ... argn"
}

COLUMNS=120
local output=$(prompt_bryndin_preview 2>&1)

[[ $output == *'bryndin theme'* ]] || {
  print -u2 "FAIL: preview did not identify the theme: $output"; exit 1
}
local visible=${output//$'\e'\[[0-9;]#m/}
[[ $visible == *'❯❯❯'* ]] || {
  print -u2 "FAIL: preview used the previous editor format: $output"; exit 1
}
[[ $output != *'OLD-THEME'* ]] || {
  print -u2 "FAIL: previous theme's keymap indicator leaked into preview: $output"; exit 1
}

# Preview with async enabled must not spawn a worker (it would die with the
# preview subshell) and must still render git status synchronously.
local async_dir=$(mktemp -d /tmp/opencode/bryndin-preview-async.XXXXXX)
cat > "$async_dir/async" <<'ASYNC'
function async_start_worker { print -r -- started >> "$PREVIEW_MARKER"; return 0 }
function async_register_callback { : }
function async_flush_jobs { : }
function async_job { print -r -- job >> "$PREVIEW_MARKER"; return 0 }
function async { : }
function zpty { return 0 }
async "$@"
ASYNC
fpath=( "$async_dir" $fpath )
zstyle ':prezto:module:prompt:bryndin' async 'yes'
local marker=$(mktemp /tmp/opencode/bryndin-preview-marker.XXXXXX)
export PREVIEW_MARKER=$marker
COLUMNS=120
local async_output=$(prompt_bryndin_preview 2>&1)
unset PREVIEW_MARKER
[[ ! -s $marker ]] || {
  print -u2 "FAIL: preview spawned an async worker: $(<$marker)"; exit 1
}
[[ ${async_output//$'\e'\[[0-9;]#m/} == *'git:main'* ]] || {
  print -u2 "FAIL: preview omitted synchronous git status: $async_output"; exit 1
}

# Backslashes in the displayed path must survive the preview's print call.
zstyle ':prezto:module:prompt:bryndin' async 'no'
local bsdir=$(mktemp -d /tmp/opencode/bryndin-preview-bs.XXXXXX)
mkdir -p "$bsdir/lit\\nname" || exit 1
cd "$bsdir/lit\\nname" || exit 1
COLUMNS=200
local bs_output=$(prompt_bryndin_preview 2>&1)
[[ $bs_output == *'lit\nname'* ]] || {
  print -u2 "FAIL: preview interpreted a backslash escape in the path: $bs_output"; exit 1
}

print "PASS: preview initialises the editor indicator after setup"

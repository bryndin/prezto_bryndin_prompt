#!/usr/bin/env zsh
#
# Async git status: worker startup, job dispatch and callback redraw.
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

# A fake zsh-async that records what the theme asks it to do.
local helper_dir=$(mktemp -d /tmp/opencode/bryndin-async.XXXXXX)
cat > "$helper_dir/async" <<'EOF'
function async_start_worker { typeset -g ASYNC_TEST_STARTED=1 }
function async_register_callback { typeset -g ASYNC_TEST_CALLBACK=$2 }
function async_flush_jobs { : }
function async_job { typeset -g ASYNC_TEST_JOB=$2 }
function async { : }
async "$@"
EOF
fpath=( "$helper_dir" $fpath )

zstyle ':prezto:module:prompt:bryndin' async 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

(( _prompt_bryndin_async == 1 )) || {
  print -u2 "FAIL: async mode was not enabled"; exit 1
}
(( ${ASYNC_TEST_STARTED:-0} == 1 )) || {
  print -u2 "FAIL: worker was not started"; exit 1
}
[[ $ASYNC_TEST_CALLBACK == prompt_bryndin_async_callback ]] || {
  print -u2 "FAIL: callback not registered"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd
[[ $ASYNC_TEST_JOB == prompt_bryndin_async_git ]] || {
  print -u2 "FAIL: git job was not dispatched"; exit 1
}

prompt_bryndin_async_callback prompt_bryndin_async_git 0 'GITBLOCK'
[[ $_prompt_bryndin_git == GITBLOCK ]] || {
  print -u2 "FAIL: callback did not store the git block"; exit 1
}
[[ $_prompt_bryndin_header == *GITBLOCK* ]] || {
  print -u2 "FAIL: callback did not rebuild the header"; exit 1
}

print "PASS: async git status works"

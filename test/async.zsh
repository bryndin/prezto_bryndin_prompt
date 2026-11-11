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
function async_start_worker {
  typeset -g ASYNC_TEST_STARTED=1
  # The worker inherits the zstyle database at fork time; git-info formats must
  # already be configured or it renders an empty block.
  zstyle -s ':prezto:module:git:info:branch' format ASYNC_TEST_BRANCH_AT_START
}
function async_register_callback { typeset -g ASYNC_TEST_CALLBACK=$2 }
function async_flush_jobs { typeset -g ASYNC_TEST_FLUSH=$1 }
function async_job { typeset -g ASYNC_TEST_JOB=$2 }
function async { : }
function zpty { return 0 }
async "$@"
EOF
fpath=( "$helper_dir" $fpath )

zstyle ':prezto:module:prompt:bryndin' async 'yes'
prompt_newline=$'\n%{\r%}'
source "$theme"

(( _prompt_bryndin_async == 1 )) || {
  print -u2 "FAIL: async mode was not enabled"; exit 1
}
[[ -n $ASYNC_TEST_BRANCH_AT_START ]] || {
  print -u2 "FAIL: worker started before git-info zstyles were configured"; exit 1
}
(( ${ASYNC_TEST_STARTED:-0} == 1 )) || {
  print -u2 "FAIL: worker was not started"; exit 1
}
[[ $ASYNC_TEST_CALLBACK == prompt_bryndin_async_callback ]] || {
  print -u2 "FAIL: callback not registered"; exit 1
}

COLUMNS=80
prompt_bryndin_precmd
[[ $ASYNC_TEST_FLUSH == prompt_bryndin ]] || {
  print -u2 "FAIL: pending git jobs were not flushed"; exit 1
}
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

# Changing directories must drop the previous repository's block immediately;
# the worker fills in the new one asynchronously.
_prompt_bryndin_git='OLDGIT'
_prompt_bryndin_last_pwd="$PWD/old"
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_git ]] || {
  print -u2 "FAIL: stale git block survived a directory change: $_prompt_bryndin_git"; exit 1
}
[[ $_prompt_bryndin_header != *OLDGIT* ]] || {
  print -u2 "FAIL: stale git block still in the header"; exit 1
}
[[ $_prompt_bryndin_last_pwd == $PWD ]] || {
  print -u2 "FAIL: last PWD was not updated"; exit 1
}

print "PASS: async git status works"

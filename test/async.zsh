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

# Same repository: keep the block so `cd src` does not flicker.
if command -v git >/dev/null 2>&1; then
  local repo=$(mktemp -d /tmp/opencode/bryndin-async-repo.XXXXXX)
  git -C "$repo" init -q
  local root=$(command git -C "$repo" rev-parse --show-toplevel)
  cd "$repo"

  _prompt_bryndin_git='GITBLOCK'
  _prompt_bryndin_git_root="$root"
  _prompt_bryndin_last_pwd="$repo/old"
  COLUMNS=200
  prompt_bryndin_precmd
  [[ $_prompt_bryndin_git == 'GITBLOCK' ]] || {
    print -u2 "FAIL: same-repository cd cleared the git block"; exit 1
  }
  [[ $_prompt_bryndin_git_root == "$root" ]] || {
    print -u2 "FAIL: repository root was not tracked"; exit 1
  }

  # Leaving the repository: clear the block immediately.
  local nonrepo=$(mktemp -d /tmp/opencode/bryndin-async-nonrepo.XXXXXX)
  cd "$nonrepo"
  _prompt_bryndin_git='GITBLOCK'
  _prompt_bryndin_last_pwd="$repo"
  prompt_bryndin_precmd
  [[ -z $_prompt_bryndin_git ]] || {
    print -u2 "FAIL: stale git block survived leaving the repository: $_prompt_bryndin_git"; exit 1
  }
else
  print "SKIP: git not found; root-tracking checks skipped"
fi

# A longer git block must compress the directory instead of making the header
# overflow and dropping the git block in reflow.
COLUMNS=40
_prompt_bryndin_cur_dir='%~'
_prompt_bryndin_git=''
prompt_bryndin_async_callback prompt_bryndin_async_git 0 \
  '%F{blue}git:feature/user-auth-refactor%f'
[[ $_prompt_bryndin_cur_dir != '%~' ]] || {
  print -u2 "FAIL: async callback did not refit the directory"; exit 1
}
local zero='%([BSUbfksu]|([FBK]|){*})'
local width=${#${(S%%)_prompt_bryndin_header//$~zero/}}
(( width <= 40 )) || {
  print -u2 "FAIL: async callback header overflows: $width > 40"; exit 1
}

print "PASS: async git status works"

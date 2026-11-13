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
function async_stop_worker { typeset -g ASYNC_TEST_STOPPED=$1 }

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
function async_job {
  typeset -g ASYNC_TEST_JOB=$2
  (( ${ASYNC_TEST_FAIL:-0} )) && return 1
  return 0
}
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

# A result for another directory must not overwrite the current block.
_prompt_bryndin_git='CURRENT'
_prompt_bryndin_async_pwd='/somewhere/else'
prompt_bryndin_async_callback prompt_bryndin_async_git 0 'STALE'
[[ $_prompt_bryndin_git == CURRENT ]] || {
  print -u2 "FAIL: stale async result replaced the current block: $_prompt_bryndin_git"; exit 1
}
_prompt_bryndin_async_pwd=$PWD
prompt_bryndin_async_callback prompt_bryndin_async_git 0 'FRESH'
[[ $_prompt_bryndin_git == FRESH ]] || {
  print -u2 "FAIL: current-directory result was rejected"; exit 1
}

# A job that was already running when the directory changed tags its own
# directory in the output; a mismatched tag must be rejected even though the
# global dispatch directory now matches $PWD.
_prompt_bryndin_git='CURRENT'
_prompt_bryndin_async_pwd=$PWD
prompt_bryndin_async_callback prompt_bryndin_async_git 0 "/old/repoA"$'\001STALE'
[[ $_prompt_bryndin_git == CURRENT ]] || {
  print -u2 "FAIL: in-flight job from another directory was accepted: $_prompt_bryndin_git"; exit 1
}
prompt_bryndin_async_callback prompt_bryndin_async_git 0 "$PWD"$'\001FRESH-TAGGED'
[[ $_prompt_bryndin_git == FRESH-TAGGED ]] || {
  print -u2 "FAIL: correctly tagged job was rejected"; exit 1
}

# The worker itself must emit the directory tag and the rendered block.
function git-info {
  git_info=(
    bryndin-git-prefix 'PREFIX'
    bryndin-git-suffix 'SUFFIX'
    bryndin-branch 'main'
  )
}
local worker_output=$(prompt_bryndin_async_git "$PWD")
unfunction git-info
[[ $worker_output == "$PWD"$'\001'* ]] || {
  print -u2 "FAIL: async worker did not tag its output: $worker_output"; exit 1
}
[[ $worker_output == *':%F{green}main%f'* ]] || {
  print -u2 "FAIL: async worker did not render the git block: $worker_output"; exit 1
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

  # A cd inside a known repository must not spawn git rev-parse in precmd.
  local fakebin=$(mktemp -d /tmp/opencode/bryndin-fakegit.XXXXXX)
  local git_log="$fakebin/called"
  cat > "$fakebin/git" <<'GIT'
#!/bin/sh
echo called >> "$GIT_CALL_LOG"
exit 1
GIT
  chmod +x "$fakebin/git"
  local old_path=$PATH
  export GIT_CALL_LOG="$git_log"
  PATH="$fakebin:$PATH"
  _prompt_bryndin_last_pwd="$repo/other"
  COLUMNS=200
  prompt_bryndin_precmd
  PATH=$old_path
  [[ ! -e $git_log ]] || {
    print -u2 "FAIL: same-repository cd still spawned git rev-parse"; exit 1
  }

  # A repository at "/" must contain every absolute path, including the
  # literal root itself.  The `(|/*)` form used to miss this case.
  local saved_root=$_prompt_bryndin_git_root
  local saved_last=$_prompt_bryndin_last_pwd
  local saved_pwd=$PWD
  cd /tmp
  _prompt_bryndin_git_root='/'
  _prompt_bryndin_last_pwd='/old'
  rm -f "$git_log"
  PATH="$fakebin:$PATH"
  prompt_bryndin_precmd
  PATH=$old_path
  [[ ! -e $git_log ]] || {
    print -u2 "FAIL: repository root / was not treated as containing /tmp"; exit 1
  }
  _prompt_bryndin_git_root=$saved_root
  _prompt_bryndin_last_pwd=$saved_last
  cd "$saved_pwd"

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

# async_job failure: disable async and clean up the worker immediately.
ASYNC_TEST_FAIL=1
ASYNC_TEST_STOPPED=''
_prompt_bryndin_async=1
COLUMNS=80
prompt_bryndin_precmd
ASYNC_TEST_FAIL=0
(( _prompt_bryndin_async == 0 )) || {
  print -u2 "FAIL: async mode stayed enabled after async_job failed"; exit 1
}
[[ $ASYNC_TEST_STOPPED == prompt_bryndin ]] || {
  print -u2 "FAIL: failed async worker was not stopped"; exit 1
}

# Worker failure: stop using async and clean up the dead zpty.
ASYNC_TEST_STOPPED=''
_prompt_bryndin_async=1
prompt_bryndin_async_callback '[async]' 2 '' 0 'worker died' 0
(( _prompt_bryndin_async == 0 )) || {
  print -u2 "FAIL: async mode stayed enabled after a worker failure"; exit 1
}
[[ $ASYNC_TEST_STOPPED == prompt_bryndin ]] || {
  print -u2 "FAIL: dead async worker was not stopped"; exit 1
}

# Sync mode: a failing git-info must clear the block even if it leaves stale
# values in git_info, or the previous repository's branch survives.
function git-info {
  git_info=(
    bryndin-git-prefix 'PREFIX'
    bryndin-git-suffix 'SUFFIX'
    bryndin-branch 'stale-branch'
  )
  return 1
}
_prompt_bryndin_async=0
_prompt_bryndin_git='STALE'
COLUMNS=80
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_git ]] || {
  print -u2 "FAIL: failing git-info reused stale data: $_prompt_bryndin_git"; exit 1
}

# The same must hold when git-info is unavailable entirely.
unfunction git-info
_prompt_bryndin_git='STALE'
prompt_bryndin_precmd
[[ -z $_prompt_bryndin_git ]] || {
  print -u2 "FAIL: missing git-info reused stale data: $_prompt_bryndin_git"; exit 1
}

print "PASS: async git status works"

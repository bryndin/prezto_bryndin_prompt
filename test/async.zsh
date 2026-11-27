#!/usr/bin/env zsh
#
# Async git status: worker startup, job dispatch and callback redraw.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

# Keep the caller's virtualenv and colour overrides out of the header.
unset VIRTUAL_ENV CONDA_DEFAULT_ENV NO_COLOR

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
function zpty {
  (( ${ASYNC_TEST_ZPTY_FAIL:-0} )) && return 1
  return 0
}
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

prompt_bryndin_async_callback prompt_bryndin_async_git 0 "$PWD"$'\001GITBLOCK'
[[ $_prompt_bryndin_git == GITBLOCK ]] || {
  print -u2 "FAIL: callback did not store the git block"; exit 1
}
[[ $_prompt_bryndin_header == *GITBLOCK* ]] || {
  print -u2 "FAIL: callback did not rebuild the header"; exit 1
}

# Untagged output must be ignored even when $PWD matches.
_prompt_bryndin_git='CURRENT'
prompt_bryndin_async_callback prompt_bryndin_async_git 0 'UNTAGGED'
[[ $_prompt_bryndin_git == CURRENT ]] || {
  print -u2 "FAIL: untagged async result was accepted: $_prompt_bryndin_git"; exit 1
}

# A result tagged with another directory must not overwrite the current block.
prompt_bryndin_async_callback prompt_bryndin_async_git 0 "/old/repoA"$'\001STALE'
[[ $_prompt_bryndin_git == CURRENT ]] || {
  print -u2 "FAIL: in-flight job from another directory was accepted: $_prompt_bryndin_git"; exit 1
}
prompt_bryndin_async_callback prompt_bryndin_async_git 0 "$PWD"$'\001FRESH-TAGGED'
[[ $_prompt_bryndin_git == FRESH-TAGGED ]] || {
  print -u2 "FAIL: correctly tagged job was rejected"; exit 1
}

# The worker itself must emit the directory tag, set GIT_OPTIONAL_LOCKS=0, and render.
local locks_file=$(mktemp /tmp/opencode/bryndin-locks.XXXXXX)
function git-info {
  print -r -- "${GIT_OPTIONAL_LOCKS:-}" > "$locks_file"
  git_info=(
    bryndin-git-prefix 'PREFIX'
    bryndin-git-suffix 'SUFFIX'
    bryndin-branch 'main'
  )
}
local worker_output=$(prompt_bryndin_async_git "$PWD")
unfunction git-info
local seen_locks=$(<"$locks_file")
rm -f "$locks_file"
[[ $seen_locks == '0' ]] || {
  print -u2 "FAIL: async worker did not set GIT_OPTIONAL_LOCKS=0: '$seen_locks'"; exit 1
}
[[ $worker_output == "$PWD"$'\001'* ]] || {
  print -u2 "FAIL: async worker did not tag its output: $worker_output"; exit 1
}
[[ $worker_output == *':%F{green}main%f'* ]] || {
  print -u2 "FAIL: async worker did not render the git block: $worker_output"; exit 1
}

# Failed cd or failed git-info must still emit the directory tag with empty body
# so stale output from an earlier directory never races a later cd.
function git-info { return 1 }
local failed_output=$(prompt_bryndin_async_git "$PWD")
[[ $failed_output == "$PWD"$'\001' ]] || {
  print -u2 "FAIL: failed git-info did not emit empty tagged output: ${(V)failed_output}"; exit 1
}
unfunction git-info
local missing_dir='/tmp/opencode/nonexistent-bryndin-dir-999999'
local badcd_output=$(prompt_bryndin_async_git "$missing_dir")
[[ $badcd_output == "$missing_dir"$'\001' ]] || {
  print -u2 "FAIL: failed cd did not emit empty tagged output: ${(V)badcd_output}"; exit 1
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

  # A repository at "/" must contain /tmp if /.git exists, and must invalidate
  # when /.git does not exist.
  local saved_root=$_prompt_bryndin_git_root
  local saved_last=$_prompt_bryndin_last_pwd
  local saved_pwd=$PWD
  cd /tmp
  _prompt_bryndin_git_root='/'
  _prompt_bryndin_last_pwd='/old'
  rm -f "$git_log"
  if [[ -e /.git ]]; then
    PATH="$fakebin:$PATH"
    prompt_bryndin_precmd
    PATH=$old_path
    [[ ! -e $git_log ]] || {
      print -u2 "FAIL: repository root / was not treated as containing /tmp"; exit 1
    }
  else
    if prompt_bryndin_in_cached_repo; then
      print -u2 "FAIL: root / without /.git was treated as a cached repo"; exit 1
    fi
  fi
  _prompt_bryndin_git_root=$saved_root
  _prompt_bryndin_last_pwd=$saved_last
  cd "$saved_pwd"

  # in_cached_repo must invalidate on .git/, nested submodule .git (dir & file),
  # and deleted .git.
  mkdir -p "$repo/sub/dir" "$repo/nested_dir/.git" "$repo/nested_file"
  print -r -- 'gitdir: ../.git/modules/nested_file' > "$repo/nested_file/.git"
  _prompt_bryndin_git_root="$root"
  cd "$repo/sub/dir"
  prompt_bryndin_in_cached_repo || {
    print -u2 "FAIL: valid subdir inside repo failed in_cached_repo"; exit 1
  }
  cd "$repo/.git"
  ! prompt_bryndin_in_cached_repo || {
    print -u2 "FAIL: .git directory was treated as inside cached repo"; exit 1
  }
  cd "$repo/nested_dir"
  ! prompt_bryndin_in_cached_repo || {
    print -u2 "FAIL: nested .git directory was treated as inside cached repo"; exit 1
  }
  cd "$repo/nested_file"
  ! prompt_bryndin_in_cached_repo || {
    print -u2 "FAIL: nested submodule .git file was treated as inside cached repo"; exit 1
  }
  cd "$repo/sub"
  mv "$repo/.git" "$repo/.git.bak"
  ! prompt_bryndin_in_cached_repo || {
    print -u2 "FAIL: deleted .git still matched cached repo"; exit 1
  }
  mv "$repo/.git.bak" "$repo/.git"
  cd "$repo"

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
  "$PWD"$'\001%F{blue}git:feature/user-auth-refactor%f'
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

# Sync mode: set GIT_OPTIONAL_LOCKS=0 and clear stale data if git-info fails.
typeset -g SYNC_SEEN_LOCKS=''
function git-info {
  SYNC_SEEN_LOCKS=${GIT_OPTIONAL_LOCKS:-}
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
[[ $SYNC_SEEN_LOCKS == '0' ]] || {
  print -u2 "FAIL: sync git-info did not receive GIT_OPTIONAL_LOCKS=0: '$SYNC_SEEN_LOCKS'"; exit 1
}
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

# A worker that disappeared between prompts must be stopped, not just ignored:
# async_stop_worker detaches zsh-async's fd watcher and callback.
ASYNC_TEST_ZPTY_FAIL=1
ASYNC_TEST_STOPPED=''
_prompt_bryndin_async=1
_prompt_bryndin_last_pwd=$PWD
COLUMNS=80
prompt_bryndin_precmd
ASYNC_TEST_ZPTY_FAIL=0
(( _prompt_bryndin_async == 0 )) || {
  print -u2 "FAIL: async mode stayed enabled after the worker disappeared"; exit 1
}
[[ $ASYNC_TEST_STOPPED == prompt_bryndin ]] || {
  print -u2 "FAIL: dead worker was not stopped before synchronous fallback"; exit 1
}

# Skipping git work and async worker startup when git is omitted from blocks or
# single-line=yes.
local git_calls=0
function git-info { (( git_calls++ )); return 0 }
ASYNC_TEST_STARTED=0
ASYNC_TEST_JOB=''
zstyle ':prezto:module:prompt:bryndin' async 'yes'
zstyle ':prezto:module:prompt:bryndin' blocks 'time' 'host'
prompt_bryndin_setup
(( _prompt_bryndin_async == 0 && ASYNC_TEST_STARTED == 0 )) || {
  print -u2 "FAIL: async worker started when git was absent from blocks"; exit 1
}
prompt_bryndin_precmd
(( git_calls == 0 )) || {
  print -u2 "FAIL: git-info called when git was absent from blocks"; exit 1
}

zstyle ':prezto:module:prompt:bryndin' blocks 'time' 'git'
zstyle ':prezto:module:prompt:bryndin' single-line 'yes'
prompt_bryndin_setup
(( _prompt_bryndin_async == 0 && ASYNC_TEST_STARTED == 0 )) || {
  print -u2 "FAIL: async worker started in single-line mode"; exit 1
}
prompt_bryndin_precmd
(( git_calls == 0 )) || {
  print -u2 "FAIL: git-info called in single-line mode"; exit 1
}

print "PASS: async git status works"

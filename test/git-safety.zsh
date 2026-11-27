#!/usr/bin/env zsh
#
# Regression test: git ref names are untrusted prompt text.  They may contain
# quotes (which used to break a `$(coalesce "%b" ...)' expression), dollars,
# backticks and percent signs.  The theme must render them literally without
# evaluating them or aborting precmd.
#
emulate -LR zsh
zmodload -i zsh/zutil
setopt EXTENDED_GLOB PROMPT_SUBST PROMPT_PERCENT MULTIBYTE

local theme=${1:-${0:A:h:h}/prompt_bryndin_setup}
function pmodload { : }
function add-zsh-hook { : }
function add-zle-hook-widget { : }

# Prezto's helper module function, reproduced so the test exercises the same
# escaping git-info applies before formatting a branch.
function escape-eval {
  emulate -L zsh
  setopt EXTENDED_GLOB
  print -r -- "${1//(#m)[\\\$\`]/\\$MATCH}"
}

typeset -gA git_info python_info editor_info
git_info=(); python_info=(); editor_info=(keymap '❯')
typeset -g TEST_BRANCH='' TEST_POSITION='' TEST_COMMIT=''

function git-info {
  emulate -L zsh
  local branch=${TEST_BRANCH}
  local position=${TEST_POSITION}
  local commit=${TEST_COMMIT}
  local branch_formatted='' position_formatted='' commit_formatted=''
  local fmt
  git_info=()

  if [[ -n $branch ]]; then
    zstyle -s ':prezto:module:git:info:branch' format fmt
    zformat -f branch_formatted "$fmt" "b:$(escape-eval "$branch")"
  fi
  if [[ -n $position ]]; then
    zstyle -s ':prezto:module:git:info:position' format fmt
    zformat -f position_formatted "$fmt" "p:$(escape-eval "$position")"
  fi
  if [[ -n $commit ]]; then
    zstyle -s ':prezto:module:git:info:commit' format fmt
    zformat -f commit_formatted "$fmt" "c:$(escape-eval "$commit")"
  fi

  local -A info_formats
  local key
  zstyle -a ':prezto:module:git:info:keys' format info_formats
  for key fmt in "${(@kv)info_formats}"; do
    zformat -f REPLY "$fmt" \
      "b:$branch_formatted" "p:$position_formatted" "c:$commit_formatted" \
      "s:" "A:" "B:" "S:" "a:" "d:" "m:" "r:" "U:" "u:"
    git_info[$key]=$REPLY
  done
}

zstyle ':prezto:module:prompt:bryndin' async 'no'
prompt_newline=$'\n%{\r%}'
source "$theme"

function fail {
  print -u2 "FAIL: $*"
  exit 1
}

# The unsafe deferred-eval expression must be gone.
local -a literals
zstyle -a ':prezto:module:git:info:keys' format literals
[[ ${(pj:\n:)literals} != *'$(coalesce'* ]] || \
  fail "git keys still defer a command substitution"
[[ ${(pj:\n:)literals} == *'bryndin-branch'* ]] || \
  fail "raw branch key is not requested"

function render_git {
  COLUMNS=200
  _prompt_bryndin_last_status=0
  prompt_bryndin_precmd || fail "precmd failed for branch <$TEST_BRANCH>"
}

# A double quote is legal in a ref and used to make the old format a parse
# error.  It must reach the prompt verbatim.
TEST_BRANCH='test"branch'
render_git
[[ $_prompt_bryndin_git == *'test"branch'* ]] || \
  fail "quoted branch missing: $_prompt_bryndin_git"

TEST_BRANCH="test'branch"
render_git
[[ $_prompt_bryndin_git == *"test'branch"* ]] || \
  fail "single-quoted branch missing: $_prompt_bryndin_git"

# Dollar signs and backticks are escaped by git-info for its eval consumers;
# the theme must undo that escaping and then treat the text literally.
TEST_BRANCH='feat/$foo'
render_git
[[ $_prompt_bryndin_git == *'feat/$foo'* ]] || \
  fail "dollar sign was not restored: $_prompt_bryndin_git"
[[ $_prompt_bryndin_git != *'feat/\$foo'* ]] || \
  fail "git-info backslash leaked into the prompt"

TEST_BRANCH='feat/`id`'
render_git
[[ $_prompt_bryndin_git == *'feat/`id`'* ]] || \
  fail "backticks were not restored: $_prompt_bryndin_git"

# Quotes, semicolons, dollars and backticks together must not be evaluated.
typeset -g PWNED=0
TEST_BRANCH='x";PWNED=1;"'
render_git
(( PWNED == 0 )) || fail "branch name executed a command list"
[[ $_prompt_bryndin_git == *'x";PWNED=1;"'* ]] || \
  fail "dangerous branch was not rendered literally: $_prompt_bryndin_git"

# Percent signs must be prompt-escaped, not interpreted as colour escapes.
TEST_BRANCH='percent%F{red}'
render_git
[[ $_prompt_bryndin_git == *'percent%%F{red}'* ]] || \
  fail "percent sign was not prompt-escaped: $_prompt_bryndin_git"

# Detached HEAD and position fallbacks still work.
TEST_BRANCH=''
TEST_POSITION=''
TEST_COMMIT='1a2b3c4'
render_git
[[ $_prompt_bryndin_git == *'1a2b3c4'* ]] || \
  fail "commit fallback missing: $_prompt_bryndin_git"

TEST_POSITION='v1.0'
TEST_COMMIT='1a2b3c4'
render_git
[[ $_prompt_bryndin_git == *'v1.0'* ]] || \
  fail "position fallback missing: $_prompt_bryndin_git"

# Verify renamed uses '→' (not '➜') and unmerged uses red (not yellow).
local renamed_fmt unmerged_fmt
zstyle -s ':prezto:module:git:info:renamed' format renamed_fmt
zstyle -s ':prezto:module:git:info:unmerged' format unmerged_fmt
[[ $renamed_fmt == *'→'* && $renamed_fmt != *'➜'* ]] || \
  fail "renamed glyph should be →: $renamed_fmt"
[[ $unmerged_fmt == *'%F{red}'* ]] || \
  fail "unmerged indicator should be red: $unmerged_fmt"

print "PASS: git ref names are rendered safely"

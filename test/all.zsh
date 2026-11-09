#!/usr/bin/env zsh
#
# Run the whole test suite: zsh test/all.zsh [path/to/prompt_bryndin_setup]
#
emulate -LR zsh
local dir=${0:A:h}
local theme=${1:-$dir:h/prompt_bryndin_setup}
local -a failed
local t

for t in $dir/*.zsh(N); do
  [[ $t == */all.zsh ]] && continue
  if zsh "$t" "$theme"; then
    :
  else
    failed+=( $t:t )
  fi
done

if (( $#failed )); then
  print -u2 -- "FAILED: ${(j:, :)failed}"
  exit 1
fi
print "All tests passed."

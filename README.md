prezto_bryndin_prompt
=====================

A configurable two-line prompt for [Prezto](https://github.com/sorin-ionescu/prezto).

The first line is a full-terminal-width separator carrying context about the
current shell; the second line is the input prompt itself. The separator is part
of `PROMPT` (rather than printed by `precmd`), so it survives `clear-screen`,
`zle reset-prompt`, vi keymap switches and terminal resizes.

Features
--------

* full terminal width top line to visually separate different runs
* current time (format configurable)
* current user, highlighted in red for root
* host, shown only on remote machines (SSH, `su`/`sudo`)
* active Python virtualenv / Conda environment
* git info (branch, position or commit, action and status counters)
* current directory, with `~` abbreviation and automatic shortening when the
  header would not fit
* directories without write permission highlighted in red
* last command exit status, background jobs, history number, command duration,
  vi overwrite mode and `$VIM` indicators
* multi-byte (display-column) aware width calculation, so wide characters and
  CJK paths do not break the separator
* 256-colour defaults with an automatic downgrade to 16 colours, plus
  `NO_COLOR` / monochrome support
* optional asynchronous git status collection
* everything configurable through `zstyle` — no need to edit the theme file

Installation
------------

1. Copy `prompt_bryndin_setup` into your Prezto prompt functions directory:

   ```sh
   cp prompt_bryndin_setup ~/.zprezto/modules/prompt/functions/
   ```

2. Enable the required modules in `${ZDOTDIR:-$HOME}/.zpreztorc`:

   ```sh
   zstyle ':prezto:load' pmodule \
     'git' \
     'helper' \
     'editor' \
     'python' \
     'prompt'
   ```

3. Select the theme:

   ```sh
   zstyle ':prezto:module:prompt' theme 'bryndin'
   ```

   The theme sets `zstyle ':prezto:module:prompt' managed 'yes'` itself, which
   is required for the `editor` module to populate `editor_info`.

4. Start a new shell. `prompt -p bryndin` previews the theme.

Requirements
------------

* zsh 5.3 or newer
* Prezto modules: `git`, `helper`, `editor`, `prompt` (`python` is recommended
  for virtualenv detection but is optional)
* a UTF-8 locale and a terminal that understands box-drawing characters
* a 256-colour terminal for the default palette (falls back automatically)

Configuration
-------------

All options live under `:prezto:module:prompt:bryndin`. Put these in
`.zpreztorc`, before the `prompt` module is loaded.

```sh
# Colours. Named colours, 0-15, or 256-colour indices.
# (Named `main-color', not `color': Prezto's global ':prezto:*:* color' style
# would otherwise leak into this context.)
zstyle ':prezto:module:prompt:bryndin' main-color        'cyan'
zstyle ':prezto:module:prompt:bryndin' time-color         '27'
zstyle ':prezto:module:prompt:bryndin' host-color         '27'
zstyle ':prezto:module:prompt:bryndin' virtualenv-color   'yellow'
zstyle ':prezto:module:prompt:bryndin' dir-color          '33'
zstyle ':prezto:module:prompt:bryndin' git-color          'blue'
zstyle ':prezto:module:prompt:bryndin' error-color        'red'
# auto | 256 | 16 | none.  NO_COLOR also forces 'none'.
zstyle ':prezto:module:prompt:bryndin' colors             'auto'

# Separator glyph and its colour (empty = same as `main-color`).
zstyle ':prezto:module:prompt:bryndin' separator          '─'
zstyle ':prezto:module:prompt:bryndin' separator-color    ''

# Which left-hand blocks are shown, in display order.
zstyle ':prezto:module:prompt:bryndin' blocks \
  'time' 'host' 'virtualenv' 'git'

# Time: any zsh prompt date/time escape.
zstyle ':prezto:module:prompt:bryndin' time-format        '%T'

# auto | always | never.  SSH_TTY / SSH_CLIENT / SSH_CONNECTION and
# su/sudo are detected in 'auto' mode.
zstyle ':prezto:module:prompt:bryndin' host               'auto'

# Compression fallback used only when the full %~ path does not fit:
# prompt-pwd | full | tilde.  'prompt-pwd' honours the framework-wide
# ':prezto:module:prompt' pwd-length style (short | long | full).
# `pwd' remains a deprecated alias for `compressed-pwd'.
zstyle ':prezto:module:prompt:bryndin' compressed-pwd   'prompt-pwd'

# Clip any single block to N display columns (0 disables clipping).
zstyle ':prezto:module:prompt:bryndin' max-block-width     '0'

# Second-line indicators (yes/no).
zstyle ':prezto:module:prompt:bryndin' exit-status         'yes'
zstyle ':prezto:module:prompt:bryndin' jobs                'yes'
zstyle ':prezto:module:prompt:bryndin' history             'no'
zstyle ':prezto:module:prompt:bryndin' duration            'no'
zstyle ':prezto:module:prompt:bryndin' vim                 'yes'
zstyle ':prezto:module:prompt:bryndin' overwrite           'yes'
# ZLE keymap indicator (❯❯❯ / ❮❮❮) before the input line.  A basic ❯ is
# shown when this is off.
zstyle ':prezto:module:prompt:bryndin' keymap-indicator    'no'

# Collapse to a single line (drop the separator header).
zstyle ':prezto:module:prompt:bryndin' single-line         'no'

# Collect git status in a background worker (requires Prezto's async helper).
zstyle ':prezto:module:prompt:bryndin' async               'no'
```

Framework-wide styles that are honoured:

```sh
zstyle ':prezto:module:prompt' pwd-length       'short'
zstyle ':prezto:module:prompt' show-return-val  'yes'   # show numeric exit code
zstyle ':prezto:module:prompt' managed          'yes'   # set by the theme
```

Notes
-----

* Git status is collected synchronously by default. Enable `async` for large
  repositories; if the async helper is unavailable the theme falls back to
  synchronous collection.  When the directory changes, the previous
  repository's git block is cleared immediately and the new one appears when
  the worker returns; queued jobs are flushed on each prompt so rapid
  directory changes do not build a backlog.
* The header re-flows on terminal resize via a `TRAPWINCH` handler.  Any
  pre-existing resize trap is saved and restored when the theme is torn down.
* `compressed-pwd` only controls the overflow fallback.  The normal header
  shows the full `%~` path and switches to the compressed form when it does not
  fit.
* As with other Prezto themes, git ref names and virtualenv names are inserted
  into a prompt string. Avoid literal `%` in ref names, or escape it in your
  `git:info:*` formats.

Tests
-----

```sh
zsh test/all.zsh
zsh -n prompt_bryndin_setup
```

Each test file can also be run on its own (`zsh test/coalesce.zsh`, etc.). They
load the theme with the Prezto modules stubbed out, so no Prezto installation
is required.

Screenshots
-----------

![prompt screenshot](https://i.imgur.com/b2M5eOw.png "Prompt screenshot")

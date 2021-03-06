prezto_bryndin_prompt
=====================

Custom 2-liner prompt for [prezto](https://github.com/sorin-ionescu/prezto) (zsh framework).

Features
--------
  * full terminal width top line to visually separate different runs
  * current time
  * current user
  * highlites root users in red
  * host (only shown on remote machines)
  * active pythons virtualenv
  * git info
  * current dir (automatically falls back to shortened version if too long)
  * highlights dirs without write permission in red

Screenshots
-----------
![alt prompt screenshot](http://i.imgur.com/b2M5eOw.png?1 "Prompt screenshot")

Requirements
------------
prezto modules:
  * git
  * python
  * helper
  * editor

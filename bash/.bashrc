# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias nano='micro'
alias hx='helix'

export EDITOR=helix
export VISUAL=helix


ARCHLAND_CLR='\[\e[38;2;235;22;5m\]'
RESET_CLR='\[\e[0m\]'

PS1='\u@'"${ARCHLAND_CLR}"'\h'"${RESET_CLR}"' \w \$ '

# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='lsd'
alias grep='grep --color=auto'
alias nano='micro'
alias hx='helix'

export EDITOR=helix
export VISUAL=helix

__xler_startup_fetch() {
  [[ -t 1 ]] || return
  [[ -z "${__XLER_FASTFETCH_SHOWN:-}" ]] || return
  command -v fastfetch >/dev/null 2>&1 || return

  __XLER_FASTFETCH_SHOWN=1
  fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
  __xler_clear_after_fetch=1

  __xler_arm_first_command_clear() {
    [[ -n "${__xler_clear_after_fetch:-}" ]] || return
    __xler_waiting_for_first_command=1
  }

  __xler_add_prompt_command() {
    local fn="$1"
    local decl

    decl="$(declare -p PROMPT_COMMAND 2>/dev/null || true)"

    if [[ "$decl" == declare\ -a* ]]; then
      local item
      for item in "${PROMPT_COMMAND[@]}"; do
        [[ "$item" == "$fn" ]] && return
      done
      PROMPT_COMMAND+=("$fn")
      return
    fi

    if [[ -z "${PROMPT_COMMAND:-}" ]]; then
      PROMPT_COMMAND="$fn"
    elif [[ "${PROMPT_COMMAND}" != *"$fn"* ]]; then
      PROMPT_COMMAND="${PROMPT_COMMAND}"$'\n'"$fn"
    fi
  }

  __xler_clear_on_first_command() {
    local cmd="${BASH_COMMAND:-}"

    if [[ -z "${__xler_clear_after_fetch:-}" ]]; then
      trap - DEBUG
      return
    fi

    [[ -n "${__xler_waiting_for_first_command:-}" ]] || return

    case "$cmd" in
      __xler_*|trap*)
        return
        ;;
      clear)
        unset __xler_clear_after_fetch
        unset __xler_waiting_for_first_command
        trap - DEBUG
        return
        ;;
    esac

    unset __xler_clear_after_fetch
    unset __xler_waiting_for_first_command
    trap - DEBUG
    clear
  }

  __xler_add_prompt_command "__xler_arm_first_command_clear"
  trap '__xler_clear_on_first_command' DEBUG
}

__xler_startup_fetch

ARCHLAND_CLR='\[\e[38;2;235;22;5m\]'
RESET_CLR='\[\e[0m\]'

PS1='\u@'"${ARCHLAND_CLR}"'\h'"${RESET_CLR}"' \w \$ '

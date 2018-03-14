# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
if [[ -z "$PRIMARY_FG" ]]; then
	PRIMARY_FG=black
fi

# Characters
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u27f3" # gear "\u2699", open arrow "\u21bb", gap arrow "\u27f3"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Status:
# - was there an error
# - am I in a nested shell
# - am I root
# - are there background jobs
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -eq 0 ]] && symbols+="%{%F{green}%}λ" # ❖
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}λ" # ✘ or $CROSS
  [[ $SHLVL -ge 2 ]] && symbols+=${SHLVL}
  # [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR" # replaced by prompt_jobs
  # [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING" # moved to prompt_context

  [[ -n "$symbols" ]] && prompt_segment $PRIMARY_FG default "$symbols"
}

# Braille job counter by https://github.com/dekz/prompt/
prompt_jobs () {
  indicators=("⠂" "⠃" "⠇" "⠗" "⠷" "⠿")

  _jobs=$(jobs -l | wc -l | sed -E 's/\ +$//' | sed -E 's/^\ +//')
  indicator=${indicators[${_jobs}]}

  if [[ "$indicator" == "" && ("${_jobs}" -gt 0) ]]; then
    # Too many jobs to display
    indicator="⠿"
  fi

  [ -n "$indicator" ] && prompt_segment $PRIMARY_FG default "%F{magenta}$indicator"
}

# Node: current Node version
prompt_n() {
  if [[ $(type n) =~ 'n is /usr/local/bin/n' ]]; then
    local v=$(node -v)
  fi
  [[ $v != '' ]] && prompt_segment black cyan "$v" # ⬡
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue $PRIMARY_FG "(`basename $virtualenv_path`)"
  fi
}

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`
  local root
  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    [[ $UID -eq 0 ]] && user="$LIGHTNING root"
    prompt_segment black yellow "$user @ %m"
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue $PRIMARY_FG '%3~' # omit number for full path
}

# Git: branch/detached head, dirty status
prompt_git() {
  local color ref state mode repo_path
  is_dirty() {
    test -n "$(git status --porcelain --ignore-submodules)"
  }
  if [[ -n $vcs_info_msg_0_ ]]; then
    # coloration
    if is_dirty; then
      color=yellow
    else
      color=green
    fi
    # ref parsing
    ref=$vcs_info_msg_0_
    if [[ ${ref: -3} == "..." ]]; then # detached commits end in '...'
      ref="$DETACHED $(git rev-parse --short HEAD 2> /dev/null)"
    else
      ref="$BRANCH $vcs_info_msg_0_"
    fi
    # git mode
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi
    # staged, mixed, or clean
    if [[ -n $vcs_info_msg_1_ ]]; then
      state=" ${vcs_info_msg_1_}"
    fi
    # final output
    prompt_segment $color $PRIMARY_FG
    print -Pn "${ref}${state}${mode}"
  fi
}

## Main prompt
prompt_agnoster_main() {
  RETVAL=$?
  CURRENT_BG='NONE'
  prompt_status
  prompt_jobs
  prompt_n
  prompt_virtualenv
  prompt_context
  prompt_virtualenv
  prompt_dir
  prompt_git
  prompt_end
}

prompt_agnoster_precmd() {
  vcs_info
  PROMPT='
%{%f%b%k%}$(prompt_agnoster_main) '
  # RPROMPT='%*'
}

prompt_agnoster_setup() {
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_precmd

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' get-revision true
  zstyle ':vcs_info:*' check-for-changes true
  zstyle ':vcs_info:*' stagedstr '✚'
  zstyle ':vcs_info:*' unstagedstr '●'
  zstyle ':vcs_info:git*' formats '%b' '%u%c' # branch / (un)staged
  zstyle ':vcs_info:git*' actionformats '%b' '%u%c' # %a for action
}

prompt_agnoster_setup "$@"

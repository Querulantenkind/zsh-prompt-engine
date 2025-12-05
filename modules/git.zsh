# Git status module

function zpe__git_is_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

function zpe__git_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

function zpe__git_dirty_counts() {
  # Returns added, modified, deleted counts
  local status added=0 modified=0 deleted=0
  status=$(git status --porcelain 2>/dev/null)
  local line
  while IFS= read -r line; do
    case ${line[1,1]}${line[2,2]} in
      M*|*M) ((modified++));;
      A*|*A) ((added++));;
      D*|*D) ((deleted++));;
    esac
  done <<< "$status"
  print -r -- "$added $modified $deleted"
}

function zpe_module_git() {
  [[ ${ZPE_GIT_CONF[show_branch]} == true || ${ZPE_GIT_CONF[show_status]} == true ]] || return
  zpe__git_is_repo || return

  local branch
  branch=$(zpe__git_branch) || return
  local seg="git:${branch}"

  if [[ ${ZPE_GIT_CONF[show_status]} == true ]]; then
    local counts added modified deleted
    counts=($(zpe__git_dirty_counts))
    added=${counts[1]:-0}
    modified=${counts[2]:-0}
    deleted=${counts[3]:-0}
    local parts=()
    (( added > 0 )) && parts+=("+${added}")
    (( modified > 0 )) && parts+=("~${modified}")
    (( deleted > 0 )) && parts+=("-${deleted}")
    if (( ${#parts[@]} > 0 )); then
      seg+=" ${parts[*]}"
    fi
  fi

  local color_prefix=$(zpe_color accent magenta)
  local color_reset="%f"
  print -n -- "${color_prefix}${seg}${color_reset}"
}

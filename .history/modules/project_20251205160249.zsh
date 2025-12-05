# Project context module

function zpe__truncate_path() {
  local str=$1 max=$2
  (( max <= 0 )) && { print -r -- "$str"; return; }
  if (( ${#str} > max )); then
    print -r -- "…${str[-$((max-1)),-1]}"
  else
    print -r -- "$str"
  fi
}

function zpe_module_project() {
  local dir=${PWD:t}
  local max_len=${ZPE_PROJECT_CONF[max_path_len]:-0}
  dir=$(zpe__truncate_path "$dir" "$max_len")
  local color_prefix=$(zpe_color primary cyan)
  local color_reset="%f"
  print -n -- "${color_prefix}proj:${dir}${color_reset}"
}

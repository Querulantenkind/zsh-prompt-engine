# Project context module

function zpe_module_project() {
  local dir=${PWD:t}
  local color_prefix=$(zpe_color primary cyan)
  local color_reset="%f"
  print -n -- "${color_prefix}proj:${dir}${color_reset}"
}

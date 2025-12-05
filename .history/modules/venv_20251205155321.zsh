# Python virtual environment module

function zpe__venv_name() {
  if [[ -n $VIRTUAL_ENV ]]; then
    print -r -- "${VIRTUAL_ENV:t}"
    return 0
  fi
  if [[ -n $CONDA_DEFAULT_ENV ]]; then
    print -r -- "$CONDA_DEFAULT_ENV"
    return 0
  fi
  return 1
}

function zpe_module_venv() {
  local name
  name=$(zpe__venv_name) || return
  [[ -z $name ]] && return

  local seg="venv:${name}"
  if [[ ${ZPE_VENV_CONF[show_prefix]} == true && -n $VIRTUAL_ENV ]]; then
    seg="venv:${VIRTUAL_ENV:t}"
  fi

  local color_prefix=$(zpe_color primary cyan)
  local color_reset="%f"
  print -n -- "${color_prefix}${seg}${color_reset}"
}

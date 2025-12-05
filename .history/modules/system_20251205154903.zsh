# System metrics module

function zpe__loadavg() {
  if [[ -r /proc/loadavg ]]; then
    print -r -- "$(cut -d' ' -f1 /proc/loadavg)"
  else
    uptime 2>/dev/null | awk -F'load average: ' '{print $2}' | cut -d',' -f1
  fi
}

function zpe_module_system() {
  local pieces=()
  if [[ ${ZPE_SYSTEM_CONF[show_time]} == true ]]; then
    pieces+=("$(date +%H:%M)")
  fi
  if [[ ${ZPE_SYSTEM_CONF[show_load]} == true ]]; then
    local load
    load=$(zpe__loadavg)
    [[ -n $load ]] && pieces+=("load ${load}")
  fi
  (( ${#pieces[@]} == 0 )) && return
  local color_prefix=$(zpe_color muted white)
  local color_reset="%f"
  print -n -- "${color_prefix}${(j: : )pieces}${color_reset}"
}

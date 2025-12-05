# Battery status module (Linux-focused)

function zpe__battery_path() {
  local path
  for path in /sys/class/power_supply/BAT*; do
    [[ -e $path ]] && { print -r -- "$path"; return 0; }
  done
  return 1
}

function zpe__battery_percent_and_status() {
  local base
  base=$(zpe__battery_path) || return 1
  local capacity bat_state
  if [[ -r ${base}/capacity ]]; then
    capacity=$(<"${base}/capacity")
  fi
  if [[ -r ${base}/status ]]; then
    bat_state=$(<"${base}/status")
  fi
  [[ -z $capacity ]] && return 1
  print -r -- "${capacity}|${bat_state}"
}

function zpe_module_battery() {
  local data
  data=$(zpe__battery_percent_and_status) || return
  local percent=${data%%|*}
  local bat_state=${data#*|}
  local icon=""
  case ${bat_state:l} in
    charging) icon="+";;
    full) icon="=";;
    discharging) icon="-";;
    *) icon="";;
  esac

  local seg
  if [[ ${ZPE_BATTERY_CONF[show_status]} == true && -n $icon ]]; then
    seg="bat:${percent}%${icon}"
  else
    seg="bat:${percent}%"
  fi

  # Color based on thresholds
  local warn_thresh=${ZPE_BATTERY_CONF[warn_threshold]:-20}
  local crit_thresh=${ZPE_BATTERY_CONF[critical_threshold]:-10}
  local color
  if (( percent <= crit_thresh )); then
    color="red"
  elif (( percent <= warn_thresh )); then
    color="yellow"
  else
    color=${ZPE_COLOR_CONF[primary]:-cyan}
  fi

  local color_prefix="%F{${color}}"
  local color_reset="%f"
  print -n -- "${color_prefix}${seg}${color_reset}"
}

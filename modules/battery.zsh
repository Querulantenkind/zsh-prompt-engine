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
  local capacity status
  if [[ -r ${base}/capacity ]]; then
    capacity=$(<"${base}/capacity")
  fi
  if [[ -r ${base}/status ]]; then
    status=$(<"${base}/status")
  fi
  [[ -z $capacity ]] && return 1
  print -r -- "${capacity}|${status}"
}

function zpe_module_battery() {
  local data
  data=$(zpe__battery_percent_and_status) || return
  local percent=${data%%|*}
  local status=${data#*|}
  local icon=""
  case ${status:l} in
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

  local color_prefix=$(zpe_color primary cyan)
  local color_reset="%f"
  print -n -- "${color_prefix}${seg}${color_reset}"
}

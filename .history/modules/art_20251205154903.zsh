# ASCII art / animation module

function zpe_module_art() {
  local total=${#ZPE_ART_FRAMES[@]}
  (( total == 0 )) && return
  local frame=${ZPE_ART_FRAMES[$((ZPE_FRAME_INDEX + 1))]}
  local color_prefix=$(zpe_color accent magenta)
  local color_reset="%f"
  print -n -- "${color_prefix}${frame}${color_reset}"
}

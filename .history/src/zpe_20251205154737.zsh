#!/usr/bin/env zsh
# Core runtime for zsh-prompt-engine

emulate -L zsh

# Load basic color support
autoload -U colors && colors

# Global settings with defaults; config loader will override when available
: ${ZPE_ROOT:=${0:A:h}/..}
: ${ZPE_CONFIG_PATH:=${ZPE_ROOT}/config/default.toml}
: ${ZPE_SEPARATOR:=" | "}
: ${ZPE_ENABLE_ANIMATION:=true}
: ${ZPE_FRAME_INTERVAL:=1}

setopt prompt_subst

# State containers
typeset -ga ZPE_MODULE_ORDER=(art project git system)
typeset -ga ZPE_ART_FRAMES
ZPE_ART_FRAMES=("(>" "=>" ">=") )
typeset -gA ZPE_GIT_CONF
ZPE_GIT_CONF=(
  [show_branch]="true"
  [show_status]="true"
)
typeset -gA ZPE_SYSTEM_CONF
ZPE_SYSTEM_CONF=(
  [show_time]="true"
  [show_load]="true"
)
typeset -gA ZPE_COLOR_CONF
ZPE_COLOR_CONF=(
  [primary]="cyan"
  [muted]="white"
  [accent]="magenta"
)
typeset -gA ZPE_MODULE_HANDLERS

# Animation state
typeset -gi ZPE_FRAME_INDEX=0

# Utility: log to stderr
function zpe_log() {
  print -u2 -- "zpe: $*"
}

# Utility: find python interpreter
function zpe_detect_python() {
  if command -v python3 >/dev/null 2>&1; then
    REPLY=python3
    return 0
  elif command -v python >/dev/null 2>&1; then
    REPLY=python
    return 0
  fi
  return 1
}

# Utility: color helper
function zpe_color() {
  local name=$1
  local fallback=$2
  local chosen=${ZPE_COLOR_CONF[$name]:-$fallback}
  print -n "%F{${chosen}}"
}

# Register a module handler
function zpe_register_module() {
  local name=$1
  local handler=$2
  [[ -n $name && -n $handler ]] || return 1
  ZPE_MODULE_HANDLERS[$name]=$handler
}

# Load config via Python helper; falls back to defaults when loader fails
function zpe_load_config() {
  local loader="${ZPE_ROOT}/scripts/config_loader.py"
  local py
  if ! zpe_detect_python; then
    zpe_log "python is required to read config; using defaults"
    return 1
  fi
  py=$REPLY
  if [[ ! -f $loader ]]; then
    zpe_log "config loader missing at $loader"
    return 1
  fi
  local payload
  payload=$($py "$loader" "$ZPE_CONFIG_PATH" 2> >(
    while read -r line; do zpe_log "$line"; done
  )) || {
    zpe_log "failed to parse config; using defaults"
    return 1
  }
  eval "$payload"
  return 0
}

# Build prompt string from registered modules
function zpe_render_prompt() {
  local segments=()
  local module
  for module in "${ZPE_MODULE_ORDER[@]}"; do
    local handler=${ZPE_MODULE_HANDLERS[$module]}
    if [[ -n $handler ]] && whence -w "$handler" >/dev/null 2>&1; then
      local segment
      segment="$($handler)"
      [[ -n $segment ]] && segments+=("$segment")
    fi
  done
  PROMPT="${(j.${ZPE_SEPARATOR}.)segments} "
}

# Advance animation frame when enabled
function zpe_next_frame() {
  if [[ $ZPE_ENABLE_ANIMATION != true ]]; then
    return
  fi
  local total=${#ZPE_ART_FRAMES[@]}
  (( total == 0 )) && return
  ZPE_FRAME_INDEX=$(( (ZPE_FRAME_INDEX + 1) % total ))
}

# Hook called before each prompt render
function zpe_precmd() {
  zpe_next_frame
  zpe_render_prompt
}

# Wire up precmd hook safely
function zpe_install_precmd() {
  if (( ${precmd_functions[(I)zpe_precmd]} == 0 )); then
    precmd_functions+=(zpe_precmd)
  fi
}

# Source modules and register handlers
function zpe_register_default_modules() {
  local module_dir="${ZPE_ROOT}/modules"
  [[ -d $module_dir ]] || return
  source "$module_dir/art.zsh"
  source "$module_dir/project.zsh"
  source "$module_dir/git.zsh"
  source "$module_dir/system.zsh"
  zpe_register_module art zpe_module_art
  zpe_register_module project zpe_module_project
  zpe_register_module git zpe_module_git
  zpe_register_module system zpe_module_system
}

# Ensure arrays have sensible defaults if config was missing
function zpe_apply_fallbacks() {
  (( ${#ZPE_MODULE_ORDER[@]} == 0 )) && ZPE_MODULE_ORDER=(art project git system)
  (( ${#ZPE_ART_FRAMES[@]} == 0 )) && ZPE_ART_FRAMES=("[" "|" "]")
  [[ -z ${ZPE_SEPARATOR} ]] && ZPE_SEPARATOR=" | "
}

# Public initializer
function zpe_init() {
  zpe_load_config
  zpe_apply_fallbacks
  zpe_register_default_modules
  zpe_install_precmd
  zpe_render_prompt
}

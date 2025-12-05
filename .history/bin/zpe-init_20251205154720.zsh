#!/usr/bin/env zsh
# Entry point for zsh-prompt-engine. Source this from your .zshrc.

# Resolve repository root relative to this script
ZPE_SCRIPT_DIR=${${(%):-%x}:A:h}
ZPE_ROOT=${ZPE_ROOT:-${ZPE_SCRIPT_DIR%/bin}}
export ZPE_ROOT

if [[ ! -f "${ZPE_ROOT}/src/zpe.zsh" ]]; then
  print -u2 "zpe: core script missing at ${ZPE_ROOT}/src/zpe.zsh"
  return 1
fi

source "${ZPE_ROOT}/src/zpe.zsh"
# Initialize the prompt once this file is sourced
zpe_init

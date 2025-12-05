#!/usr/bin/env bash
# Install zsh-prompt-engine by symlinking into ~/.local/bin and optionally
# appending a source line to ~/.zshrc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
INIT_SCRIPT="${SCRIPT_DIR}/bin/zpe-init.zsh"
LINK_NAME="zpe-init.zsh"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --link-only    Only create symlink, do not modify ~/.zshrc
  --uninstall    Remove symlink and (optionally) source line from ~/.zshrc
  -h, --help     Show this help message
EOF
}

link_only=false
uninstall=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link-only) link_only=true; shift ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

ensure_bin_dir() {
  if [[ ! -d "$BIN_DIR" ]]; then
    echo "Creating $BIN_DIR"
    mkdir -p "$BIN_DIR"
  fi
}

create_symlink() {
  local target="${BIN_DIR}/${LINK_NAME}"
  if [[ -L "$target" ]]; then
    echo "Symlink already exists: $target"
  elif [[ -e "$target" ]]; then
    echo "Warning: $target exists and is not a symlink; skipping"
  else
    ln -s "$INIT_SCRIPT" "$target"
    echo "Created symlink: $target -> $INIT_SCRIPT"
  fi
}

remove_symlink() {
  local target="${BIN_DIR}/${LINK_NAME}"
  if [[ -L "$target" ]]; then
    rm "$target"
    echo "Removed symlink: $target"
  else
    echo "No symlink found at $target"
  fi
}

SOURCE_LINE="source \"\${HOME}/.local/bin/zpe-init.zsh\""

add_to_zshrc() {
  local zshrc="${HOME}/.zshrc"
  if [[ ! -f "$zshrc" ]]; then
    echo "Creating $zshrc"
    touch "$zshrc"
  fi
  if grep -qF "zpe-init.zsh" "$zshrc"; then
    echo "\$HOME/.zshrc already sources zpe-init.zsh"
  else
    echo "" >> "$zshrc"
    echo "# zsh-prompt-engine" >> "$zshrc"
    echo "$SOURCE_LINE" >> "$zshrc"
    echo "Added source line to ~/.zshrc"
  fi
}

remove_from_zshrc() {
  local zshrc="${HOME}/.zshrc"
  if [[ -f "$zshrc" ]] && grep -qF "zpe-init.zsh" "$zshrc"; then
    # Remove lines containing zpe-init.zsh and the comment above
    sed -i.bak '/# zsh-prompt-engine/d; /zpe-init\.zsh/d' "$zshrc"
    echo "Removed zpe-init.zsh lines from ~/.zshrc (backup: ~/.zshrc.bak)"
  else
    echo "No zpe-init.zsh reference found in ~/.zshrc"
  fi
}

if $uninstall; then
  remove_symlink
  remove_from_zshrc
  echo "Uninstall complete."
  exit 0
fi

ensure_bin_dir
create_symlink

if ! $link_only; then
  add_to_zshrc
fi

echo ""
echo "Installation complete. Restart your shell or run:"
echo "  source ~/.zshrc"

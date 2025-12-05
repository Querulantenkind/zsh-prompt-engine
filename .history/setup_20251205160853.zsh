# Minimal setup snippet for zsh-prompt-engine
# Copy or source this file in your ~/.zshrc after installation.

# Optional: set a custom config path (default: <repo>/config/default.toml)
# export ZPE_CONFIG_PATH="$HOME/.config/zpe.toml"

# Optional: set a custom cache directory (default: ~/.cache/zpe)
# export ZPE_CACHE_DIR="$HOME/.cache/zpe"

# Load zsh-prompt-engine
if [[ -f "${HOME}/.local/bin/zpe-init.zsh" ]]; then
  source "${HOME}/.local/bin/zpe-init.zsh"
fi

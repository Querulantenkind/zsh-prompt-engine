.PHONY: install uninstall link test help

help:
	@echo "Targets:"
	@echo "  install    - Symlink zpe-init.zsh to ~/.local/bin and add source to ~/.zshrc"
	@echo "  link       - Only create symlink (do not modify ~/.zshrc)"
	@echo "  uninstall  - Remove symlink and source line from ~/.zshrc"
	@echo "  test       - Run Python unit tests"

install:
	@bash install.sh

link:
	@bash install.sh --link-only

uninstall:
	@bash install.sh --uninstall

test:
	python -m unittest discover tests

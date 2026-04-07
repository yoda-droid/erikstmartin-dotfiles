#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"



_install_jetbrains_nerd_font() {
	# Install JetBrains Mono Nerd Font from GitHub releases
	echo "Installing JetBrains Mono Nerd Font"
	url=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.assets[] | select(.name | test("JetBrainsMono.*zip")) | .browser_download_url')
	curl -sL "$url" -o /tmp/JetBrainsMono.zip
	mkdir -p ~/.local/share/fonts
	unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts
	fc-cache -fv ~/.local/share/fonts
	rm /tmp/JetBrainsMono.zip
}

_install() {
	echo "Installing..."
	
	sudo apt install -y git stow

	# Ensure locale exists — many minimal Ubuntu installs omit it
	sudo apt install -y locales
	sudo locale-gen en_US.UTF-8
	sudo update-locale LANG=en_US.UTF-8

	_bootstrap_stow
	_link_dotfiles
	
	sudo apt install -y wget curl zsh fish unzip \
		build-essential make autoconf patch \
		postgresql-client \
		yq entr mc \
		tmux stow direnv htop btop ripgrep \
		llvm clang \
		clazy \
		cppcheck \
		ccache \
		heaptrack \
		spirv-tools \
		glslang-tools \
		libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev \
		libreadline-dev libncurses5-dev libgdbm-dev libdb-dev \
		libgssapi-krb5-2

	# libicu version varies by Ubuntu release (needed for dotnet)
	. /etc/lsb-release
	case "$DISTRIB_CODENAME" in
		noble)   sudo apt install -y libicu74 ;;
		jammy)   sudo apt install -y libicu70 ;;
		*)       sudo apt install -y libicu-dev ;;
	esac

	_install_mise_tools

	gh extension install dlvhdr/gh-dash 2>/dev/null || true

	go install github.com/joshmedeski/sesh/v2@latest
	go install github.com/noahgorstein/jqp@latest

	local kubectl_arch
	kubectl_arch=$(dpkg --print-architecture)
	curl -sL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${kubectl_arch}/kubectl" -o /tmp/kubectl
	sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
	rm /tmp/kubectl

	if [ -z "$WSL_DISTRO_NAME" ]; then
		sudo apt install xclip
	fi

	mkdir -p ~/.cache/zinit/completions

	_install_tpm
	_install_jetbrains_nerd_font

	sudo ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl 2>/dev/null || true

	_install_fzf_git
	
	_install_zinit
	_install_fisher

	local fish_path
	fish_path="$(which fish 2>/dev/null)"
	if [ -n "$fish_path" ] && [ "$SHELL" != "$fish_path" ]; then
		if ! grep -qF "$fish_path" /etc/shells; then
			echo "$fish_path" | sudo tee -a /etc/shells
		fi
		chsh -s "$fish_path"
	fi

	echo ""
	echo "✓ Installation complete. Open a new terminal to start using fish."
}

_system_update() {
	echo "Updating system packages..."
	sudo rm -f /etc/apt/sources.list.d/hashicorp.list
	sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
	sudo apt update && sudo apt upgrade -y
}

_update() {
	echo "Updating..."

	_system_update
	_update_common
}

if [ $# -lt 1 ]; then
	echo "Usage: $0 <install|update|system-update|link|unlink> [packages...]";
	exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
	update)
		_update
		;;
	system-update)
		_system_update
		;;
	link)
		_link_dotfiles "$@"
		;;
	unlink)
		_unlink_dotfiles "$@"
		;;
	install)
		_install
		;;
	*)
		echo "Unknown command: $COMMAND"
		echo "Usage: $0 <install|update|system-update|link|unlink> [packages...]"
		exit 1
		;;
esac

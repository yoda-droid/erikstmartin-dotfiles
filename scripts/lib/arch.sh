#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

_install_yay() {
	if ! command -v yay >/dev/null 2>&1; then
		echo "Installing yay"
		sudo pacman -S --needed --noconfirm git base-devel
		git clone https://aur.archlinux.org/yay.git /tmp/yay
		(cd /tmp/yay && makepkg -si --noconfirm)
		rm -rf /tmp/yay
	fi
}

_install() {
	echo "Installing..."
	
	sudo pacman -Syu --needed --noconfirm stow git

	_bootstrap_stow
	_link_dotfiles
	
	sudo pacman -Syu --needed --noconfirm \
		wget curl zsh fish \
		base-devel make \
		lua \
		postgresql-libs \
		yq entr mc \
		tmux stow direnv htop btop \
		kubectl

	_install_yay
	yay -S --needed --noconfirm \
		jqp \
		sesh-bin \
		fastfetch \
		nerd-fonts-jetbrains-mono \
		clazy \
		cppcheck \
		heaptrack \
		tracy-bin

	sudo pacman -S --needed --noconfirm llvm clang ccache

	yay -S --needed --noconfirm spirv-tools glslang

	_install_mise_tools

	gh extension install dlvhdr/gh-dash 2>/dev/null || true

	_install_tpm

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
}

_system_update() {
	echo "Updating system packages..."
	sudo pacman -Syu --noconfirm
	_install_yay
	yay -Syu --noconfirm
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

#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"

copy_file() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

sync_dir() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"
  rsync -a --delete "$src/" "$dst/"
}

copy_file "$HOME_DIR/.bashrc" "$REPO_ROOT/bash/.bashrc"
copy_file "$HOME_DIR/.bash_profile" "$REPO_ROOT/bash/.bash_profile"
copy_file "$HOME_DIR/.config/foot/foot.ini" "$REPO_ROOT/foot/.config/foot/foot.ini"
copy_file "$HOME_DIR/.config/fastfetch/config.jsonc" "$REPO_ROOT/fastfetch/.config/fastfetch/config.jsonc"

sync_dir "$HOME_DIR/.config/hypr" "$REPO_ROOT/hypr/.config/hypr"
sync_dir "$HOME_DIR/.config/waybar" "$REPO_ROOT/waybar/.config/waybar"
sync_dir "$HOME_DIR/.config/yazi" "$REPO_ROOT/yazi/.config/yazi"

rm -rf "$REPO_ROOT/neofetch"

echo "Dotfiles synced from $HOME_DIR"

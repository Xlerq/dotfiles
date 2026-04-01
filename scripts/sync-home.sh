#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
WALLPAPER_TARGET="$REPO_ROOT/assets/wallpapers/fire.png"

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
  rsync -a --delete --exclude '.git/' --exclude '*.bak' "$src/" "$dst/"
}

render_home_placeholder() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"
  sed "s|$HOME_DIR|@HOME@|g" "$src" > "$dst"
}

sync_user_package() {
  local src="$1"
  local dst="$2"

  if [ -e "$src" ]; then
    sync_dir "$src" "$dst"
  fi
}

sync_wallpaper_asset() {
  local wallpaper_source
  wallpaper_source="$(
    sed -n 's/^[[:space:]]*path = //p' "$HOME_DIR/.config/hypr/hyprpaper.conf" | head -n1
  )"

  wallpaper_source="${wallpaper_source/#\~/$HOME_DIR}"

  if [ -n "$wallpaper_source" ] && [ -f "$wallpaper_source" ]; then
    mkdir -p "$(dirname "$WALLPAPER_TARGET")"
    cp "$wallpaper_source" "$WALLPAPER_TARGET"
  fi
}

copy_file "$HOME_DIR/.bashrc" "$REPO_ROOT/bash/.bashrc"
copy_file "$HOME_DIR/.bash_profile" "$REPO_ROOT/bash/.bash_profile"
sync_user_package "$HOME_DIR/.config/btop" "$REPO_ROOT/btop/.config/btop"
sync_user_package "$HOME_DIR/.config/cava" "$REPO_ROOT/cava/.config/cava"
sync_user_package "$HOME_DIR/.config/fastfetch" "$REPO_ROOT/fastfetch/.config/fastfetch"
sync_user_package "$HOME_DIR/.config/foot" "$REPO_ROOT/foot/.config/foot"
sync_user_package "$HOME_DIR/.config/helix" "$REPO_ROOT/helix/.config/helix"
sync_user_package "$HOME_DIR/.config/hypr" "$REPO_ROOT/hypr/.config/hypr"
sync_user_package "$HOME_DIR/.config/micro" "$REPO_ROOT/micro/.config/micro"
sync_user_package "$HOME_DIR/.config/pupgui" "$REPO_ROOT/pupgui/.config/pupgui"
sync_user_package "$HOME_DIR/.config/rustfmt" "$REPO_ROOT/rustfmt/.config/rustfmt"
sync_user_package "$HOME_DIR/.config/spotatui" "$REPO_ROOT/spotatui/.config/spotatui"
sync_user_package "$HOME_DIR/.config/systemd/user" "$REPO_ROOT/systemd-user/.config/systemd/user"
sync_user_package "$HOME_DIR/.config/waybar" "$REPO_ROOT/waybar/.config/waybar"
sync_user_package "$HOME_DIR/.config/wlogout" "$REPO_ROOT/wlogout/.config/wlogout"
sync_user_package "$HOME_DIR/.config/yazi" "$REPO_ROOT/yazi/.config/yazi"
sync_user_package "$HOME_DIR/.config/zathura" "$REPO_ROOT/zathura/.config/zathura"

cat > "$REPO_ROOT/hypr/.config/hypr/monitor.conf" <<'EOF'
## Portable default: let Hyprland pick the active display automatically.
## Override this locally per machine if you want an exact layout/refresh rate.
monitor = , preferred, auto, 1
EOF

cat > "$REPO_ROOT/hypr/.config/hypr/hyprpaper.conf" <<'EOF'
wallpaper {
  monitor =
  path = @HOME@/.local/share/wallpapers/fire.png
  fit_mode = cover
}
EOF

render_home_placeholder "$HOME_DIR/.config/pupgui/config.ini" "$REPO_ROOT/pupgui/.config/pupgui/config.ini"
sync_wallpaper_asset

rm -rf "$REPO_ROOT/neofetch"

echo "Dotfiles synced from $HOME_DIR"

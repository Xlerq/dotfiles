#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy-home.sh [--dry-run]

Copies the tracked user dotfiles into $HOME, renders @HOME@ placeholders,
and installs the wallpaper used by hyprpaper.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

sync_into_home() {
  local src="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    rsync -an --exclude '.git/' --exclude '*.bak' "$src/" "$HOME_DIR/"
  else
    rsync -a --exclude '.git/' --exclude '*.bak' "$src/" "$HOME_DIR/"
  fi
}

render_template() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'render %s -> %s\n' "$src" "$dst"
  else
    sed "s|@HOME@|$HOME_DIR|g" "$src" > "$dst"
  fi
}

copy_wallpaper() {
  local src="$REPO_ROOT/assets/wallpapers/fire.png"
  local dst="$HOME_DIR/.local/share/wallpapers/fire.png"

  if [ ! -f "$src" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'copy %s -> %s\n' "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

for package in \
  bash \
  btop \
  cava \
  fastfetch \
  foot \
  helix \
  hypr \
  lact \
  micro \
  pupgui \
  rustfmt \
  spotatui \
  systemd-user \
  waybar \
  wlogout \
  yazi \
  zathura; do
  sync_into_home "$REPO_ROOT/$package"
done

render_template "$REPO_ROOT/hypr/.config/hypr/hyprpaper.conf" "$HOME_DIR/.config/hypr/hyprpaper.conf"
render_template "$REPO_ROOT/pupgui/.config/pupgui/config.ini" "$HOME_DIR/.config/pupgui/config.ini"
copy_wallpaper

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\nDry run complete.\n'
else
  printf '\nDotfiles deployed into %s\n' "$HOME_DIR"
  printf 'Next steps:\n'
  printf '  1. Install packages from packages/official.txt and your CPU/GPU files.\n'
  printf '  2. Rebuild waybar CSS with ~/.config/waybar/rebuild-style.sh if needed.\n'
  printf '  3. Reload Hyprland or log in again.\n'
fi

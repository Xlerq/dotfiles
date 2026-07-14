#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
DRY_RUN=0
BACKUP=1
BACKUP_DIR=""
BACKUP_COUNT=0

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy-home.sh [--dry-run] [--no-backup]

Copies the tracked user dotfiles into $HOME, renders @HOME@ placeholders,
and installs the wallpaper used by hyprpaper.

By default, existing target files are backed up to ~/.dotfiles-backups/
before they are overwritten.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-backup)
      BACKUP=0
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

require_cmd cp
require_cmd date
require_cmd find
require_cmd rsync
require_cmd rm
require_cmd sed

ensure_backup_dir() {
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$HOME_DIR/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
  fi
}

backup_existing_path() {
  local rel="$1"
  local src="$HOME_DIR/$rel"
  local dst

  if [ "$BACKUP" -eq 0 ] || [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    return 0
  fi

  ensure_backup_dir
  dst="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
}

backup_package_files() {
  local src="$1"
  local rel

  if [ "$BACKUP" -eq 0 ] || [ "$DRY_RUN" -eq 1 ] || [ ! -d "$src" ]; then
    return 0
  fi

  while IFS= read -r rel; do
    rel="${rel#./}"
    backup_existing_path "$rel"
  done < <(
    cd "$src"
    find . -type f ! -path './.git/*' ! -name '*.bak' -print | sort
  )
}

sync_into_home() {
  local src="$1"

  if [ ! -d "$src" ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    rsync -ani --exclude '.git/' --exclude '*.bak' "$src/" "$HOME_DIR/"
  else
    backup_package_files "$src"
    rsync -a --exclude '.git/' --exclude '*.bak' "$src/" "$HOME_DIR/"
  fi
}

remove_obsolete_file() {
  local rel="$1"
  local path="$HOME_DIR/$rel"

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'remove obsolete %s\n' "$path"
  else
    backup_existing_path "$rel"
    rm -f -- "$path"
  fi
}

render_template() {
  local src="$1"
  local dst="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'render %s -> %s\n' "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    sed "s|@HOME@|$HOME_DIR|g" "$src" > "$dst"
  fi
}

copy_wallpaper() {
  local src="$REPO_ROOT/assets/wallpapers/fire.png"
  local dst="$HOME_DIR/.local/share/wallpapers/fire.png"

  if [ ! -f "$src" ]; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'copy %s -> %s\n' "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    backup_existing_path ".local/share/wallpapers/fire.png"
    cp "$src" "$dst"
  fi
}

for package in \
  autostart \
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
  zathura \
  zed; do
  sync_into_home "$REPO_ROOT/$package"
done

for obsolete_file in \
  .config/autostart/blueman.desktop \
  .config/autostart/nm-applet.desktop \
  .config/hypr/env.conf \
  .config/hypr/hyprland.conf \
  .config/hypr/keys.conf \
  .config/hypr/look_and_feel.conf \
  .config/hypr/rules.conf \
  .config/hypr/start_programs.conf; do
  remove_obsolete_file "$obsolete_file"
done

render_template "$REPO_ROOT/hypr/.config/hypr/hyprpaper.conf" "$HOME_DIR/.config/hypr/hyprpaper.conf"
render_template "$REPO_ROOT/pupgui/.config/pupgui/config.ini" "$HOME_DIR/.config/pupgui/config.ini"
render_template "$REPO_ROOT/spotatui/.config/spotatui/config.yml" "$HOME_DIR/.config/spotatui/config.yml"
copy_wallpaper

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\nDry run complete.\n'
else
  printf '\nDotfiles deployed into %s\n' "$HOME_DIR"
  if [ "$BACKUP_COUNT" -gt 0 ]; then
    printf 'Existing files backed up to %s\n' "$BACKUP_DIR"
  fi
  printf 'Next steps:\n'
  printf '  1. If you did not use scripts/install-arch.sh, install the packages you need from packages/.\n'
  printf '  2. Enable the user services you want (for example: systemctl --user enable --now audio-sanity.service hyprpolkitagent.service).\n'
  printf '  3. Rebuild waybar CSS with ~/.config/waybar/rebuild-style.sh if needed.\n'
  printf '  4. Reload Hyprland or log in again.\n'
fi

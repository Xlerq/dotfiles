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

sync_file() {
  local src="$1"
  local dst="$2"

  if [ -f "$src" ]; then
    copy_file "$src" "$dst"
  else
    rm -f "$dst"
  fi
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

trim_trailing_blank_lines() {
  local file="$1"
  local tmp

  tmp="$(mktemp)"

  awk '
    {
      lines[NR] = $0
      if ($0 != "") {
        last = NR
      }
    }
    END {
      for (i = 1; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

has_gpu_vendor() {
  local wanted="$1"
  local vendor_file vendor

  while IFS= read -r vendor_file; do
    vendor="$(tr '[:upper:]' '[:lower:]' < "$vendor_file")"
    if [ "$vendor" = "$wanted" ]; then
      return 0
    fi
  done < <(find /sys/class/drm -path '*/device/vendor' -type f 2>/dev/null | sort -u)

  return 1
}

sync_user_package() {
  local src="$1"
  local dst="$2"

  if [ -e "$src" ]; then
    sync_dir "$src" "$dst"
  fi
}

sync_systemd_user() {
  local src="$HOME_DIR/.config/systemd/user"
  local dst="$REPO_ROOT/systemd-user/.config/systemd/user"

  if [ ! -d "$src" ]; then
    return 0
  fi

  mkdir -p "$dst"
  rsync -a --delete \
    --delete-excluded \
    --exclude '.git/' \
    --exclude '*.bak' \
    --exclude '*.wants/' \
    --exclude 'pipewire-media-session.service' \
    --exclude 'pipewire-session-manager.service' \
    --exclude 'pulseaudio.service' \
    --exclude 'pulseaudio.socket' \
    "$src/" "$dst/"
}

sync_lact_config() {
  local src="$HOME_DIR/.config/lact/ui.yaml"
  local dst="$REPO_ROOT/lact/.config/lact/ui.yaml"

  if ! has_gpu_vendor "0x1002"; then
    rm -rf "$REPO_ROOT/lact"
    return 0
  fi

  if [ ! -f "$src" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  awk '
    /^selected_gpu:/ {
      next
    }
    /^gpus:/ {
      skip = 1
      next
    }
    skip && /^[^[:space:]]/ {
      skip = 0
    }
    !skip {
      print
    }
  ' "$src" > "$dst"
}

sync_foot_config() {
  local src="$HOME_DIR/.config/foot"
  local dst="$REPO_ROOT/foot/.config/foot"

  if [ ! -d "$src" ]; then
    return 0
  fi

  mkdir -p "$dst"
  rsync -a --delete \
    --delete-excluded \
    --exclude '.git/' \
    --exclude '*.bak' \
    --exclude '*.bak.codex-*' \
    "$src/" "$dst/"
}

sync_micro_config() {
  local src="$HOME_DIR/.config/micro"
  local dst="$REPO_ROOT/micro/.config/micro"

  if [ ! -d "$src" ]; then
    return 0
  fi

  mkdir -p "$dst"
  rsync -a --delete \
    --delete-excluded \
    --exclude '.git/' \
    --exclude '*.bak' \
    --exclude 'buffers/' \
    --exclude 'backups/' \
    "$src/" "$dst/"
}

sync_spotatui_config() {
  local src="$HOME_DIR/.config/spotatui"
  local dst="$REPO_ROOT/spotatui/.config/spotatui"

  if [ ! -d "$src" ]; then
    return 0
  fi

  mkdir -p "$dst"
  rsync -a --delete \
    --delete-excluded \
    --exclude '.git/' \
    --exclude '*.bak' \
    --exclude '.gitignore' \
    --exclude 'client.yml' \
    --exclude '.spotify_token_cache*.json' \
    --exclude 'streaming_cache/' \
    "$src/" "$dst/"
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

write_portable_brightness_scripts() {
  cat > "$REPO_ROOT/hypr/.config/hypr/scripts/monitor_dim.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"

get_backlight_brightness() {
	brightnessctl get 2>/dev/null || true
}

get_ddc_brightness() {
	ddcutil getvcp 10 --brief 2>/dev/null | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1
}

CURRENT="$(get_backlight_brightness)"
if [[ "${CURRENT:-}" =~ ^[0-9]+$ ]]; then
	printf 'brightnessctl:%s\n' "$CURRENT" >"$STATE_FILE"
	brightnessctl set 5% >/dev/null 2>&1 || true
	exit 0
fi

CURRENT="$(get_ddc_brightness)"
if [[ "${CURRENT:-}" =~ ^[0-9]+$ ]]; then
	printf 'ddcutil:%s\n' "$CURRENT" >"$STATE_FILE"
	ddcutil setvcp 10 1 >/dev/null 2>&1 || true
fi
EOF

  cat > "$REPO_ROOT/hypr/.config/hypr/scripts/monitor_restore.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"
FALLBACK_BRIGHTNESS="30"
BACKEND="brightnessctl"

# mały delay, bo po resume monitor bywa jeszcze niegotowy
sleep 2

if [ -f "$STATE_FILE" ]; then
	STATE="$(cat "$STATE_FILE" 2>/dev/null || true)"
else
	STATE=""
fi

if [[ "$STATE" == *:* ]]; then
	BACKEND="${STATE%%:*}"
	BRIGHTNESS="${STATE#*:}"
else
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

if ! [[ "${BRIGHTNESS:-}" =~ ^[0-9]+$ ]]; then
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

case "$BACKEND" in
brightnessctl)
	if brightnessctl set "$BRIGHTNESS" >/dev/null 2>&1; then
		rm -f "$STATE_FILE"
		exit 0
	fi
	for _ in 1 2 3 4 5; do
		if ddcutil setvcp 10 "$BRIGHTNESS" >/dev/null 2>&1; then
			rm -f "$STATE_FILE"
			exit 0
		fi
		sleep 1
	done
	;;
*)
	for _ in 1 2 3 4 5; do
		if ddcutil setvcp 10 "$BRIGHTNESS" >/dev/null 2>&1; then
			rm -f "$STATE_FILE"
			exit 0
		fi
		sleep 1
	done
	if brightnessctl set "$BRIGHTNESS" >/dev/null 2>&1; then
		rm -f "$STATE_FILE"
		exit 0
	fi
	;;
esac

exit 1
EOF

  cat > "$REPO_ROOT/waybar/.config/waybar/monitor-brightness.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

get_ddc_brightness() {
	ddcutil getvcp 10 --terse 2>/dev/null | awk 'NR==1 {print $(NF-1)}'
}

set_ddc_brightness() {
	ddcutil setvcp 10 "$1" >/dev/null 2>&1 || true
}

get_backlight_percent() {
	local current max

	current="$(brightnessctl get 2>/dev/null || true)"
	max="$(brightnessctl max 2>/dev/null || true)"

	if [[ ! "$current" =~ ^[0-9]+$ || ! "$max" =~ ^[0-9]+$ || "$max" -le 0 ]]; then
		return 1
	fi

	printf '%s\n' "$((current * 100 / max))"
}

set_backlight_percent() {
	brightnessctl set "$1%" >/dev/null 2>&1 || true
}

detect_backend() {
	local ddc

	if get_backlight_percent >/dev/null 2>&1; then
		printf 'backlight\n'
		return 0
	fi

	ddc="$(get_ddc_brightness || true)"
	if [[ "$ddc" =~ ^[0-9]+$ ]]; then
		printf 'ddc\n'
		return 0
	fi

	printf 'none\n'
}

get_brightness() {
	case "$(detect_backend)" in
	ddc)
		get_ddc_brightness
		;;
	backlight)
		get_backlight_percent
		;;
	*)
		return 1
		;;
	esac
}

set_brightness() {
	local cur new
	cur="$(get_brightness)"
	cur="${cur:-30}"

	case "${1:-}" in
	up)
		new=$((cur + 5))
		[ "$new" -gt 100 ] && new=100
		;;
	down)
		new=$((cur - 5))
		[ "$new" -lt 1 ] && new=1
		;;
	*)
		new="$cur"
		;;
	esac

	case "$(detect_backend)" in
	ddc)
		set_ddc_brightness "$new"
		;;
	backlight)
		set_backlight_percent "$new"
		;;
	esac
}

case "${1:-}" in
up | down)
	set_brightness "$1"
	;;
esac

cur="$(get_brightness)"
if [[ -z "${cur:-}" || ! "$cur" =~ ^[0-9]+$ ]]; then
	printf '{"text":"󰃟 ?","tooltip":"Nie udało się odczytać jasności ekranu","class":"brightness"}\n'
else
	printf '{"text":"󰃟 %s%%","tooltip":"Jasność ekranu: %s%%","class":"brightness"}\n' "$cur" "$cur"
fi
EOF

  chmod +x \
    "$REPO_ROOT/hypr/.config/hypr/scripts/monitor_dim.sh" \
    "$REPO_ROOT/hypr/.config/hypr/scripts/monitor_restore.sh" \
    "$REPO_ROOT/waybar/.config/waybar/monitor-brightness.sh"
}

copy_file "$HOME_DIR/.bashrc" "$REPO_ROOT/bash/.bashrc"
copy_file "$HOME_DIR/.bash_profile" "$REPO_ROOT/bash/.bash_profile"
sync_file "$HOME_DIR/.config/autostart/blueman.desktop" "$REPO_ROOT/autostart/.config/autostart/blueman.desktop"
sync_file "$HOME_DIR/.config/autostart/nm-applet.desktop" "$REPO_ROOT/autostart/.config/autostart/nm-applet.desktop"
sync_user_package "$HOME_DIR/.config/btop" "$REPO_ROOT/btop/.config/btop"
sync_user_package "$HOME_DIR/.config/cava" "$REPO_ROOT/cava/.config/cava"
sync_user_package "$HOME_DIR/.config/fastfetch" "$REPO_ROOT/fastfetch/.config/fastfetch"
sync_foot_config
sync_user_package "$HOME_DIR/.config/helix" "$REPO_ROOT/helix/.config/helix"
sync_user_package "$HOME_DIR/.config/hypr" "$REPO_ROOT/hypr/.config/hypr"
sync_micro_config
sync_user_package "$HOME_DIR/.config/pupgui" "$REPO_ROOT/pupgui/.config/pupgui"
sync_user_package "$HOME_DIR/.config/rustfmt" "$REPO_ROOT/rustfmt/.config/rustfmt"
sync_spotatui_config
sync_systemd_user
sync_user_package "$HOME_DIR/.config/waybar" "$REPO_ROOT/waybar/.config/waybar"
sync_user_package "$HOME_DIR/.config/wlogout" "$REPO_ROOT/wlogout/.config/wlogout"
sync_user_package "$HOME_DIR/.config/yazi" "$REPO_ROOT/yazi/.config/yazi"
sync_user_package "$HOME_DIR/.config/zathura" "$REPO_ROOT/zathura/.config/zathura"
sync_lact_config

cat > "$REPO_ROOT/hypr/.config/hypr/monitor.conf" <<'EOF'
## Laptop panel: Dell 1080p 120 Hz.
monitor = eDP-1, preferred, 0x0, 1
EOF

cat > "$REPO_ROOT/hypr/.config/hypr/hyprpaper.conf" <<'EOF'
wallpaper {
  monitor =
  path = @HOME@/.local/share/wallpapers/fire.png
  fit_mode = cover
}
EOF

write_portable_brightness_scripts
render_home_placeholder "$HOME_DIR/.config/pupgui/config.ini" "$REPO_ROOT/pupgui/.config/pupgui/config.ini"
trim_trailing_blank_lines "$REPO_ROOT/pupgui/.config/pupgui/config.ini"
sync_wallpaper_asset

rm -rf "$REPO_ROOT/neofetch"

echo "Dotfiles synced from $HOME_DIR"

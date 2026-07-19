#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest/home-items.tsv"
HOME_DIR="${HOME}"
STATE_HOME="${XDG_STATE_HOME:-$HOME_DIR/.local/state}"
SELECTION_FILE="$STATE_HOME/dotfiles/selection"

DRY_RUN=0
YES=0
FORCE=0
BACKUP=1
BACKUP_DIR=""
BACKUP_COUNT=0
DEVICE_REQUEST="auto"
DISPLAY_REQUEST="auto"
DEVICE_PROFILE=""
DISPLAY_PROFILE=""

declare -A BACKED_UP=()

usage() {
  cat <<'EOF'
Usage: ./dotfiles COMMAND [options]

Commands:
  install    Install Arch packages, then apply the dotfiles
  apply      Copy repository dotfiles into HOME (repo -> HOME)
  capture    Capture the current HOME configuration (HOME -> repo)
  list       List tracked HOME components from the manifest
  profiles   List device/display profiles and the saved selection

Aliases:
  deploy     Same as apply
  sync       Same as capture

Common options for apply/capture:
  --device auto|NAME   List available names with: ./dotfiles profiles
  --display auto|NAME  List available names with: ./dotfiles profiles
  --dry-run  Show changes without modifying HOME or the repository
  --yes      Do not ask for confirmation

Capture-only:
  --force    Allow capture with an already dirty Git worktree

Apply-only compatibility option:
  --no-backup

Examples:
  ./dotfiles apply --dry-run
  ./dotfiles apply --device desktop --display desktop-dual
  ./dotfiles capture --dry-run
  ./dotfiles capture
EOF
}

info() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

state_value() {
  local key="$1"

  [ -f "$SELECTION_FILE" ] || return 0
  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$SELECTION_FILE"
}

detect_device_profile() {
  local chassis_file="/sys/class/dmi/id/chassis_type"
  local chassis=""
  local type_file type

  if [ -r "$chassis_file" ]; then
    chassis="$(sed -n '1p' "$chassis_file")"
    case "$chassis" in
      8 | 9 | 10 | 14 | 30 | 31 | 32)
        printf 'laptop\n'
        return 0
        ;;
    esac
  fi

  for type_file in /sys/class/power_supply/*/type; do
    [ -r "$type_file" ] || continue
    type="$(sed -n '1p' "$type_file")"
    if [ "$type" = "Battery" ]; then
      printf 'laptop\n'
      return 0
    fi
  done

  printf 'desktop\n'
}

gpu_vendor_files() {
  local device class_file vendor_file class

  {
    find /sys/class/drm -path '*/device/vendor' -type f 2>/dev/null

    for device in /sys/bus/pci/devices/*; do
      class_file="$device/class"
      vendor_file="$device/vendor"
      [ -f "$class_file" ] && [ -f "$vendor_file" ] || continue

      class="$(cat "$class_file")"
      case "$class" in
        0x03*) printf '%s\n' "$vendor_file" ;;
      esac
    done
  } | sort -u
}

has_gpu_vendor() {
  local wanted="$1"
  local vendor_file vendor

  while IFS= read -r vendor_file; do
    vendor="$(tr '[:upper:]' '[:lower:]' < "$vendor_file")"
    if [ "$vendor" = "$wanted" ]; then
      return 0
    fi
  done < <(gpu_vendor_files)

  return 1
}

validate_profile() {
  local axis="$1"
  local name="$2"

  case "$name" in
    *[!A-Za-z0-9._-]* | "")
      die "Invalid $axis profile name: $name"
      ;;
  esac

  [ -d "$REPO_ROOT/profiles/$axis/$name" ] || die "Unknown $axis profile: $name"
}

resolve_profiles() {
  local saved

  if [ "$DEVICE_REQUEST" = "auto" ]; then
    saved="$(state_value device)"
    DEVICE_PROFILE="${saved:-$(detect_device_profile)}"
  else
    DEVICE_PROFILE="$DEVICE_REQUEST"
  fi

  if [ "$DISPLAY_REQUEST" = "auto" ]; then
    saved="$(state_value display)"
    DISPLAY_PROFILE="${saved:-generic}"
  else
    DISPLAY_PROFILE="$DISPLAY_REQUEST"
  fi

  validate_profile device "$DEVICE_PROFILE"
  validate_profile display "$DISPLAY_PROFILE"
}

write_selection() {
  local tmp

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'select device=%s display=%s\n' "$DEVICE_PROFILE" "$DISPLAY_PROFILE"
    return 0
  fi

  mkdir -p "$(dirname "$SELECTION_FILE")"
  tmp="$(mktemp "$(dirname "$SELECTION_FILE")/.dotfiles.XXXXXX")"
  printf 'device=%s\ndisplay=%s\n' "$DEVICE_PROFILE" "$DISPLAY_PROFILE" > "$tmp"
  chmod 0600 "$tmp"
  mv -fT -- "$tmp" "$SELECTION_FILE"
}

confirm() {
  local answer

  [ "$YES" -eq 1 ] && return 0
  [ -t 0 ] || die "Refusing an interactive operation without a TTY; pass --yes"

  read -r -p "Continue? [y/N] " answer
  case "$answer" in
    y | Y | yes | YES) ;;
    *) die "Cancelled" ;;
  esac
}

replace_literal() {
  local needle="$1"
  local replacement="$2"

  awk -v needle="$needle" -v replacement="$replacement" '
    function replace_all(value, position) {
      while ((position = index(value, needle)) > 0) {
        value = substr(value, 1, position - 1) replacement substr(value, position + length(needle))
      }
      return value
    }
    { print replace_all($0) }
  '
}

ensure_backup_dir() {
  local root="$HOME_DIR/.dotfiles-backups"
  local base suffix=0

  if [ -z "$BACKUP_DIR" ]; then
    if [ -L "$root" ] || { [ -e "$root" ] && [ ! -d "$root" ]; }; then
      die "Backup root must be a real directory: $root"
    fi
    mkdir -p "$root"
    chmod 0700 "$root"
    base="$root/$(date +%Y%m%d-%H%M%S)"
    BACKUP_DIR="$base"
    while [ -e "$BACKUP_DIR" ] || [ -L "$BACKUP_DIR" ]; do
      suffix=$((suffix + 1))
      BACKUP_DIR="$base-$suffix"
    done
    mkdir -p "$BACKUP_DIR"
    chmod 0700 "$BACKUP_DIR"
  fi
}

backup_existing_path() {
  local rel="$1"
  local src="$HOME_DIR/$rel"
  local dst parent

  if [ "$BACKUP" -eq 0 ] || [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  if [ -n "${BACKED_UP[$rel]+x}" ]; then
    return 0
  fi
  parent="$rel"
  while [[ "$parent" == */* ]]; do
    parent="${parent%/*}"
    if [ -n "${BACKED_UP[$parent]+x}" ]; then
      return 0
    fi
  done
  BACKED_UP["$rel"]=1
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    return 0
  fi

  ensure_backup_dir
  dst="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -a -- "$src" "$dst"
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
}

backup_tree_targets() {
  local src="$1"
  local home_rel="$2"
  shift 2
  local dst changes pass change rel target_rel target type

  if [ -z "$home_rel" ] || [ "$home_rel" = "." ]; then
    dst="$HOME_DIR"
  else
    dst="$HOME_DIR/$home_rel"
  fi

  [ -d "$dst" ] || return 0

  if ! changes="$(
    rsync -acni --no-times --omit-dir-times \
      --no-perms --no-owner --no-group \
      --out-format='%i|%n' \
      --exclude '.git' \
      --exclude '*.bak*' \
      "$@" \
      "$src/" "$dst/"
  )"; then
    die "Could not calculate a complete backup plan for $dst"
  fi

  for pass in directories files; do
    while IFS='|' read -r change rel; do
      [ -n "$change" ] || continue
      type="${change:1:1}"
      if { [ "$pass" = "directories" ] && [ "$type" != "d" ]; } \
        || { [ "$pass" = "files" ] && [ "$type" = "d" ]; }; then
        continue
      fi

      rel="${rel%/}"
      if [ -z "$home_rel" ] || [ "$home_rel" = "." ]; then
        target_rel="$rel"
      else
        target_rel="$home_rel/$rel"
      fi
      target="$HOME_DIR/$target_rel"

      case "$type" in
        f | L | S | D)
          backup_existing_path "$target_rel"
          ;;
        d)
          if [ -L "$target" ] || { [ -e "$target" ] && [ ! -d "$target" ]; }; then
            backup_existing_path "$target_rel"
          fi
          ;;
      esac
    done <<< "$changes"
  done
}

ensure_executable_targets() {
  local src="$1"
  local home_rel="$2"
  local source_file rel target_rel target

  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$src"/}"
    if [ -z "$home_rel" ] || [ "$home_rel" = "." ]; then
      target_rel="$rel"
    else
      target_rel="$home_rel/$rel"
    fi
    target="$HOME_DIR/$target_rel"
    if [ -f "$target" ] && [ ! -L "$target" ] && [ ! -x "$target" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'make executable %s\n' "$target"
      else
        backup_existing_path "$target_rel"
        chmod u+x "$target"
      fi
    fi
  done < <(
    find "$src" \
      -path '*/.git' -prune -o \
      -type f -perm /111 ! -name '*.bak*' -print0
  )
}

mirror_executable_bits() {
  local src="$1"
  local dst="$2"
  local source_file rel target

  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$src"/}"
    target="$dst/$rel"
    [ -f "$target" ] && [ ! -L "$target" ] || continue
    if [ -x "$source_file" ]; then
      chmod u+x "$target"
    else
      chmod a-x "$target"
    fi
  done < <(
    find "$src" \
      -path '*/.git' -prune -o \
      -type f ! -name '*.bak*' -print0
  )
}

apply_file() {
  local src="$1"
  local home_rel="$2"
  local dst="$HOME_DIR/$home_rel"
  local tmp

  { [ -e "$src" ] || [ -L "$src" ]; } || {
    warn "Skipping missing repository file: $src"
    return 0
  }

  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'copy %s -> %s\n' "$src" "$dst"
    return 0
  fi

  backup_existing_path "$home_rel"
  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  rm -f -- "$tmp"
  cp -a -- "$src" "$tmp"
  mv -fT -- "$tmp" "$dst"
}

apply_rendered_file() {
  local src="$1"
  local home_rel="$2"
  local dst="$HOME_DIR/$home_rel"
  local tmp

  [ -f "$src" ] || {
    warn "Skipping missing template: $src"
    return 0
  }

  if [ -f "$dst" ] && replace_literal '@HOME@' "$HOME_DIR" < "$src" | cmp -s - "$dst"; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'render %s -> %s\n' "$src" "$dst"
    return 0
  fi

  backup_existing_path "$home_rel"
  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  replace_literal '@HOME@' "$HOME_DIR" < "$src" > "$tmp"
  chmod --reference="$src" "$tmp"
  mv -fT -- "$tmp" "$dst"
}

apply_spotatui_file() {
  local src="$1"
  local home_rel="$2"
  local dst="$HOME_DIR/$home_rel"
  local rendered merged tmp

  [ -f "$src" ] || {
    warn "Skipping missing Spotatui template: $src"
    return 0
  }

  rendered="$(mktemp)"
  merged="$(mktemp)"
  replace_literal '@HOME@' "$HOME_DIR" < "$src" > "$rendered"

  if [ -f "$dst" ]; then
    awk '
      function key_name(line, key) {
        key = line
        sub(/:.*/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        return tolower(key)
      }
      function key_id(line, prefix) {
        match(line, /^[[:space:]]*/)
        prefix = substr(line, RSTART, RLENGTH)
        return prefix key_name(line)
      }
      function sensitive(line, key) {
        key = key_name(line)
        return key ~ /(token|password|secret|api[_-]?key|credential|private[_-]?key)/
      }
      NR == FNR {
        if (sensitive($0)) {
          local_value[key_id($0)] = $0
        }
        next
      }
      {
        id = key_id($0)
        if (sensitive($0) && id in local_value) {
          print local_value[id]
        } else {
          print
        }
      }
    ' "$dst" "$rendered" > "$merged"
  else
    cp -- "$rendered" "$merged"
  fi

  if [ -f "$dst" ] && cmp -s "$merged" "$dst"; then
    if [ "$(stat -Lc %a "$dst")" = "600" ]; then
      rm -f -- "$rendered" "$merged"
      return 0
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'render %s -> %s (preserve local secrets)\n' "$src" "$dst"
    rm -f -- "$rendered" "$merged"
    return 0
  fi

  backup_existing_path "$home_rel"
  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  cp -- "$merged" "$tmp"
  chmod 0600 "$tmp"
  mv -fT -- "$tmp" "$dst"
  rm -f -- "$rendered" "$merged"
}

preflight_directory_sync() {
  local src="$1"
  shift
  local tmp

  tmp="$(mktemp -d)"
  if ! rsync -acni --no-times --omit-dir-times \
    --no-perms --no-owner --no-group \
    --exclude '.git' --exclude '*.bak*' "$@" "$src/" "$tmp/" >/dev/null; then
    rm -rf -- "$tmp"
    die "Could not validate directory source before changing HOME: $src"
  fi
  rm -rf -- "$tmp"
}

apply_directory() {
  local src="$1"
  local home_rel="$2"
  shift 2
  local dst

  if [ -z "$home_rel" ] || [ "$home_rel" = "." ]; then
    dst="$HOME_DIR"
  else
    dst="$HOME_DIR/$home_rel"
  fi

  [ -d "$src" ] || {
    warn "Skipping missing repository directory: $src"
    return 0
  }

  if [ -z "$home_rel" ] || [ "$home_rel" = "." ]; then
    [ -d "$dst" ] || die "HOME is not a directory: $dst"
  elif [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -d "$dst" ]; }; then
    preflight_directory_sync "$src" "$@"
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'replace %s with a managed directory from %s\n' "$dst" "$src"
      return 0
    fi
    backup_existing_path "$home_rel"
    rm -f -- "$dst"
    mkdir -p "$dst"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    rsync -acni --no-times --omit-dir-times \
      --no-perms --no-owner --no-group \
      --exclude '.git' --exclude '*.bak*' "$@" "$src/" "$dst/"
    ensure_executable_targets "$src" "$home_rel"
    return 0
  fi

  backup_tree_targets "$src" "$home_rel" "$@"
  mkdir -p "$dst"
  rsync -ac --no-times --omit-dir-times \
    --no-perms --no-owner --no-group \
    --exclude '.git' --exclude '*.bak*' "$@" "$src/" "$dst/"
  ensure_executable_targets "$src" "$home_rel"
}

remove_obsolete_files() {
  local rel path
  local obsolete=(
    .config/autostart/blueman.desktop
    .config/autostart/nm-applet.desktop
    .config/hypr/env.conf
    .config/hypr/hyprland.conf
    .config/hypr/keys.conf
    .config/hypr/look_and_feel.conf
    .config/hypr/monitor.conf
    .config/hypr/rules.conf
    .config/hypr/start_programs.conf
  )

  for rel in "${obsolete[@]}"; do
    path="$HOME_DIR/$rel"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
      continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'remove obsolete %s\n' "$path"
    else
      backup_existing_path "$rel"
      rm -f -- "$path"
    fi
  done
}

apply_manifest() {
  local id repo_rel home_rel handler src

  while IFS='|' read -r id repo_rel home_rel handler; do
    [ -n "$id" ] || continue
    [[ "$id" == \#* ]] && continue
    src="$REPO_ROOT/$repo_rel"

    case "$handler" in
      template)
        apply_rendered_file "$src" "$home_rel"
        ;;
      spotatui)
        apply_spotatui_file "$src" "$home_rel"
        ;;
      hypr)
        apply_directory "$src" "$home_rel" \
          --exclude 'hyprpaper.conf' \
          --exclude 'hypridle.conf' \
          --exclude 'lua/device.lua' \
          --exclude 'lua/monitor.lua'
        apply_rendered_file "$src/hyprpaper.conf" "$home_rel/hyprpaper.conf"
        ;;
      waybar)
        apply_directory "$src" "$home_rel" \
          --exclude 'device.jsonc' \
          --exclude 'display.jsonc'
        ;;
      mirror | foot | micro | systemd)
        apply_directory "$src" "$home_rel"
        ;;
      lact)
        if has_gpu_vendor "0x1002"; then
          apply_file "$src" "$home_rel"
        else
          info "Skipping LACT config on non-AMD graphics"
        fi
        ;;
      optional-file | wallpaper)
        apply_file "$src" "$home_rel"
        ;;
      *)
        die "Unknown manifest handler '$handler' for $id"
        ;;
    esac
  done < "$MANIFEST"
}

apply_profiles() {
  apply_directory "$REPO_ROOT/profiles/device/$DEVICE_PROFILE" ""
  apply_directory "$REPO_ROOT/profiles/display/$DISPLAY_PROFILE" ""
}

apply_dotfiles() {
  info "Direction: repository -> HOME"
  info "Profiles: device=$DEVICE_PROFILE display=$DISPLAY_PROFILE"
  [ "$DRY_RUN" -eq 1 ] && info "Mode: dry-run"

  if [ "$DRY_RUN" -eq 0 ]; then
    confirm
  fi

  apply_manifest
  apply_profiles
  remove_obsolete_files
  write_selection

  if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run complete; HOME was not modified"
  else
    info "Dotfiles applied to $HOME_DIR"
    if [ "$BACKUP_COUNT" -gt 0 ]; then
      info "Backup: $BACKUP_DIR"
    fi
  fi
}

capture_file() {
  local src="$1"
  local dst="$2"
  local tmp

  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    warn "Skipping missing HOME file: $src"
    return 0
  fi

  if [ -L "$src" ] && [ -L "$dst" ] && [ "$(readlink "$src")" = "$(readlink "$dst")" ]; then
    return 0
  fi
  if [ -f "$src" ] && [ ! -L "$src" ] && [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  rm -f -- "$tmp"
  cp -a -- "$src" "$tmp"
  mv -fT -- "$tmp" "$dst"
}

capture_template() {
  local src="$1"
  local dst="$2"
  local tmp

  [ -f "$src" ] || {
    warn "Skipping missing HOME template source: $src"
    return 0
  }

  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  replace_literal "$HOME_DIR" '@HOME@' < "$src" > "$tmp"
  chmod --reference="$src" "$tmp"
  mv -fT -- "$tmp" "$dst"
}

capture_directory() {
  local src="$1"
  local dst="$2"
  shift 2
  local args=(
    -ac
    --no-times
    --omit-dir-times
    --no-perms
    --no-owner
    --no-group
    --exclude '.git'
    --exclude '*.bak*'
    --exclude-from "$REPO_ROOT/.gitignore"
  )

  [ -d "$src" ] || {
    warn "Skipping missing HOME directory: $src"
    return 0
  }

  if [ -L "$dst" ]; then
    rm -f -- "$dst"
  elif [ -e "$dst" ] && [ ! -d "$dst" ]; then
    die "Repository directory target is not a directory: $dst"
  fi

  mkdir -p "$dst"
  rsync "${args[@]}" "$@" "$src/" "$dst/"
  mirror_executable_bits "$src" "$dst"
}

capture_spotatui() {
  local src="$1"
  local dst="$2"
  local tmp

  [ -f "$src" ] || {
    warn "Skipping missing Spotatui config: $src"
    return 0
  }

  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  awk -v home="$HOME_DIR" '
    function replace_all(value, needle, replacement, position) {
      while ((position = index(value, needle)) > 0) {
        value = substr(value, 1, position - 1) replacement substr(value, position + length(needle))
      }
      return value
    }
    {
      key = $0
      sub(/:.*/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (tolower(key) ~ /(token|password|secret|api[_-]?key|credential|private[_-]?key)/) {
        sub(/:.*/, ": null")
      }
      $0 = replace_all($0, home, "@HOME@")
      if ($0 ~ /:[[:space:]]*@HOME@/) {
        sub(/@HOME@[^[:space:]#]*/, "\"&\"")
      }
      print
    }
  ' "$src" > "$tmp"
  chmod 0644 "$tmp"
  mv -fT -- "$tmp" "$dst"
}

capture_lact() {
  local src="$1"
  local dst="$2"
  local tmp

  [ -f "$src" ] || {
    warn "Skipping missing LACT config: $src"
    return 0
  }

  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.dotfiles.XXXXXX")"
  awk '
    /^selected_gpu:/ { next }
    /^gpus:/ { skip = 1; next }
    skip && /^[^[:space:]]/ { skip = 0 }
    !skip { print }
  ' "$src" > "$tmp"
  chmod 0644 "$tmp"
  mv -fT -- "$tmp" "$dst"
}

capture_wallpaper() {
  local dst="$1"
  local config="$HOME_DIR/.config/hypr/hyprpaper.conf"
  local src

  [ -f "$config" ] || {
    warn "Skipping wallpaper: $config does not exist"
    return 0
  }

  src="$(sed -n 's/^[[:space:]]*path = //p' "$config" | head -n1)"
  src="${src/#\~/$HOME_DIR}"
  [ -f "$src" ] || {
    warn "Skipping wallpaper: $src does not exist"
    return 0
  }

  capture_file "$src" "$dst"
}

normalize_waybar_config() {
  local file="$1"
  local tmp

  [ -f "$file" ] || return 0
  tmp="$(mktemp "$(dirname "$file")/.dotfiles.XXXXXX")"

  awk '
    BEGIN { inserted = 0; in_include = 0 }
    in_include {
      if ($0 ~ /^[[:space:]]*\][[:space:]]*,?[[:space:]]*$/) {
        in_include = 0
      }
      next
    }
    /^[[:space:]]*"include"[[:space:]]*:/ {
      if ($0 !~ /\]/) {
        in_include = 1
      }
      next
    }
    /^[[:space:]]*\/\// {
      comments = comments $0 ORS
      next
    }
    /^[[:space:]]*"output"[[:space:]]*:/ {
      comments = ""
      next
    }
    !inserted && /^[[:space:]]*\{/ {
      print
      print "  \"include\": ["
      print "    \"device.jsonc\","
      print "    \"display.jsonc\""
      print "  ],"
      inserted = 1
      next
    }
    {
      printf "%s", comments
      comments = ""
      print
    }
    END { printf "%s", comments }
  ' "$file" > "$tmp"

  chmod --reference="$file" "$tmp"
  mv -fT -- "$tmp" "$file"
}

capture_manifest() {
  local id repo_rel home_rel handler src dst

  while IFS='|' read -r id repo_rel home_rel handler; do
    [ -n "$id" ] || continue
    [[ "$id" == \#* ]] && continue
    src="$HOME_DIR/$home_rel"
    dst="$REPO_ROOT/$repo_rel"

    case "$handler" in
      mirror)
        capture_directory "$src" "$dst"
        ;;
      foot)
        capture_directory "$src" "$dst" --exclude '*.bak.codex-*'
        ;;
      micro)
        capture_directory "$src" "$dst" --exclude 'buffers/' --exclude 'backups/'
        ;;
      hypr)
        capture_directory "$src" "$dst" \
          --exclude 'old_conf/' \
          --exclude 'hyprpaper.conf' \
          --exclude 'hypridle.conf' \
          --exclude 'env.conf' \
          --exclude 'hyprland.conf' \
          --exclude 'keys.conf' \
          --exclude 'look_and_feel.conf' \
          --exclude 'monitor.conf' \
          --exclude 'rules.conf' \
          --exclude 'start_programs.conf' \
          --exclude 'lua/device.lua' \
          --exclude 'lua/monitor.lua'
        capture_template "$src/hyprpaper.conf" "$dst/hyprpaper.conf"
        ;;
      systemd)
        capture_directory "$src" "$dst" \
          --exclude '*.wants/' \
          --exclude 'pipewire-media-session.service' \
          --exclude 'pipewire-session-manager.service' \
          --exclude 'pulseaudio.service' \
          --exclude 'pulseaudio.socket' \
          --exclude 'xdg-desktop-portal.service' \
          --exclude 'xdg-desktop-portal.service.d/'
        ;;
      waybar)
        capture_directory "$src" "$dst" \
          --exclude 'device.jsonc' \
          --exclude 'display.jsonc'
        normalize_waybar_config "$dst/config.jsonc"
        ;;
      optional-file)
        capture_file "$src" "$dst"
        ;;
      template)
        capture_template "$src" "$dst"
        ;;
      spotatui)
        capture_spotatui "$src" "$dst"
        ;;
      lact)
        if has_gpu_vendor "0x1002"; then
          capture_lact "$src" "$dst"
        else
          info "Skipping LACT config on non-AMD graphics"
        fi
        ;;
      wallpaper)
        capture_wallpaper "$dst"
        ;;
      *)
        die "Unknown manifest handler '$handler' for $id"
        ;;
    esac
  done < "$MANIFEST"
}

capture_profile_tree() {
  local profile_root="$1"
  local profile_file rel home_file

  while IFS= read -r -d '' profile_file; do
    rel="${profile_file#"$profile_root"/}"
    home_file="$HOME_DIR/$rel"
    if [ -e "$home_file" ] || [ -L "$home_file" ]; then
      capture_file "$home_file" "$profile_file"
    else
      warn "Profile file missing in HOME, preserving repository version: $rel"
    fi
  done < <(find "$profile_root" \( -type f -o -type l \) -print0 | sort -z)
}

capture_impl() {
  capture_manifest
  capture_profile_tree "$REPO_ROOT/profiles/device/$DEVICE_PROFILE"
  capture_profile_tree "$REPO_ROOT/profiles/display/$DISPLAY_PROFILE"
}

scan_capture_secrets() {
  local root="$1"
  local changes="$2"
  local change rel file found=0

  while IFS='|' read -r change rel; do
    [ "${change:1:1}" = "f" ] || continue
    rel="${rel%/}"
    file="$root/$rel"
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    grep -Iq . "$file" || continue

    if ! awk -v label="$rel" '
      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
      }
      function sensitive_key(key) {
        key = tolower(key)
        return key ~ /(token|password|secret|api[_-]?key|credential|private[_-]?key)/
      }
      function safe_value(value, lowered) {
        value = trim(value)
        sub(/[[:space:],]+$/, "", value)
        if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) {
          value = substr(value, 2, length(value) - 2)
        }
        lowered = tolower(trim(value))
        return lowered == "" || lowered == "null" || lowered == "none" ||
          lowered == "false" || lowered == "redacted" || lowered == "<redacted>" ||
          lowered ~ /^@home@/ || lowered ~ /^\$[a-z_][a-z0-9_]*$/ ||
          lowered ~ /^\$\{[a-z_][a-z0-9_]*\}$/
      }
      {
        if (!match($0, /[:=]/)) {
          next
        }

        key = tolower(trim(substr($0, 1, RSTART - 1)))
        value = trim(substr($0, RSTART + 1))

        if (key == "environment") {
          if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) {
            value = substr(value, 2, length(value) - 2)
          }
          count = split(value, fields, /[[:space:]]+/)
          sensitive = 0
          unsafe = 0
          for (field_index = 1; field_index <= count; field_index++) {
            entry = fields[field_index]
            gsub(/^["\047]+/, "", entry)
            gsub(/["\047]+$/, "", entry)
            if ((equals = index(entry, "=")) == 0) {
              continue
            }
            environment_key = trim(substr(entry, 1, equals - 1))
            if (!sensitive_key(environment_key)) {
              continue
            }
            sensitive = 1
            if (!safe_value(substr(entry, equals + 1))) {
              unsafe = 1
            }
          }
          if (!sensitive || !unsafe) {
            next
          }
        } else {
          if (!sensitive_key(key) || safe_value(value)) {
            next
          }
        }

        printf "possible secret-like value: %s:%d\n", label, FNR > "/dev/stderr"
        found = 1
      }
      END { exit found }
    ' "$file"; then
      found=1
    fi
  done <<< "$changes"

  [ "$found" -eq 0 ] || die "Capture stopped before modifying the repository; remove or redact the reported values"
}

restore_capture_snapshot() {
  local original="$1"

  rsync -ac --delete --no-times --omit-dir-times \
    --perms --no-owner --no-group \
    --exclude '.git' \
    "$original/" "$REPO_ROOT/"
}

verify_capture_base_unchanged() {
  local original="$1"
  local changes

  if ! changes="$(
    rsync -acni --delete --no-times --omit-dir-times \
      --perms --no-owner --no-group \
      --exclude '.git' \
      "$original/" "$REPO_ROOT/"
  )"; then
    die "Could not verify that the repository stayed unchanged during capture"
  fi

  [ -z "$changes" ] \
    || die "Repository changed while capture was running; no capture changes were applied"
}

capture_snapshot() (
  local tmp output applying=0 status

  tmp="$(mktemp -d)"
  trap '
    status=$?
    if [ "$status" -ne 0 ] && [ "$applying" -eq 1 ]; then
      set +e
      if restore_capture_snapshot "$tmp/original"; then
        warn "Capture update failed; the original repository snapshot was restored"
      else
        warn "Capture update failed and automatic restoration was incomplete"
      fi
      warn "Recovery snapshot retained at: $tmp"
    else
      rm -rf -- "$tmp"
    fi
    exit "$status"
  ' EXIT
  mkdir -p "$tmp/original" "$tmp/repo"
  rsync -a --exclude '.git' "$REPO_ROOT/" "$tmp/original/"
  rsync -a "$tmp/original/" "$tmp/repo/"

  DOTFILES_INTERNAL_CAPTURE=1 "$tmp/repo/scripts/dotfiles.sh" _capture \
    --device "$DEVICE_PROFILE" \
    --display "$DISPLAY_PROFILE" \
    --yes >/dev/null

  output="$(
    rsync -acni --no-times --omit-dir-times \
      --perms --no-owner --no-group \
      --out-format='%i|%n' \
      --exclude '.git' \
      "$tmp/repo/" "$REPO_ROOT/"
  )"
  scan_capture_secrets "$tmp/repo" "$output"

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -n "$output" ]; then
      printf '%s\n' "$output"
    else
      printf 'No repository changes.\n'
    fi
    return 0
  fi

  verify_capture_base_unchanged "$tmp/original"
  applying=1
  rsync -ac --no-times --omit-dir-times \
    --no-perms --no-owner --no-group \
    --exclude '.git' \
    "$tmp/repo/" "$REPO_ROOT/"
  mirror_executable_bits "$tmp/repo" "$REPO_ROOT"
  applying=0
)

capture_dotfiles() {
  local dirty

  info "Direction: HOME -> repository"
  info "Profiles: device=$DEVICE_PROFILE display=$DISPLAY_PROFILE"

  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "Capture requires the repository to be a Git worktree"
  dirty="$(git -C "$REPO_ROOT" status --porcelain)"

  if [ "$DRY_RUN" -eq 1 ]; then
    [ -z "$dirty" ] || warn "Worktree is already dirty; preview is relative to its current state"
    capture_snapshot
    info "Dry run complete; repository was not modified"
    return 0
  fi

  if [ -n "$dirty" ] && [ "$FORCE" -eq 0 ]; then
    die "Repository has uncommitted changes; commit/stash them or pass --force"
  fi

  confirm
  if [ "$FORCE" -eq 0 ]; then
    dirty="$(git -C "$REPO_ROOT" status --porcelain)"
    [ -z "$dirty" ] \
      || die "Repository changed while awaiting confirmation; rerun capture after committing or stashing it"
  fi
  capture_snapshot
  info "HOME captured into $REPO_ROOT"
  git -C "$REPO_ROOT" status --short || true
}

list_items() {
  local id _repo_rel home_rel handler

  printf '%-16s %-38s %s\n' "COMPONENT" "HOME PATH" "CAPTURE"
  while IFS='|' read -r id _repo_rel home_rel handler; do
    [ -n "$id" ] || continue
    [[ "$id" == \#* ]] && continue
    printf '%-16s ~/%-36s %s\n' "$id" "$home_rel" "$handler"
  done < "$MANIFEST"
}

list_profiles() {
  local axis path selected

  for axis in device display; do
    printf '%s profiles:\n' "$axis"
    while IFS= read -r path; do
      printf '  %s\n' "${path##*/}"
    done < <(find "$REPO_ROOT/profiles/$axis" -mindepth 1 -maxdepth 1 -type d | sort)
  done

  selected="$(state_value device)"
  printf 'selected device: %s\n' "${selected:-auto}"
  selected="$(state_value display)"
  printf 'selected display: %s\n' "${selected:-auto}"
}

parse_common_options() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --device | --profile)
        shift
        [ "$#" -gt 0 ] || die "--device requires a value"
        DEVICE_REQUEST="$1"
        ;;
      --display)
        shift
        [ "$#" -gt 0 ] || die "--display requires a value"
        DISPLAY_REQUEST="$1"
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --yes)
        YES=1
        ;;
      --force)
        FORCE=1
        ;;
      --no-backup)
        BACKUP=0
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  local command="${1:-help}"
  [ "$#" -gt 0 ] && shift

  case "$command" in
    install)
      exec "$REPO_ROOT/scripts/install-arch.sh" "$@"
      ;;
    list)
      [ "$#" -eq 0 ] || die "list does not accept options"
      list_items
      ;;
    profiles)
      [ "$#" -eq 0 ] || die "profiles does not accept options"
      list_profiles
      ;;
    apply | deploy | capture | sync | _capture)
      if [ "$command" = "_capture" ] && [ "${DOTFILES_INTERNAL_CAPTURE:-0}" != "1" ]; then
        die "_capture is an internal command"
      fi
      parse_common_options "$@"
      case "$command" in
        apply | deploy)
          [ "$FORCE" -eq 0 ] || die "--force is only valid with capture"
          ;;
        capture | sync | _capture)
          [ "$BACKUP" -eq 1 ] || die "--no-backup is only valid with apply"
          ;;
      esac
      resolve_profiles
      require_cmd awk
      require_cmd cmp
      require_cmd cp
      require_cmd find
      require_cmd mktemp
      require_cmd readlink
      require_cmd rsync
      require_cmd sed
      case "$command" in
        apply | deploy)
          require_cmd date
          require_cmd stat
          apply_dotfiles
          ;;
        capture | sync)
          require_cmd git
          require_cmd grep
          capture_dotfiles
          ;;
        _capture)
          capture_impl
          ;;
      esac
      ;;
    help | -h | --help)
      usage
      ;;
    *)
      usage >&2
      die "Unknown command: $command"
      ;;
  esac
}

main "$@"

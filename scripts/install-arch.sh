#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
INSTALL_OFFICIAL=1
INSTALL_AUR=1
DEPLOY_HOME=1
APPLY_SYSTEM=0
ENABLE_USER_SERVICES=1
WITH_EXTRAS=0
CPU_OVERRIDE=""
GPU_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/install-arch.sh [options]

Fresh-install helper for this Arch Linux dotfiles repo.
Run it as your normal user, not as root.

Options:
  --dry-run             Print the actions without changing the system.
  --with-extras         Install nice-to-have packages in addition to the bare minimum.
  --cpu intel|amd|none  Override CPU package profile detection.
  --gpu amd|nvidia|none Override GPU package profile detection.
  --apply-system        Copy tracked files from system/ into / using sudo.
  --skip-official       Skip pacman package installation.
  --skip-aur            Skip AUR package installation.
  --skip-home           Skip deploy-home.sh.
  --skip-user-services  Do not enable user services.
  -h, --help            Show this help.

Examples:
  ./scripts/install-arch.sh --dry-run
  ./scripts/install-arch.sh
  ./scripts/install-arch.sh --with-extras
  ./scripts/install-arch.sh --cpu intel --gpu nvidia --apply-system
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

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Missing required command: $1"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --with-extras)
        WITH_EXTRAS=1
        ;;
      --cpu)
        shift
        [ "$#" -gt 0 ] || die "--cpu requires a value"
        CPU_OVERRIDE="$1"
        case "$CPU_OVERRIDE" in
          intel | amd | none)
            ;;
          *)
            die "Invalid CPU profile: $CPU_OVERRIDE"
            ;;
        esac
        ;;
      --gpu)
        shift
        [ "$#" -gt 0 ] || die "--gpu requires a value"
        GPU_OVERRIDE="$1"
        case "$GPU_OVERRIDE" in
          amd | nvidia | none)
            ;;
          *)
            die "Invalid GPU profile: $GPU_OVERRIDE"
            ;;
        esac
        ;;
      --apply-system)
        APPLY_SYSTEM=1
        ;;
      --skip-official)
        INSTALL_OFFICIAL=0
        ;;
      --skip-aur)
        INSTALL_AUR=0
        ;;
      --skip-home)
        DEPLOY_HOME=0
        ;;
      --skip-user-services)
        ENABLE_USER_SERVICES=0
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

ensure_arch() {
  [ -f /etc/arch-release ] || die "This installer is intended for Arch Linux."
}

ensure_regular_user() {
  [ "$(id -u)" -ne 0 ] || die "Run this script as your regular user, not root."
}

detect_cpu_profile() {
  if [ -n "$CPU_OVERRIDE" ]; then
    printf '%s\n' "$CPU_OVERRIDE"
    return 0
  fi

  if grep -qi 'AuthenticAMD' /proc/cpuinfo; then
    printf 'amd\n'
    return 0
  fi

  if grep -qi 'GenuineIntel' /proc/cpuinfo; then
    printf 'intel\n'
    return 0
  fi

  printf 'none\n'
}

gpu_vendor_files() {
  find /sys/class/drm -path '*/device/vendor' -type f 2>/dev/null | sort -u
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

detect_gpu_profile() {
  if [ -n "$GPU_OVERRIDE" ]; then
    printf '%s\n' "$GPU_OVERRIDE"
    return 0
  fi

  if has_gpu_vendor "0x10de"; then
    printf 'nvidia\n'
    return 0
  fi

  if has_gpu_vendor "0x1002"; then
    printf 'amd\n'
    return 0
  fi

  printf 'none\n'
}

has_intel_graphics() {
  has_gpu_vendor "0x8086"
}

read_package_files() {
  awk '
    /^[[:space:]]*#/ { next }
    NF == 0 { next }
    { print $1 }
  ' "$@"
}

build_official_package_list() {
  local files
  files=("$REPO_ROOT/packages/official-minimal.txt")

  if [ "$WITH_EXTRAS" -eq 1 ]; then
    files+=("$REPO_ROOT/packages/official-extra.txt")
  fi

  case "$CPU_PROFILE" in
    intel)
      files+=("$REPO_ROOT/packages/cpu-intel.txt")
      ;;
    amd)
      files+=("$REPO_ROOT/packages/cpu-amd.txt")
      ;;
  esac

  case "$GPU_PROFILE" in
    amd)
      files+=("$REPO_ROOT/packages/gpu-amd.txt")
      ;;
    nvidia)
      files+=("$REPO_ROOT/packages/gpu-nvidia.txt")
      ;;
  esac

  {
    read_package_files "${files[@]}"
    if [ "$GPU_PROFILE" = "nvidia" ] && has_intel_graphics; then
      printf '%s\n' "vulkan-intel"
    fi
  } | awk '!seen[$0]++'
}

build_aur_package_list() {
  local files
  files=("$REPO_ROOT/packages/aur-minimal.txt")

  if [ "$WITH_EXTRAS" -eq 1 ]; then
    files+=("$REPO_ROOT/packages/aur-extra.txt")
  fi

  read_package_files "${files[@]}" | awk '!seen[$0]++'
}

bootstrap_paru() {
  local tmp_dir

  if command -v paru >/dev/null 2>&1; then
    return 0
  fi

  require_cmd git
  require_cmd makepkg

  info "paru is not installed; bootstrapping it from the AUR"
  tmp_dir="$(mktemp -d)"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] git clone %q %q\n' "https://aur.archlinux.org/paru.git" "$tmp_dir/paru"
    printf '[dry-run] (cd %q && makepkg -si --needed)\n' "$tmp_dir/paru"
    rm -rf "$tmp_dir"
    return 0
  fi

  git clone https://aur.archlinux.org/paru.git "$tmp_dir/paru"
  (
    cd "$tmp_dir/paru"
    makepkg -si --needed
  )
  rm -rf "$tmp_dir"
}

install_official_packages() {
  if [ "$INSTALL_OFFICIAL" -eq 0 ]; then
    info "Skipping official packages"
    return 0
  fi

  if [ "${#OFFICIAL_PACKAGES[@]}" -eq 0 ]; then
    warn "No official packages selected"
    return 0
  fi

  info "Installing official packages with pacman"
  run sudo pacman -Syu --needed "${OFFICIAL_PACKAGES[@]}"
}

install_aur_packages() {
  if [ "$INSTALL_AUR" -eq 0 ]; then
    info "Skipping AUR packages"
    return 0
  fi

  if [ "${#AUR_PACKAGES[@]}" -eq 0 ]; then
    info "No AUR packages selected"
    return 0
  fi

  bootstrap_paru

  info "Installing AUR packages with paru"
  run paru -S --needed "${AUR_PACKAGES[@]}"
}

deploy_home_dotfiles() {
  if [ "$DEPLOY_HOME" -eq 0 ]; then
    info "Skipping home dotfiles deployment"
    return 0
  fi

  info "Deploying tracked user dotfiles into \$HOME"
  if [ "$DRY_RUN" -eq 1 ]; then
    run "$REPO_ROOT/scripts/deploy-home.sh" --dry-run
  else
    run "$REPO_ROOT/scripts/deploy-home.sh"
  fi
}

apply_system_configs() {
  if [ "$APPLY_SYSTEM" -eq 0 ]; then
    info "Skipping tracked system files"
    return 0
  fi

  if [ ! -d "$REPO_ROOT/system" ]; then
    warn "No tracked system directory found"
    return 0
  fi

  info "Copying tracked system files from system/ into /"
  run sudo rsync -a "$REPO_ROOT/system/" /

  printf '\n'
  printf 'System files were copied, but services were not enabled automatically.\n'
  printf 'If you want greetd to be your display manager, review /etc/greetd/config.toml and then run:\n'
  printf '  sudo systemctl enable greetd.service\n'
}

enable_tracked_user_services() {
  local service

  if [ "$ENABLE_USER_SERVICES" -eq 0 ]; then
    info "Skipping user services"
    return 0
  fi

  info "Enabling tracked user services when available"

  if [ "$DRY_RUN" -eq 1 ]; then
    run systemctl --user daemon-reload
    run systemctl --user enable --now audio-sanity.service
    run systemctl --user enable --now hyprpolkitagent.service
    return 0
  fi

  if ! systemctl --user daemon-reload >/dev/null 2>&1; then
    warn "Could not talk to the user systemd instance. Run these later inside your user session:"
    warn "systemctl --user enable --now audio-sanity.service"
    warn "systemctl --user enable --now hyprpolkitagent.service"
    return 0
  fi

  for service in audio-sanity.service hyprpolkitagent.service; do
    if systemctl --user list-unit-files "$service" --no-legend 2>/dev/null | grep -q "^$service "; then
      if ! systemctl --user enable --now "$service"; then
        warn "Could not enable user service: $service"
      fi
    else
      warn "Skipping missing user service: $service"
    fi
  done
}

print_plan() {
  if [ "$WITH_EXTRAS" -eq 1 ]; then
    info "Package set: minimal + nice-to-have extras"
  else
    info "Package set: bare minimum only"
  fi
  info "CPU profile: $CPU_PROFILE"
  info "GPU profile: $GPU_PROFILE"
  info "Official packages: ${#OFFICIAL_PACKAGES[@]}"
  info "AUR packages: ${#AUR_PACKAGES[@]}"
  info "Apply tracked system files: $APPLY_SYSTEM"
}

main() {
  parse_args "$@"
  ensure_arch
  ensure_regular_user
  require_cmd awk
  require_cmd rsync
  require_cmd sed
  require_cmd sudo
  require_cmd pacman

  CPU_PROFILE="$(detect_cpu_profile)"
  GPU_PROFILE="$(detect_gpu_profile)"

  mapfile -t OFFICIAL_PACKAGES < <(build_official_package_list)
  mapfile -t AUR_PACKAGES < <(build_aur_package_list)

  print_plan
  install_official_packages
  install_aur_packages
  deploy_home_dotfiles
  apply_system_configs
  enable_tracked_user_services

  printf '\nDone.\n'
  printf 'If this is a fresh install, the usual next step is to log out or reboot.\n'
}

main "$@"

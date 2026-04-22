# Dotfiles

My personal Arch Linux + Hyprland setup.

This repo tracks user dotfiles, package lists, one optional `greetd` config, wallpaper assets, and helper scripts for syncing and deployment.

## Preview

### Desktop
![Hyprland desktop 1](assets/screenshots/hypr1.png)
![Hyprland desktop 2](assets/screenshots/hypr2.png)
![Hyprland desktop 3](assets/screenshots/hypr3.png)

## What Is In The Repo

- Hyprland
- Waybar
- Foot
- Fastfetch
- Yazi
- Helix
- Micro
- Cava
- Wlogout
- Zathura
- Btop
- Rustfmt
- LACT portable UI defaults
- PupGUI
- Spotatui
- TradingView Desktop flags for remote debugging / MCP tooling
- Bash config
- User systemd services
- Optional `greetd` config in `system/`
- Package lists
- Wallpaper and helper scripts

## What Is Not In The Repo

- bootloader config
- partitioning / disk setup
- user creation
- secrets, tokens, caches, or machine-specific runtime junk

## Quick Install

If you want the simplest path on a fresh Arch install, use the installer script.

```bash
git clone https://github.com/Xlerq/dotfiles.git
cd dotfiles
./scripts/install-arch.sh --dry-run
./scripts/install-arch.sh
```

Important notes:

- Run the installer as your normal user, not as `root`.
- The script is meant for Arch Linux.
- By default it installs packages, deploys dotfiles into `$HOME`, and tries to enable the tracked user services.
- It does not touch system files unless you explicitly pass `--apply-system`.

If auto-detection guesses the wrong hardware profile, override it explicitly:

```bash
./scripts/install-arch.sh --cpu intel --gpu nvidia
./scripts/install-arch.sh --cpu amd --gpu amd
./scripts/install-arch.sh --cpu none --gpu none
```

If you also want the tracked `greetd` config copied into `/etc`, use:

```bash
./scripts/install-arch.sh --apply-system
```

That copies `system/` into `/` with `sudo`. Review those files before using it.

## What The Installer Does

`scripts/install-arch.sh` does the following:

1. Detects your CPU and GPU profile, unless you override it.
2. Installs official packages from:
   - `packages/official.txt`
   - `packages/cpu-intel.txt` or `packages/cpu-amd.txt`
   - `packages/gpu-amd.txt` or `packages/gpu-nvidia.txt`
3. Bootstraps `paru` if it is missing, then installs AUR packages from `packages/aur.txt`.
4. Runs `scripts/deploy-home.sh` to copy tracked user dotfiles into `$HOME`.
5. Optionally copies tracked system files from `system/` into `/`.
6. Tries to enable:
   - `audio-sanity.service`
   - `hyprpolkitagent.service`

For hybrid Intel + Nvidia systems, the installer automatically adds `vulkan-intel`.

## Manual Deploy

If you do not want the full installer, you can deploy only the user dotfiles:

```bash
./scripts/deploy-home.sh --dry-run
./scripts/deploy-home.sh
```

This script:

- copies the tracked user config into `$HOME`
- renders `@HOME@` placeholders in files that need your local home path
- installs the wallpaper used by `hyprpaper`

If `systemctl --user` is not available at install time, enable the user services later inside your user session:

```bash
systemctl --user enable --now audio-sanity.service
systemctl --user enable --now hyprpolkitagent.service
```

## Sync From Current Machine

To refresh the repo from the current machine state, run:

```bash
./scripts/sync-home.sh
```

The sync step keeps some files portable on purpose:

- `hypr/.config/hypr/monitor.conf` is rewritten to a generic monitor auto-detect layout.
- `hypr/.config/hypr/hyprpaper.conf` and `pupgui/.config/pupgui/config.ini` render `$HOME` as `@HOME@`.
- `lact/.config/lact/ui.yaml` drops machine-specific GPU IDs and plot bindings.
- `tradingview/.config/tradingview-flags.conf` is copied only if it exists locally.

## Package Lists

Base packages live in:

- `packages/official.txt`
- `packages/aur.txt`

Hardware-specific splits live in:

- `packages/cpu-intel.txt`
- `packages/cpu-amd.txt`
- `packages/gpu-amd.txt`
- `packages/gpu-nvidia.txt`

The installer script is the preferred way to consume these lists because it handles detection and `paru` bootstrapping for you.

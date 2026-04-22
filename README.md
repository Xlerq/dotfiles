# Dotfiles

My personal Arch Linux + Hyprland setup.

This repo tracks user dotfiles, split package lists, one optional `greetd` config, wallpaper assets, and helper scripts for syncing and deployment.

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

## Package Philosophy

The package lists are split into two layers:

- `bare minimum`: what I consider enough to boot into the Hyprland setup, get audio, notifications, terminal, Waybar, and the core user environment working
- `nice-to-have extras`: apps, gaming tools, dev tooling, browsers, media tools, and other convenience packages

The goal is that a fresh install can start from the minimum set and only add the extra layer if wanted.

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
- By default it installs the bare minimum package set, deploys dotfiles into `$HOME`, and tries to enable the tracked user services.
- It does not touch system files unless you explicitly pass `--apply-system`.
- It does not install the nice-to-have extras unless you explicitly pass `--with-extras`.

If you want the full setup, including browsers, gaming tools, media tools, and dev extras:

```bash
./scripts/install-arch.sh --with-extras
```

If auto-detection guesses the wrong hardware profile, override it explicitly:

```bash
./scripts/install-arch.sh --cpu intel --gpu nvidia
./scripts/install-arch.sh --cpu amd --gpu amd
./scripts/install-arch.sh --cpu none --gpu none
./scripts/install-arch.sh --with-extras --cpu intel --gpu nvidia
```

If you also want the tracked `greetd` config copied into `/etc`, use:

```bash
./scripts/install-arch.sh --apply-system
```

That copies `system/` into `/` with `sudo`. Review those files before using it.

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

Bare-minimum package lists live in:

- `packages/official-minimal.txt`
- `packages/aur-minimal.txt`

Nice-to-have extras live in:

- `packages/official-extra.txt`
- `packages/aur-extra.txt`

Hardware-specific splits live in:

- `packages/cpu-intel.txt`
- `packages/cpu-amd.txt`
- `packages/gpu-amd.txt`
- `packages/gpu-nvidia.txt`

The installer script is the preferred way to consume these lists because it handles detection and `paru` bootstrapping for you.

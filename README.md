# Dotfiles

My personal Arch Linux + Hyprland setup.

This repo tracks user dotfiles, split package lists, one optional `greetd` config, wallpaper assets, and helper scripts for syncing and deployment.
It is intended to be portable across fresh Arch installs, with hardware-specific package splits selected by auto-detection or explicit flags.

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
- PupGUI
- Spotatui
- Bash config
- User systemd services
- Optional `greetd` config in `system/`
- Package lists
- Wallpaper and helper scripts

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
- Existing dotfiles are backed up under `~/.dotfiles-backups/` before deployment overwrites them.
- It does not touch system files unless you explicitly pass `--apply-system`.
- It does not install the nice-to-have extras unless you explicitly pass `--with-extras`.
- The full extras set includes Steam/lib32 packages. The installer checks for the Arch `[multilib]` repository and prints a clear error if it is missing.

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

## Sync From Current Machine

To refresh the repo from the current machine state, run:

```bash
./scripts/sync-home.sh
```

The sync step keeps some files portable on purpose:

- `hypr/.config/hypr/monitor.conf` and `hypr/.config/hypr/lua/monitor.lua` are rewritten to a generic preferred-resolution, auto-position monitor layout.
- `hypr/.config/hypr/hyprpaper.conf` and `pupgui/.config/pupgui/config.ini` render `$HOME` as `@HOME@`.
- On AMD GPU machines, `lact/.config/lact/ui.yaml` is synced without machine-specific GPU IDs and plot bindings.

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

The installer script is the preferred way to consume these lists because it handles hardware detection and `paru` bootstrapping for you.

On hybrid Intel + NVIDIA systems, the installer also adds `vulkan-intel` and `nvidia-prime`; with `--with-extras` it adds the matching lib32 Vulkan/NVIDIA packages for Steam/Proton.

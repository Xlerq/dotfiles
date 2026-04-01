# Dotfiles

My personal Arch Linux + Hyprland setup.

This repository contains my user configs, scripts, package lists, wallpaper, and selected system configuration used to recreate my desktop after a fresh install.

## Preview

### Desktop
![Hyprland desktop 1](assets/screenshots/hypr1.png)
![Hyprland desktop 2](assets/screenshots/hypr2.png)
![Hyprland desktop 3](assets/screenshots/hypr3.png)

## Included

- Hyprland
- Waybar
- Foot
- Fastfetch
- Yazi
- Helix
- Cava
- Wlogout
- Zathura
- Btop
- Rustfmt
- Bash aliases and shell config
- User systemd services
- greetd config
- GRUB config
- package lists

## Sync

To refresh the tracked configs from the current machine state, run:

```bash
./scripts/sync-home.sh
```

## Deploy

To install the tracked user dotfiles onto a fresh machine, run:

```bash
./scripts/deploy-home.sh
```

This copies the user config into `$HOME`, installs the wallpaper used by `hyprpaper`, and renders `@HOME@` placeholders to the current username/home path.

## Packages

Base packages live in `packages/official.txt` and `packages/aur.txt`.

Hardware-specific lists are split out so the same repo works on different machines:

- `packages/cpu-intel.txt`
- `packages/cpu-amd.txt`
- `packages/gpu-amd.txt`
- `packages/gpu-nvidia.txt`

For the laptop setup discussed here, the usual combination is:

```bash
sudo pacman -S --needed $(grep -hvE '^(#|$)' packages/official.txt packages/cpu-intel.txt packages/gpu-nvidia.txt)
paru -S --needed $(grep -hvE '^(#|$)' packages/aur.txt)
```

If the laptop is hybrid Intel + Nvidia and you need Vulkan on the Intel iGPU too, add `vulkan-intel`.

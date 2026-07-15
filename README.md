# Dotfiles

Personal Arch Linux + Hyprland configuration with safe HOME backups and separate device/display profiles.

## Preview

![Hyprland desktop](assets/screenshots/hypr1.png)
![Hyprland dashboard](assets/screenshots/hypr2.png)
![Hyprland applications](assets/screenshots/hypr3.png)

## Quick Start

```bash
git clone https://github.com/Xlerq/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

./dotfiles install --dry-run
./dotfiles install
```

Prerequisite: an Arch Linux user account with working `sudo` access (`git` is needed for the clone). The default package step installs `rsync` before HOME deployment.

On a fresh HOME, the default install uses the minimal package lists, detects CPU/GPU and laptop/desktop automatically, applies the safe `generic` display layout, and backs up replaced HOME files. A previously saved profile selection is reused.

The installer also enables `audio-sanity.service` (masks/stops PulseAudio and restarts PipeWire) and `hyprpolkitagent.service` when available. Use `--skip-user-services` to leave user services unchanged.

For this repository's AOC 1440p + Samsung 1080p desktop layout:

```bash
./dotfiles install --device desktop --display desktop-dual
```

Add `--with-extras` to install GUI applications, development tools, gaming packages, and Zed:

```bash
./dotfiles install --with-extras
```

## Everyday Use

| Direction | Preview | Apply |
|---|---|---|
| Repository → HOME | `./dotfiles apply --dry-run` | `./dotfiles apply` |
| HOME → repository | `./dotfiles capture --dry-run` | `./dotfiles capture` |

A real `capture` requires a Git worktree and refuses to run when it is dirty; its dry-run only warns. Commit/stash existing changes first; `--force` is available for intentional exceptions. Capture updates the common files and only the selected device/display profiles, so pass explicit profile flags when capturing on another machine.

Compatibility wrappers remain available:

```bash
./scripts/deploy-home.sh  # same as: ./dotfiles apply
./scripts/sync-home.sh    # same as: ./dotfiles capture
```

List the common tracked HOME components (profile overlays are listed separately by `profiles`):

```bash
./dotfiles list
```

## Profiles

Profiles have two independent axes, applied in this order:

```text
common dotfiles → device profile → display profile
```

Device profiles:

- `desktop`: enables the Spotatui/Cava dashboard (installed with `--with-extras`) and keeps the full Waybar status set.
- `laptop`: skips the dashboard, adds a battery module, and avoids the continuously polled system-info module.

Display profiles:

- `generic`: `preferred` resolution, automatic position and scale; safe for unknown displays and laptops.
- `desktop-dual`: AOC `2560×1440@155` with Waybar plus Samsung `1920×1080@60` on the left; monitors are matched by description rather than unstable connector numbers.

Choose profiles explicitly when needed:

```bash
./dotfiles apply --device laptop --display generic
./dotfiles apply --device desktop --display desktop-dual
```

The last applied selection is stored under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/selection`, so later `apply` and `capture` commands do not need repeated flags. See the saved selection (or `auto` before the first apply) with:

```bash
./dotfiles profiles
```

Dashboard windows and the power menu scale from the active monitor geometry, so a new resolution normally does not need another profile. Add a display profile only for a real layout that needs different outputs, scale, refresh rate, or monitor positions. Copy `profiles/display/generic/`, inspect identifiers with `hyprctl monitors all`, then edit its `monitor.lua` and Waybar `display.jsonc`. Hyprland expects `desc:MAKE MODEL SERIAL`; Waybar uses the same description without `desc:`. An empty Waybar object (`{}`) shows bars on all outputs, while `"output"` restricts it to one.

## Safety

- `--dry-run` does not modify HOME or the repository.
- By default, real `apply` operations back up replaced/deleted HOME files under `~/.dotfiles-backups/<timestamp>/`.
- Only explicitly listed legacy files are removed; deployment never performs a global `--delete` against HOME.
- `capture` first builds a temporary snapshot, excludes ignored/private filenames, checks changed text files for secret-like assignments, and only then updates the repository. It never deletes repository files automatically; a failed update restores the original managed files and keeps a recovery snapshot.
- Spotatui secret-like fields are reset during capture, its local file remains private (`0600`), HOME paths become `@HOME@`, and Zed runtime data is never captured.
- Machine-specific LACT GPU identifiers and transient systemd/Micro state are filtered.

## Installer Options

The installer remains Arch-specific and never applies `system/` unless requested:

```bash
./dotfiles install --with-extras
./dotfiles install --cpu intel --gpu nvidia
./dotfiles install --apply-system
./dotfiles install --help
```

On a fresh system, `--skip-aur` also omits `wlogout`, so the Waybar power button will not open its menu.

Package sets live in `packages/`:

- `official-minimal.txt` / `aur-minimal.txt`
- `official-extra.txt` / `aur-extra.txt`
- CPU/GPU-specific lists

## Repository Layout

- `manifest/home-items.tsv` — common HOME mappings and capture policies.
- `profiles/device/` — laptop/desktop behavior overlays.
- `profiles/display/` — monitor layout overlays.
- application directories (`hypr/`, `waybar/`, `zed/`, etc.) — common configuration.
- `scripts/dotfiles.sh` — implementation behind the public `./dotfiles` command.
- `scripts/install-arch.sh` — package/system installer.

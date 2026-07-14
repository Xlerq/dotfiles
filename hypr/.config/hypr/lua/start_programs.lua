hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'uwsm finalize WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE || dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; systemctl --user start xdg-desktop-portal.service'")

    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hyprlauncher -d")
    hl.exec_cmd("hypridle")

    hl.exec_cmd("sh -lc 'command -v foot >/dev/null 2>&1 && command -v spotatui >/dev/null 2>&1 && exec foot -a spotatui -T spotatui -e spotatui'", { workspace = "1 silent" })
    hl.exec_cmd("sh -lc 'command -v foot >/dev/null 2>&1 && command -v cava >/dev/null 2>&1 && exec foot -a cava -T cava -e cava'", { workspace = "1 silent" })
end)

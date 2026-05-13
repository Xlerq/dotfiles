hl.config({
    input = {
        kb_layout = "pl",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,
        accel_profile = "flat",
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("HYPRCURSOR_THEME", "DeppinDark-cursors")
hl.env("HYPRCURSOR_SIZE", "32")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor DeppinDark-cursors 32")
end)

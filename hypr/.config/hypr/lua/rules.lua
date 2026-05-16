hl.window_rule({
    match = { class = "^(foot)$" },
    opacity = "1.00 0.95",
})

hl.window_rule({
    name = "dash-spotatui",
    match = { class = "^(spotatui)$" },
    workspace = "1 silent",
    float = true,
    size = "1267 850",
    move = "9 58",
})

hl.window_rule({
    name = "dash-cava",
    match = { class = "^(cava)$" },
    workspace = "1 silent",
    float = true,
    size = "734 379",
    move = "1170 677",
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    match = { class = "^(foot)$" },
    opacity = "1.00 0.95",
})

hl.window_rule({
    name = "dash-spotatui",
    match = { class = "^(spotatui)$" },
    workspace = "1 silent",
    float = true,
    size = { "monitor_w*0.586", "monitor_h*0.66" },
    move = { "monitor_w*0.016", "monitor_h*0.059" },
})

hl.window_rule({
    name = "dash-cava",
    match = { class = "^(cava)$" },
    workspace = "1 silent",
    float = true,
    size = { "monitor_w*0.43", "monitor_h*0.36" },
    move = { "monitor_w-window_w-40", "monitor_h-window_h-70" },
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
    move = { 20, "monitor_h-120" },
    float = true,
})

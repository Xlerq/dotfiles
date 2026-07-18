#!/bin/sh

if hyprctl layers | grep -q 'namespace: hyprlauncher'; then
    hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "", key = "Escape" })'
fi

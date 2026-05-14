#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pidfile="$runtime_dir/waybar-calendar.pid"
lockfile="$runtime_dir/waybar-calendar.lock"

exec 9>"$lockfile"
flock -n 9 || exit 0

if [[ -s "$pidfile" ]]; then
    pid="$(<"$pidfile")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for _ in 1 2 3 4 5; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.05
        done
        kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
        rm -f "$pidfile"
        exit 0
    fi
    rm -f "$pidfile"
fi

if ! command -v zenity >/dev/null 2>&1; then
    notify-send -t 8000 "Calendar" "$(cal -m)"
    exit 0
fi

day="$(date +%d)"
month="$(date +%m)"
year="$(date +%Y)"

GDK_BACKEND=wayland zenity \
    --calendar \
    --title="Calendar" \
    --text="$(date +'%A, %d %B %Y')" \
    --day="$((10#$day))" \
    --month="$((10#$month))" \
    --year="$year" \
    --date-format="%Y-%m-%d" \
    >/dev/null 2>&1 &

printf '%s\n' "$!" > "$pidfile"

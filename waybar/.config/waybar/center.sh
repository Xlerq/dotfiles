#!/usr/bin/env bash

trap 'kill $(jobs -p) 2>/dev/null; exit 0' SIGPIPE SIGTERM EXIT

HOUR=$(date +"%H:%M")

# Muzyka – bardzo ostrożne czyszczenie i escaping
RAW_MUSIC=$(playerctl metadata --format '{{title}} - {{artist}}' 2>/dev/null || echo "Nic nie gra")
MUSIC=$(printf '%s' "$RAW_MUSIC" | tr -d '\000-\037\177' | sed 's/"/\\"/g; s/\\/\\\\/g; s/$/\\n/' | tr -d '\n')

# Tooltip – tylko kalendarz + muzyka, bez cava
TOOLTIP="<big>$(date +'%A, %d %B %Y')</big>\\n\\n"
TOOLTIP+="<span foreground='#ffcc80' weight='bold'>♪ Teraz gra:</span>\\n${MUSIC:-Nic nie gra}"

printf '{"text": "%s", "tooltip": "%s", "class": "center"}\n' "$HOUR" "$TOOLTIP"

exit 0

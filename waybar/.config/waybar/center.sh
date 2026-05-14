#!/usr/bin/env bash
set -euo pipefail

hour="$(date +"%H:%M")"
today="$(date +'%A, %d %B %Y')"
music="Nic nie gra"

if command -v playerctl >/dev/null 2>&1; then
    if raw_music="$(timeout 0.25s playerctl metadata --format '{{title}} - {{artist}}' 2>/dev/null)" && [[ -n "$raw_music" ]]; then
        music="$(printf '%s' "$raw_music" | tr -d '\000-\037\177')"
    fi
fi

tooltip="<big>${today}</big>

<span foreground='#ffcc80' weight='bold'>♪ Teraz gra:</span>
${music}"

jq -cn \
    --arg text "$hour" \
    --arg tooltip "$tooltip" \
    --arg class "center" \
    '{text: $text, tooltip: $tooltip, class: $class}'

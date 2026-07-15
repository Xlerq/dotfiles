#!/usr/bin/env bash

set -euo pipefail

args=(-b 2 -c 10 -r 10 -n)
output="${WAYBAR_OUTPUT_NAME:-}"

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  geometry="$(
    hyprctl monitors -j 2>/dev/null | jq -r --arg output "$output" '
      to_entries
      | ([.[] | select(.value.name == $output)][0]
        // [.[] | select(.value.focused == true)][0]
        // .[0]) as $entry
      | if $entry == null then
          empty
        else
          [
            (($entry.value.width / $entry.value.scale) | floor),
            (($entry.value.height / $entry.value.scale) | floor),
            $entry.key
          ]
          | @tsv
        end
    '
  )" || geometry=""

  if IFS=$'\t' read -r width height monitor_index <<< "$geometry" \
    && [[ "$width" =~ ^[0-9]+$ ]] \
    && [[ "$height" =~ ^[0-9]+$ ]] \
    && [[ "$monitor_index" =~ ^[0-9]+$ ]]; then
    margin_x=$((width * 30 / 100))
    margin_y=$((height * 19 / 100))
    exec wlogout "${args[@]}" \
      -L "$margin_x" -R "$margin_x" \
      -T "$margin_y" -B "$margin_y" \
      -P "$monitor_index"
  fi
fi

exec wlogout "${args[@]}"

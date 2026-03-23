#!/usr/bin/env bash

cat \
  "$HOME/.config/waybar/style-main.css" \
  "$HOME/.config/waybar/style-left.css" \
  "$HOME/.config/waybar/style-center.css" \
  "$HOME/.config/waybar/style-right.css" \
  > "$HOME/.config/waybar/style.css"

echo "Style.css odświeżony"

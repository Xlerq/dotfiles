#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"

get_backlight_brightness() {
	brightnessctl get 2>/dev/null || true
}

get_ddc_brightness() {
	ddcutil getvcp 10 --brief 2>/dev/null | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1
}

CURRENT="$(get_backlight_brightness)"
if [[ "${CURRENT:-}" =~ ^[0-9]+$ ]]; then
	printf 'brightnessctl:%s\n' "$CURRENT" >"$STATE_FILE"
	brightnessctl set 5% >/dev/null 2>&1 || true
	exit 0
fi

CURRENT="$(get_ddc_brightness)"
if [[ "${CURRENT:-}" =~ ^[0-9]+$ ]]; then
	printf 'ddcutil:%s\n' "$CURRENT" >"$STATE_FILE"
	ddcutil setvcp 10 1 >/dev/null 2>&1 || true
fi

#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"
FALLBACK_BRIGHTNESS="30"
BACKEND="ddcutil"

# mały delay, bo po resume monitor bywa jeszcze niegotowy
sleep 2

if [ -f "$STATE_FILE" ]; then
	STATE="$(cat "$STATE_FILE" 2>/dev/null || true)"
else
	STATE=""
fi

if [[ "$STATE" == *:* ]]; then
	BACKEND="${STATE%%:*}"
	BRIGHTNESS="${STATE#*:}"
else
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

if ! [[ "${BRIGHTNESS:-}" =~ ^[0-9]+$ ]]; then
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

case "$BACKEND" in
brightnessctl)
	if brightnessctl set "$BRIGHTNESS" >/dev/null 2>&1; then
		rm -f "$STATE_FILE"
		exit 0
	fi
	;;
*)
	for _ in 1 2 3 4 5; do
		if ddcutil setvcp 10 "$BRIGHTNESS" >/dev/null 2>&1; then
			rm -f "$STATE_FILE"
			exit 0
		fi
		sleep 1
	done
	;;
esac

exit 1

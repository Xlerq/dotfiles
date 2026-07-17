#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypridle-monitor-brightness-$UID"

# mały delay, bo po resume monitor bywa jeszcze niegotowy
sleep 2

[ -f "$STATE_FILE" ] || exit 0
STATE="$(<"$STATE_FILE")"
BACKEND="${STATE%%:*}"
BRIGHTNESS="${STATE#*:}"

if [[ "$STATE" != *:* ]] || ! [[ "$BRIGHTNESS" =~ ^[0-9]+$ ]]; then
	rm -f "$STATE_FILE"
	exit 0
fi

case "$BACKEND" in
brightnessctl)
	for _ in 1 2 3 4 5; do
		if brightnessctl set "$BRIGHTNESS" >/dev/null 2>&1; then
			rm -f "$STATE_FILE"
			exit 0
		fi
		sleep 1
	done
	;;
ddcutil)
	for _ in 1 2 3 4 5; do
		if ddcutil setvcp 10 "$BRIGHTNESS" >/dev/null 2>&1; then
			rm -f "$STATE_FILE"
			exit 0
		fi
		sleep 1
	done
	;;
*)
	rm -f "$STATE_FILE"
	exit 0
	;;
esac

exit 1

#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"
FALLBACK_BRIGHTNESS="30"

# mały delay, bo po resume monitor bywa jeszcze niegotowy
sleep 2

if [ -f "$STATE_FILE" ]; then
	BRIGHTNESS="$(cat "$STATE_FILE" 2>/dev/null || true)"
else
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

# sanity check
if ! [[ "${BRIGHTNESS:-}" =~ ^[0-9]+$ ]]; then
	BRIGHTNESS="$FALLBACK_BRIGHTNESS"
fi

# kilka prób, bo DDC/CI po wybudzeniu często działa z opóźnieniem
for _ in 1 2 3 4 5; do
	if ddcutil setvcp 10 "$BRIGHTNESS" >/dev/null 2>&1; then
		rm -f "$STATE_FILE"
		exit 0
	fi
	sleep 1
done

exit 1

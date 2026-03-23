#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/hypridle-monitor-brightness"

# spróbuj odczytać obecną jasność
CURRENT="$(ddcutil getvcp 10 --brief 2>/dev/null | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -n1)"

if [[ "${CURRENT:-}" =~ ^[0-9]+$ ]]; then
	printf '%s\n' "$CURRENT" >"$STATE_FILE"
fi

# minimum sensowne
ddcutil setvcp 10 1

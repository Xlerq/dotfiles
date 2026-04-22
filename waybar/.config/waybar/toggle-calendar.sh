#!/usr/bin/env bash
set -euo pipefail

if ! command -v gsimplecal >/dev/null 2>&1; then
	exit 0
fi

if pgrep -x gsimplecal >/dev/null 2>&1; then
	pkill -x gsimplecal
else
	# prosto: odpal i zamknij drugim kliknięciem
	GDK_BACKEND=wayland gsimplecal &
fi

#!/usr/bin/env bash
set -euo pipefail

get_ddc_brightness() {
	ddcutil getvcp 10 --terse 2>/dev/null | awk 'NR==1 {print $(NF-1)}'
}

set_ddc_brightness() {
	ddcutil setvcp 10 "$1" >/dev/null 2>&1 || true
}

get_backlight_percent() {
	local current max

	current="$(brightnessctl get 2>/dev/null || true)"
	max="$(brightnessctl max 2>/dev/null || true)"

	if [[ ! "$current" =~ ^[0-9]+$ || ! "$max" =~ ^[0-9]+$ || "$max" -le 0 ]]; then
		return 1
	fi

	printf '%s\n' "$((current * 100 / max))"
}

set_backlight_percent() {
	brightnessctl set "$1%" >/dev/null 2>&1 || true
}

detect_backend() {
	local ddc

	ddc="$(get_ddc_brightness || true)"
	if [[ "$ddc" =~ ^[0-9]+$ ]]; then
		printf 'ddc\n'
		return 0
	fi

	if get_backlight_percent >/dev/null 2>&1; then
		printf 'backlight\n'
		return 0
	fi

	printf 'none\n'
}

get_brightness() {
	case "$(detect_backend)" in
	ddc)
		get_ddc_brightness
		;;
	backlight)
		get_backlight_percent
		;;
	*)
		return 1
		;;
	esac
}

set_brightness() {
	local cur new
	cur="$(get_brightness)"
	cur="${cur:-30}"

	case "${1:-}" in
	up)
		new=$((cur + 5))
		[ "$new" -gt 100 ] && new=100
		;;
	down)
		new=$((cur - 5))
		[ "$new" -lt 1 ] && new=1
		;;
	*)
		new="$cur"
		;;
	esac

	case "$(detect_backend)" in
	ddc)
		set_ddc_brightness "$new"
		;;
	backlight)
		set_backlight_percent "$new"
		;;
	esac
}

case "${1:-}" in
up | down)
	set_brightness "$1"
	;;
esac

cur="$(get_brightness)"
if [[ -z "${cur:-}" || ! "$cur" =~ ^[0-9]+$ ]]; then
	printf '{"text":"󰃟 ?","tooltip":"Nie udało się odczytać jasności ekranu","class":"brightness"}\n'
else
	printf '{"text":"󰃟 %s%%","tooltip":"Jasność ekranu: %s%%","class":"brightness"}\n' "$cur" "$cur"
fi

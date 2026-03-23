#!/usr/bin/env bash
set -euo pipefail

get_brightness() {
	# --terse jest bardziej przewidywalne do parsowania
	ddcutil getvcp 10 --terse 2>/dev/null | awk 'NR==1 {print $(NF-1)}'
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

	ddcutil setvcp 10 "$new" >/dev/null 2>&1 || true
}

case "${1:-}" in
up | down)
	set_brightness "$1"
	;;
esac

cur="$(get_brightness)"
if [[ -z "${cur:-}" || ! "$cur" =~ ^[0-9]+$ ]]; then
	printf '{"text":"󰃟 ?","tooltip":"Nie udało się odczytać jasności monitora","class":"brightness"}\n'
else
	printf '{"text":"󰃟 %s%%","tooltip":"Jasność monitora: %s%%","class":"brightness"}\n' "$cur" "$cur"
fi

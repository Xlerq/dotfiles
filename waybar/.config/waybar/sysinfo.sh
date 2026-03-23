#!/usr/bin/env bash
set -euo pipefail

cpu_temp="$(
	sensors 2>/dev/null | awk '
    /Package id 0:/ {gsub(/[+°C]/,"",$4); print int($4); exit}
    /Tctl:/        {gsub(/[+°C]/,"",$2); print int($2); exit}
    /CPU:/ && /\+/ {gsub(/[+°C]/,"",$2); print int($2); exit}
  ' || true
)"
cpu_temp="${cpu_temp:-NA}"

gpu_temp="NA"
if command -v nvidia-smi >/dev/null 2>&1; then
	gpu_temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
	gpu_temp="${gpu_temp:-NA}"
else
	gpu_temp="$(
		sensors 2>/dev/null | awk '
      /edge:/ {gsub(/[+°C]/,"",$2); print int($2); exit}
    ' || true
	)"
	gpu_temp="${gpu_temp:-NA}"
fi

text=" ${cpu_temp}°  󰢮 ${gpu_temp}°"
tooltip="<big><b>Temperatury</b></big>\nCPU: ${cpu_temp}°\nGPU: ${gpu_temp}°\n\n<span foreground='#ffcc80'>Klik: btop</span>"

printf '{"text":"%s","tooltip":"%s","class":"sysinfo"}\n' "$text" "$tooltip"

#!/usr/bin/env bash
# Slow, careful capture: llvmpipe needs time to rasterise. Generous waits.
set -u
cd /home/dx401/celenium-miner
APP=./build/linux/x64/release/bundle/celenium_miner
OUT=/tmp/cen_baseline
mkdir -p "$OUT"

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

shot() {  # $1=name  $2=CEN_TAB
  pkill -9 -f 'release/bundle/celenium' 2>/dev/null
  sleep 1
  CEN_TAB="$2" "$APP" >/tmp/cen_run.log 2>&1 &
  local pid=$!
  sleep 9
  ffmpeg -y -f x11grab -video_size 1440x900 -i :99 -frames:v 1 \
    "$OUT/${1}_pre.png" >/dev/null 2>&1
  python3 scripts/xinput.py click 640 679
  sleep 6
  ffmpeg -y -f x11grab -video_size 1440x900 -i :99 -frames:v 1 \
    "$OUT/${1}.png" >/dev/null 2>&1
  sleep 2
  ffmpeg -y -f x11grab -video_size 1440x900 -i :99 -frames:v 1 \
    "$OUT/${1}_late.png" >/dev/null 2>&1
  kill -9 "$pid" 2>/dev/null
  sleep 0.4
}

shot mine mine
shot wallet wallet
shot profile profile

echo "DONE"
ls -la "$OUT" | grep -E 'mine|wallet|profile'
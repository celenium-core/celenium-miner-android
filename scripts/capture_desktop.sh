#!/usr/bin/env bash
# Baseline + iterate desktop screenshots: Xvfb :99 (1440x900 landscape), mock
# bridge on 3030, launch each tab via CEN_TAB, click through the splash, grab.
set -u
cd /home/dx401/celenium-miner
APP=./build/linux/x64/release/bundle/celenium_miner
OUT=/tmp/cen_baseline
mkdir -p "$OUT"

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

if ! pgrep -x Xvfb >/dev/null; then
  Xvfb :99 -screen 0 1440x900x24 >/tmp/xvfb.log 2>&1 &
  sleep 2
fi
if ! pgrep -f mock_bridge.py >/dev/null; then
  python3 scripts/mock_bridge.py 3030 >/tmp/mock_bridge.log 2>&1 &
  sleep 1
fi

shot() {  # $1=name  $2=CEN_TAB
  pkill -9 -f 'release/bundle/celenium' 2>/dev/null
  sleep 1
  CEN_TAB="$2" "$APP" >/tmp/cen_run.log 2>&1 &
  local pid=$!
  sleep 3.2
  ffmpeg -y -f x11grab -video_size 1440x900 -i :99 -frames:v 1 \
    "$OUT/${1}_splash.png" >/dev/null 2>&1
  python3 scripts/xinput.py click 720 859
  sleep 1.6
  ffmpeg -y -f x11grab -video_size 1440x900 -i :99 -frames:v 1 \
    "$OUT/${1}.png" >/dev/null 2>&1
  kill -9 "$pid" 2>/dev/null
  sleep 0.4
}

shot mine mine
shot wallet wallet
shot profile profile

echo "DONE"
ls -la "$OUT"
#!/usr/bin/env bash
# Capture the splash at several offsets from launch, then the settled screens.
set -u
cd "$HOME/celenium-miner" || exit 1
APP=./build/linux/x64/release/bundle/celenium_miner
OUT=/tmp/shots2
mkdir -p "$OUT"

pkill -9 -f 'release/bundle/celenium' 2>/dev/null
sleep 3

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

"$APP" > /tmp/fx_script.log 2>&1 &
PID=$!

# Frames every 0.25s from launch, so the narrow rain window is covered.
for i in $(seq 1 30); do
  ffmpeg -y -f x11grab -video_size 1400x1600 -i :99 -frames:v 1 \
    "$OUT/s_$i.png" > /dev/null 2>&1
  sleep 0.25
done

kill -9 "$PID" 2>/dev/null
wait "$PID" 2>/dev/null

# Report which frames are non-empty and their sizes, so the caller can pick.
for i in $(seq 1 30); do
  s=$(stat -c%s "$OUT/s_$i.png" 2>/dev/null || echo 0)
  echo "s_$i=$s"
done
echo "SCRIPT_DONE"

#!/usr/bin/env bash
# Build a self-contained Linux AppImage from a Flutter Linux release bundle.
# Usage: APPIMAGETOOL=/path/to/appimagetool bash scripts/package_appimage.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
APPIMAGETOOL="${APPIMAGETOOL:-/tmp/appimagetool.AppImage}"
APPDIR="$ROOT/build/CeleniumMiner.AppDir"
OUT="$ROOT/build/CeleniumMiner-x86_64.AppImage"

[ -d "$BUNDLE" ] || { echo "bundle missing, run: flutter build linux --release" >&2; exit 1; }

# main binary (the only top-level executable in the bundle root)
BIN="$(find "$BUNDLE" -maxdepth 1 -type f -executable | head -1)"
[ -n "$BIN" ] || { echo "no executable found in bundle" >&2; exit 1; }
BIN_NAME="$(basename "$BIN")"

rm -rf "$APPDIR" "$OUT"
mkdir -p "$APPDIR/usr/bin"

# Flutter resolves data/ and lib/ relative to the binary, keep them siblings.
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"

# Icon (512 png). Regenerate if missing.
ICON="$ROOT/build/celenium-miner.png"
[ -f "$ICON" ] || python3 - "$ICON" <<'PY'
import sys
from PIL import Image
im = Image.open("assets/logo/cen_mark_on_navy.jpg").convert("RGB").resize((512,512), Image.LANCZOS)
im.save(sys.argv[1])
PY
cp "$ICON" "$APPDIR/celenium-miner.png"

cat > "$APPDIR/celenium-miner.desktop" <<EOF
[Desktop Entry]
Name=Celenium Miner
Comment=Celenium pool-mining client
Exec=$BIN_NAME
Icon=celenium-miner
Type=Application
Categories=Utility;Network;
EOF

cat > "$APPDIR/AppRun" <<EOF
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/$BIN_NAME" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUT"
echo "AppImage written to: $OUT"
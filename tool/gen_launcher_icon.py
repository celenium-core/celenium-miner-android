#!/usr/bin/env python3
"""Resize the supplied CEN logo into the launcher icon PNGs Android expects.

The logo is the user's own artwork, so it is resized rather than redrawn:
nothing here interprets the shape, it only scales the source image into each
density bucket. Run with:
    python3 tool/gen_launcher_icon.py
"""

import os
from PIL import Image

# The mark on navy, which is the version that reads on a phone launcher.
SOURCE = "assets/logo/cen_mark_on_navy.jpg"

# Density bucket to pixel size, matching Android's launcher icon spec.
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def main():
    src = Image.open(SOURCE).convert("RGB")
    if src.size[0] != src.size[1]:
        raise SystemExit(f"source logo must be square, got {src.size}")

    root = "android/app/src/main/res"
    for bucket, px in SIZES.items():
        # LANCZOS keeps the petal edges clean when scaling down this far.
        icon = src.resize((px, px), Image.LANCZOS)
        d = os.path.join(root, bucket)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, "ic_launcher.png")
        icon.save(path, optimize=True)
        print(f"{bucket}/ic_launcher.png  {px}x{px}  {os.path.getsize(path)} bytes")

    store = os.path.join(root, "ic_launcher_playstore.png")
    src.resize((512, 512), Image.LANCZOS).save(store, optimize=True)
    print(f"ic_launcher_playstore.png  512x512  {os.path.getsize(store)} bytes")


if __name__ == "__main__":
    main()

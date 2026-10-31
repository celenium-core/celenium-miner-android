#!/usr/bin/env python3
"""Cut the supplied CEN logo free of its flat background.

The user's artwork ships on a solid field, navy in one file and cream in the
other. Inside the app the mark has to sit on whatever container is behind it,
so the field is removed here and the two transparent variants are written
beside the originals. The artwork itself is untouched: only the background
pixels are keyed out.

Run with:
    python3 tool/make_transparent_logo.py
"""

from collections import deque
from PIL import Image

# Source file -> (background colour, output file).
JOBS = [
    ("assets/logo/cen_mark_on_navy.jpg", (29, 34, 53), "assets/logo/cen_mark_for_dark.png"),
    ("assets/logo/cen_mark_on_cream.jpg", (245, 241, 232), "assets/logo/cen_mark_for_light.png"),
]

# JPEG ringing around a flat edge bleeds a few levels either side, so the
# tolerance has to be wide enough to catch it without eating the petal.
TOLERANCE = 26


def cut_background(src_path, bg, out_path):
    im = Image.open(src_path).convert("RGB")
    w, h = im.size
    px = im.load()

    def is_bg(p):
        return (
            abs(p[0] - bg[0]) <= TOLERANCE
            and abs(p[1] - bg[1]) <= TOLERANCE
            and abs(p[2] - bg[2]) <= TOLERANCE
        )

    # Flood from every edge pixel, so only the field connected to the border
    # is removed. Anything enclosed by the artwork survives.
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not seen[y][x] and is_bg(px[x, y]):
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y][x] and is_bg(px[x, y]):
                seen[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and is_bg(px[nx, ny]):
                seen[ny][nx] = True
                q.append((nx, ny))

    out = Image.new("RGBA", (w, h))
    op = out.load()
    removed = 0
    for y in range(h):
        for x in range(w):
            if seen[y][x]:
                op[x, y] = (0, 0, 0, 0)
                removed += 1
            else:
                r, g, b = px[x, y]
                op[x, y] = (r, g, b, 255)

    out.save(out_path, optimize=True)
    total = w * h
    print(f"{out_path}  {w}x{h}  background removed {removed}/{total} ({removed * 100 // total}%)")


def main():
    for src, bg, dst in JOBS:
        cut_background(src, bg, dst)


if __name__ == "__main__":
    main()

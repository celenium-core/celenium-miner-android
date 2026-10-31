#!/usr/bin/env python3
"""Render the CEN brand mark to the launcher icon PNGs Android expects.

The geometry mirrors lib/widgets/brand_mark_geometry.dart exactly, so the
launcher icon and the in-app mark stay identical. Run with:
    python3 tool/gen_launcher_icon.py
"""

import math
import os
from PIL import Image, ImageDraw

# Logo A from the reference pair: cream petals on a navy field, the version
# that reads on a phone launcher.
PETAL = (245, 240, 230)      # cream
DIAMOND = (31, 42, 74)       # navy
CORE = (200, 155, 60)        # gold
SPOKE = (31, 42, 74)         # navy
FIELD = (31, 42, 74)         # navy

# Density bucket to pixel size, matching Android's launcher icon spec.
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

INSET = 0.12


def cubic(p0, p1, p2, p3, steps=48):
    """Sample a cubic bezier, matching how Flutter flattens it."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def quad(p0, p1, p2, steps=24):
    """Sample a quadratic bezier."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def petal_outline(unit):
    """One petal in local coordinates, pointing up the -y axis."""
    bulb = unit * 0.92
    half_width = unit * 0.30
    notch = unit * 0.055
    inner = unit * 0.20 * 0.92

    pts = [(0.0, inner)]
    pts += cubic(
        (0.0, inner),
        (-half_width, inner * 0.35),
        (-half_width, -bulb * 0.86),
        (-half_width * 0.52, -bulb),
    )
    pts += quad((-half_width * 0.52, -bulb), (0.0, -bulb + notch), (half_width * 0.52, -bulb))
    pts += cubic(
        (half_width * 0.52, -bulb),
        (half_width, -bulb * 0.86),
        (half_width, inner * 0.35),
        (0.0, inner),
    )
    return pts


def render(px):
    """Draw the mark on a navy field at [px] square and return the image."""
    img = Image.new("RGB", (px, px), FIELD)
    draw = ImageDraw.Draw(img)

    side = px * (1 - INSET * 2)
    unit = side / 2
    cx = px / 2
    cy = px / 2

    # PIL's y axis points down; the geometry is written y-up, so flip.
    def to_px(p):
        return (cx + p[0], cy - p[1])

    def rot(p, angle):
        c, s = math.cos(angle), math.sin(angle)
        return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)

    core_radius = unit * 0.20
    bulb = unit * 0.92

    outline = petal_outline(unit)

    # Five petals, 72 degrees apart, one pointing straight up.
    for i in range(5):
        angle = -math.pi / 2 + i * (math.pi * 2 / 5)
        pts = [to_px(rot(p, angle)) for p in outline]
        draw.polygon(pts, fill=PETAL)

        # Diamond in the outer half of the petal, standing on its point.
        dr = unit * 0.085
        dc = rot((0.0, -bulb * 0.62), angle)
        dx, dy = to_px(dc)
        draw.polygon(
            [(dx, dy - dr), (dx + dr, dy), (dx, dy + dr), (dx - dr, dy)],
            fill=DIAMOND,
        )

    # Gold core, then the thin dark ring the reference carries around it.
    draw.ellipse(
        [cx - core_radius, cy - core_radius, cx + core_radius, cy + core_radius],
        fill=CORE,
    )
    ring_w = max(unit * 0.018, 0.6)
    draw.ellipse(
        [
            cx - core_radius,
            cy - core_radius,
            cx + core_radius,
            cy + core_radius,
        ],
        outline=SPOKE,
        width=max(1, int(round(ring_w))),
    )

    # Eight spokes, evenly spaced, reaching just past the core edge.
    spoke_len = core_radius * 1.22
    spoke_w = max(unit * 0.032, 1.0)
    for i in range(8):
        angle = i * math.pi / 4
        ex = cx + math.cos(angle) * spoke_len
        ey = cy - math.sin(angle) * spoke_len
        draw.line([(cx, cy), (ex, ey)], fill=SPOKE, width=max(1, int(round(spoke_w))))

    return img


def main():
    root = "android/app/src/main/res"
    for bucket, px in SIZES.items():
        d = os.path.join(root, bucket)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, "ic_launcher.png")
        render(px).save(path)
        print(f"{bucket}/ic_launcher.png  {px}x{px}  {os.path.getsize(path)} bytes")

    store = os.path.join(root, "ic_launcher_playstore.png")
    render(512).save(store)
    print(f"ic_launcher_playstore.png  512x512  {os.path.getsize(store)} bytes")


if __name__ == "__main__":
    main()

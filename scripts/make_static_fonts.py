"""Regenerate the four static test fonts from the app's two variable fonts.

Why: the flutter_test software renderer shows variable `[wght]` fonts as tofu
boxes in goldens. Tests load static instances (weights 400/700) instead, which
render real glyphs. Run this after updating either variable font in
assets/fonts/.

Usage:  uv run --with fonttools python scripts/make_static_fonts.py
"""
import os
from fontTools import ttLib
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(ROOT, "test", "support", "fonts")
os.makedirs(OUT, exist_ok=True)

# Tables that only make sense on a variable font; dropping them yields a clean
# static TTF the engine matches purely by OS/2 usWeightClass.
VAR_TABLES = ("fvar", "gvar", "avar", "STAT", "MVAR", "HVAR", "VVAR", "cvar")

JOBS = [
    ("Cinzel[wght].ttf", "Cinzel-Regular.ttf", 400),
    ("Cinzel[wght].ttf", "Cinzel-Bold.ttf", 700),
    ("JetBrainsMono[wght].ttf", "JetBrainsMono-Regular.ttf", 400),
    ("JetBrainsMono[wght].ttf", "JetBrainsMono-Bold.ttf", 700),
]

for src, dst, wght in JOBS:
    font = ttLib.TTFont(os.path.join(SRC, src))
    instantiateVariableFont(font, {"wght": wght}, inplace=True)
    font["OS/2"].usWeightClass = wght
    for tag in VAR_TABLES:
        if tag in font:
            del font[tag]
    out_path = os.path.join(OUT, dst)
    font.save(out_path)
    print(f"[OK] {dst} (weight {wght}, {os.path.getsize(out_path)} bytes)")
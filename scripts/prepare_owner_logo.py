#!/usr/bin/env python3
"""Generate the approved frame-only SH Owner art for Android and iOS.

The approved source retains the blue/green neon border and central leaf S.
Pixels outside that border are masked, not decorated with extra glow.
A separate opaque iOS asset satisfies App Store icon requirements.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets/brand"
SOURCE = BRAND / "sh-owner-frame-source.jpg"
SIZE = 1024

if not SOURCE.is_file():
    raise SystemExit("Approved SH Owner artwork missing: " + str(SOURCE))

artwork = Image.open(SOURCE).convert("RGB")
artwork = artwork.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

mask = Image.new("L", (SIZE, SIZE), 0)
pen = ImageDraw.Draw(mask)
pen.rounded_rectangle((6, 12, 1019, 1004), radius=232, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(1.5))

original = artwork.convert("RGBA")
original.putalpha(mask)
original.save(BRAND / "sh-owner-original.png", optimize=True)

adaptive = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
adaptive_size = 742
scaled = original.resize((adaptive_size, adaptive_size),
                         Image.Resampling.LANCZOS)
adaptive.alpha_composite(
    scaled, ((SIZE - adaptive_size) // 2, (SIZE - adaptive_size) // 2))
adaptive.save(BRAND / "sh-owner-adaptive.png", optimize=True)

ios = Image.new("RGB", (SIZE, SIZE), (4, 19, 35))
ios.paste(original, mask=original.getchannel("A"))
ios.save(BRAND / "sh-owner-ios.png", optimize=True)

print("SH Owner frame-only artwork generated: original, adaptive, iOS")

"""Renders the Cuevanta launcher icon for every platform.

Same geometry as lib/widgets/cuevanta_logo.dart (100x100 design box):
open gold ring r=34, stroke 5.5, gap of +/-38 degrees on the right, cue dot r=5.5.

Run from the project root:  python tool/generate_app_icons.py
"""
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

INK = (10, 13, 22)
GOLD_STOPS = [(0xEA, 0xD7, 0xAE), (0xCF, 0xB0, 0x7A), (0xA8, 0x86, 0x4F), (0xCF, 0xB0, 0x7A), (0xEA, 0xD7, 0xAE)]
MASTER_SIZE = 1024
SUPERSAMPLE = 4
MARK_SCALE = 0.66  # mark occupies 66% of the tile, inside adaptive/maskable safe zones

RING_RADIUS = 34
STROKE_WIDTH = 5.5
GAP_HALF_ANGLE = 38
DOT_RADIUS = 5.5
OPTICAL_SHIFT_X = -2.5  # recentres ring + dot as one shape


def gold_at(fraction):
    """Sweep-gradient colour at 0..1 around the circle."""
    position = fraction * (len(GOLD_STOPS) - 1)
    low = int(position)
    high = min(low + 1, len(GOLD_STOPS) - 1)
    t = position - low
    return tuple(round(a + (b - a) * t) for a, b in zip(GOLD_STOPS[low], GOLD_STOPS[high]))


def render_master():
    size = MASTER_SIZE * SUPERSAMPLE
    image = Image.new("RGB", (size, size), INK)
    draw = ImageDraw.Draw(image)
    unit = size * MARK_SCALE / 100
    center_y = size / 2
    center_x = size / 2 + OPTICAL_SHIFT_X * unit
    radius = RING_RADIUS * unit
    stroke = STROKE_WIDTH * unit

    start, end = GAP_HALF_ANGLE, 360 - GAP_HALF_ANGLE
    steps = 720
    for i in range(steps + 1):
        angle = start + (end - start) * i / steps
        x = center_x + radius * math.cos(math.radians(angle))
        y = center_y + radius * math.sin(math.radians(angle))
        r = stroke / 2
        draw.ellipse((x - r, y - r, x + r, y + r), fill=gold_at(angle / 360))

    dot = DOT_RADIUS * unit
    draw.ellipse((center_x + radius - dot, center_y - dot, center_x + radius + dot, center_y + dot), fill=GOLD_STOPS[0])
    return image.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)


def save_resized(master, path, pixels):
    path.parent.mkdir(parents=True, exist_ok=True)
    master.resize((pixels, pixels), Image.LANCZOS).save(path)


def main():
    root = Path(__file__).resolve().parent.parent
    master = render_master()
    save_resized(master, root / "assets/branding/cuevanta_icon_1024.png", 1024)

    android_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, pixels in android_sizes.items():
        save_resized(master, root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", pixels)

    for icon in (root / "ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("Icon-App-*.png"):
        points, scale = re.match(r"Icon-App-([\d.]+)x[\d.]+@(\d)x", icon.name).groups()
        save_resized(master, icon, round(float(points) * int(scale)))

    for icon in (root / "macos/Runner/Assets.xcassets/AppIcon.appiconset").glob("app_icon_*.png"):
        save_resized(master, icon, int(re.search(r"(\d+)", icon.name).group(1)))

    for name, pixels in {"Icon-192.png": 192, "Icon-512.png": 512, "Icon-maskable-192.png": 192,
                         "Icon-maskable-512.png": 512}.items():
        save_resized(master, root / "web/icons" / name, pixels)
    save_resized(master, root / "web/favicon.png", 32)

    master.save(root / "windows/runner/resources/app_icon.ico",
                sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


if __name__ == "__main__":
    main()

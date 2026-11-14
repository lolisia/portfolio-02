"""Bake the web leaf-spray canvases (src/foliage.js leafSpray) to PNGs for Godot.

    python tools/leaf-spray.py

Writes godot/assets/textures/leaf_spray.png and needle_spray.png (256x256 RGBA,
same orientation as the canvas). Drawn at 4x and downsampled, like the
browser's anti-aliased canvas.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE, SS = 256, 4
OUT = Path(__file__).resolve().parent.parent / "godot" / "assets" / "textures"


def hex_rgba(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def quad(p0, p1, p2, steps=12):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in (i / steps for i in range(steps + 1))]


def bake(needles):
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def line(a, b, color, width):
        draw.line([(a[0] * SS, a[1] * SS), (b[0] * SS, b[1] * SS)], fill=hex_rgba(color),
                  width=max(1, round(width * SS)))

    def sprig(x, y, length, angle, levels):
        ex, ey = x + length * math.cos(angle), y + length * math.sin(angle)
        line((x, y), (ex, ey), "#78774d" if levels else "#9a9b67", levels + 1.1)
        count = 15 if needles else 5
        for i in range(1, count + 1):
            for side in (-1, 1):
                t = (i - .26 * (side + 1)) / (count + 1)
                a = angle + side * (.68 + .24 * math.sin(i))
                bx, by = x + (ex - x) * t, y + (ey - y) * t
                if levels:
                    if i % 2 == 1:
                        sprig(bx, by, length * (.47 - .19 * t), a, levels - 1)
                    continue
                n = (17 if needles else 25) * (1 - .38 * t)
                w = 1.6 if needles else 8
                ca, sa = math.cos(a), math.sin(a)
                local = quad((0, 0), (n * .44, -w), (n, 0)) + quad((n, 0), (n * .5, w), (0, 0))[1:]
                pts = [((bx + px * ca - py * sa) * SS, (by + px * sa + py * ca) * SS) for px, py in local]
                fill = ["#dce4be", "#d1d9ac", "#f0edc7", "#bac791"][(i + (side + 1)) % 4]
                draw.polygon(pts, fill=hex_rgba(fill))
                if not needles:
                    line((bx, by), (bx + n * .84 * ca, by + n * .84 * sa), "#a5b388", .85)

    sprig(111, 239, 201, -1.43, 1)
    sprig(111, 229, 133, -2.04, 1)
    sprig(111, 224, 122, -.94, 1)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    bake(False).save(OUT / "leaf_spray.png")
    bake(True).save(OUT / "needle_spray.png")
    print("wrote", OUT / "leaf_spray.png", OUT / "needle_spray.png")

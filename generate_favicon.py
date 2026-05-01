#!/usr/bin/env python3
"""Generate a favicon.ico for the GS1 Nordic Summit concept animation.
Design: dark olive-green background, gold beer mug silhouette with a QR-code grid overlay.
"""
from PIL import Image, ImageDraw
import struct, zlib, os

def make_frame(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Background circle
    bg_color = (17, 31, 18, 255)       # --bg2 dark olive
    d.ellipse([0, 0, size-1, size-1], fill=bg_color)

    s = size
    # ── Beer mug silhouette ──────────────────────────────
    gold = (181, 162, 58, 255)
    gold_l = (212, 192, 96, 255)
    cream = (245, 237, 216, 255)

    # Mug body (rounded rect)
    mx = int(s * 0.18)
    my = int(s * 0.28)
    mw = int(s * 0.52)
    mh = int(s * 0.52)
    d.rounded_rectangle([mx, my, mx+mw, my+mh], radius=int(s*0.07), fill=gold)

    # Mug handle
    hx1 = mx + mw - int(s*0.02)
    hy1 = my + int(s*0.10)
    hx2 = mx + mw + int(s*0.18)
    hy2 = my + mh - int(s*0.10)
    d.arc([hx1, hy1, hx2, hy2], start=-90, end=90, fill=gold_l, width=int(s*0.07))

    # Foam top (white/cream)
    foam_margin = int(s * 0.04)
    d.ellipse([mx + foam_margin, my - int(s*0.08),
               mx + mw - foam_margin, my + int(s*0.12)],
              fill=cream)

    # Inner mug (darker) to give depth
    inner_margin = int(s * 0.06)
    inner_top = my + int(s * 0.10)
    d.rounded_rectangle([mx + inner_margin, inner_top,
                          mx + mw - inner_margin, my + mh - int(s*0.04)],
                         radius=int(s*0.04),
                         fill=(140, 120, 30, 200))

    # Small QR-grid dots in bottom-right corner
    dot_size = max(1, int(s * 0.06))
    dot_gap  = max(1, int(s * 0.08))
    qr_ox = int(s * 0.60)
    qr_oy = int(s * 0.60)
    pattern = [
        (0,0),(1,0),(2,0),
        (0,1),      (2,1),
        (0,2),(1,2),(2,2),
    ]
    for (col, row) in pattern:
        x = qr_ox + col * dot_gap
        y = qr_oy + row * dot_gap
        d.rectangle([x, y, x+dot_size, y+dot_size], fill=gold_l)

    return img

# Generate sizes
sizes = [16, 32, 48, 64, 128, 256]
frames = [make_frame(s) for s in sizes]

# Save as ICO
out_path = "/home/ubuntu/gs1-nordic-summit/favicon.ico"
frames[0].save(
    out_path,
    format="ICO",
    sizes=[(s, s) for s in sizes],
    append_images=frames[1:]
)
print(f"Saved {out_path} ({os.path.getsize(out_path)} bytes)")

# Also save a 32x32 PNG preview
frames[1].save("/home/ubuntu/gs1-nordic-summit/favicon_preview.png")
print("Saved favicon_preview.png")

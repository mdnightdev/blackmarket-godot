#!/usr/bin/env python3
# usage: python atlas.py <folder_of_png> <out_folder> [cell_size]
import sys, json, math
from pathlib import Path
from PIL import Image

src = Path(sys.argv[1])
out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
cell = int(sys.argv[3]) if len(sys.argv) > 3 else 128
cols, pad = 10, 2

files = sorted(p for p in src.iterdir() if p.suffix.lower() in (".png", ".webp"))
rows = math.ceil(len(files) / cols)
atlas = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
meta = {}

for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA")
    box = im.getchannel("A").getbbox()
    if box:
        im = im.crop(box)               # trim empty transparent margin
    im.thumbnail((cell - pad * 2,) * 2, Image.LANCZOS)
    cx, cy = (i % cols) * cell, (i // cols) * cell
    atlas.paste(im, (cx + (cell - im.width) // 2, cy + (cell - im.height) // 2))
    meta[f.stem] = {"x": cx, "y": cy, "w": cell, "h": cell}

atlas.save(out / "icons.webp", "WEBP", quality=85, alpha_quality=100, method=6)
(out / "icons.json").write_text(json.dumps(meta, indent=1))
print(f"{len(files)} icons -> {cols*cell}x{rows*cell}, {(out/'icons.webp').stat().st_size//1024} KB")

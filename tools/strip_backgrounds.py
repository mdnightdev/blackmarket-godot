import os
import collections
from PIL import Image

def strip_bg(im: Image.Image, tolerance: float = 24.0) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    pixels = im.load()

    # 1. Establish background reference from the 4 outer perimeter edges
    border_samples = []
    step_x = max(1, w // 40)
    step_y = max(1, h // 40)
    for x in range(0, w, step_x):
        border_samples.append(pixels[x, 0])
        border_samples.append(pixels[x, h - 1])
    for y in range(0, h, step_y):
        border_samples.append(pixels[0, y])
        border_samples.append(pixels[w - 1, y])

    bg_r = sum(c[0] for c in border_samples) // len(border_samples)
    bg_g = sum(c[1] for c in border_samples) // len(border_samples)
    bg_b = sum(c[2] for c in border_samples) // len(border_samples)
    bg_ref = (bg_r, bg_g, bg_b)

    # 2. BFS floodfill from all 4 borders inward so we don't punch holes inside the prop
    # 0 = unvisited, 1 = background, 2 = foreground/visited non-bg
    mask = bytearray(w * h)
    queue = collections.deque()

    # Seed the borders
    for x in range(w):
        for y in (0, h - 1):
            c = pixels[x, y]
            dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
            if dist <= tolerance + 10.0:
                mask[y * w + x] = 1
                queue.append((x, y))
            else:
                mask[y * w + x] = 2

    for y in range(h):
        for x in (0, w - 1):
            if mask[y * w + x] == 0:
                c = pixels[x, y]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist <= tolerance + 10.0:
                    mask[y * w + x] = 1
                    queue.append((x, y))
                else:
                    mask[y * w + x] = 2

    while queue:
        cx, cy = queue.popleft()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and mask[ny * w + nx] == 0:
                c = pixels[nx, ny]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist <= tolerance:
                    mask[ny * w + nx] = 1
                    queue.append((nx, ny))
                else:
                    mask[ny * w + nx] = 2

    # 3. Create RGBA image with transparent background and soft 1px edge falloff
    rgba = im.convert("RGBA")
    rgba_pixels = rgba.load()

    for y in range(h):
        for x in range(w):
            if mask[y * w + x] == 1:
                rgba_pixels[x, y] = (0, 0, 0, 0)
            elif mask[y * w + x] == 2:
                # Check distance to background for soft anti-aliased edge
                c = pixels[x, y]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist < tolerance + 10.0:
                    factor = max(0.0, min(1.0, (dist - tolerance) / 10.0))
                    alpha = int(255 * factor)
                    rgba_pixels[x, y] = (c[0], c[1], c[2], alpha)

    return rgba

if __name__ == "__main__":
    test_files = ["ammo_9mm.jpg", "machete.jpg"]
    base_dir = "/root/termux/games/godot/project/assets/items/props_54"
    out_dir = "/root/termux/games/godot/project/assets/items/props_transparent"
    os.makedirs(out_dir, exist_ok=True)

    for f in test_files:
        src = os.path.join(base_dir, f)
        if os.path.exists(src):
            im = Image.open(src)
            stripped = strip_bg(im)
            out_file = os.path.splitext(f)[0] + ".png"
            out_path = os.path.join(out_dir, out_file)
            stripped.save(out_path, "PNG")
            
            # Verify transparency stats
            w, h = stripped.size
            alpha_data = list(stripped.getchannel("A").getdata())
            transparent_count = sum(1 for a in alpha_data if a == 0)
            opaque_count = sum(1 for a in alpha_data if a == 255)
            trans_pct = (transparent_count / (w * h)) * 100
            print(f"Verified {f}: {trans_pct:.1f}% transparent pixels, saved to {out_path}")

"""Builds a talking frame for a portrait by copying only the mouth area from a
generated mouth-open variant onto the original, so nothing else flickers when
the game swaps between the two frames.

Usage: python3 make_talk_frame.py <base.jpg> <variant.jpg> <output.jpg> [preview.gif]
"""

import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SEARCH_TOP = 0.15
SEARCH_BOTTOM = 0.6
PATCH_WIDTH = 0.2
PATCH_HEIGHT = 0.11
FEATHER = 18


def find_mouth(base: Image.Image, variant: Image.Image) -> tuple[int, int]:
    width, height = base.size
    top, bottom = int(height * SEARCH_TOP), int(height * SEARCH_BOTTOM)
    # Blurring first hides the thin edge noise that regeneration adds everywhere,
    # leaving the solid change around the mouth as the strongest signal.
    soft_base = base.filter(ImageFilter.GaussianBlur(8))
    soft_variant = variant.filter(ImageFilter.GaussianBlur(8))
    difference = ImageChops.difference(soft_base, soft_variant).convert("L").crop((0, top, width, bottom))
    smoothed = difference.filter(ImageFilter.BoxBlur(16))
    pixels = smoothed.load()
    best, best_value = (width // 2, top), -1
    for y in range(0, smoothed.height, 4):
        for x in range(0, smoothed.width, 4):
            if pixels[x, y] > best_value:
                best, best_value = (x, y + top), pixels[x, y]
    return best


def make_mask(size: tuple[int, int], center: tuple[int, int]) -> Image.Image:
    width, height = size
    half_w, half_h = int(width * PATCH_WIDTH / 2), int(height * PATCH_HEIGHT / 2)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(
        (center[0] - half_w, center[1] - half_h, center[0] + half_w, center[1] + half_h), fill=255
    )
    return mask.filter(ImageFilter.GaussianBlur(FEATHER))


def main() -> None:
    base_path, variant_path, output_path = sys.argv[1:4]
    base = Image.open(base_path).convert("RGB")
    variant = Image.open(variant_path).convert("RGB").resize(base.size, Image.LANCZOS)
    mouth = find_mouth(base, variant)
    talking = Image.composite(variant, base, make_mask(base.size, mouth))
    talking.save(output_path, quality=92)
    print(f"mouth at {mouth}, saved {output_path}")
    if len(sys.argv) > 4:
        preview_size = (base.width // 2, base.height // 2)
        frames = [base.resize(preview_size), talking.resize(preview_size)]
        frames[0].save(sys.argv[4], save_all=True, append_images=frames[1:] * 3 + frames * 3, duration=140, loop=0)


if __name__ == "__main__":
    main()

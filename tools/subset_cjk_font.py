"""Cuts Noto Sans SC down to the characters the game actually uses, so the
Chinese family names render without shipping the full 8 MB font.

Run it again whenever new Chinese text or pinyin is added to the project.

Usage: python3 subset_cjk_font.py <NotoSansSC-Regular.otf> [project_dir]
"""

import sys
from pathlib import Path

from fontTools import subset

SCANNED_SUFFIXES = {".gd", ".tres", ".tscn", ".cfg"}
SKIPPED_DIRS = {".godot", "addons", ".import"}
OUTPUT_NAME = "theme/fonts/NotoSansSC-Subset.otf"
# Inter and Cinzel cover Basic Latin and Latin-1, so only characters past them need the fallback.
FIRST_FALLBACK_CODEPOINT = 0x0100


def used_characters(project_dir: Path) -> set[str]:
    characters: set[str] = set()
    for path in project_dir.rglob("*"):
        if path.suffix not in SCANNED_SUFFIXES or SKIPPED_DIRS.intersection(path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        characters.update(char for char in text if ord(char) >= FIRST_FALLBACK_CODEPOINT)
    return characters


def main() -> None:
    source = Path(sys.argv[1])
    project_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "project"
    characters = used_characters(project_dir)
    if not characters:
        sys.exit("No characters past Latin-1 found in the project, nothing to subset.")

    output = project_dir / OUTPUT_NAME
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    font = subset.load_font(str(source), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(sorted(characters)))
    subsetter.subset(font)
    subset.save_font(font, str(output), options)
    print(f"{len(characters)} characters, {output.stat().st_size // 1024} KB, saved {output}")


if __name__ == "__main__":
    main()

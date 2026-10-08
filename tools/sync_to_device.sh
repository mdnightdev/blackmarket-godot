#!/usr/bin/env bash
# Mirrors project/ into shared storage so the Godot Android editor can open and run it.
# Termux holds the authoritative import cache, so the imported assets, the uid cache and the class
# cache are mirrored too. Without them, preloads of newly added assets fail and every script that
# uses them stops compiling when the project is run from the editor. The editor's own editor/ and
# shader_cache/ folders are left alone. Close the project in the editor before syncing.
set -euo pipefail

source_dir="$(cd "$(dirname "$0")/../project" && pwd)"
target_dir="${1:-/sdcard/Documents/blackmarket_godot}"

if [[ ! -d "$source_dir/.godot/imported" ]]; then
	echo "No import cache in $source_dir. Run a headless --import first." >&2
	exit 1
fi

mkdir -p "$target_dir/.godot"
rsync -rt --delete --exclude '.godot/' "$source_dir/" "$target_dir/"
rsync -rt --delete "$source_dir/.godot/imported/" "$target_dir/.godot/imported/"
for cache in global_script_class_cache.cfg uid_cache.bin; do
	cp "$source_dir/.godot/$cache" "$target_dir/.godot/$cache"
done
echo "Synced $source_dir -> $target_dir"

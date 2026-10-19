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
rm -rf "$target_dir/.godot/editor"
for cache in global_script_class_cache.cfg uid_cache.bin; do
	rm -f "$target_dir/.godot/$cache"
	cp "$source_dir/.godot/$cache" "$target_dir/.godot/$cache"
done
for top_file in project.godot export_presets.cfg .gutconfig.json; do
	if [[ -f "$source_dir/$top_file" ]]; then
		rm -f "$target_dir/$top_file"
		cp "$source_dir/$top_file" "$target_dir/$top_file"
	fi
done
for top_scene in "$source_dir"/*.tscn; do
	if [[ -f "$top_scene" ]]; then
		cp -f "$top_scene" "$target_dir/"
	fi
done
for code_dir in scripts ui data theme tests; do
	if [[ -d "$source_dir/$code_dir" ]]; then
		rm -rf "$target_dir/$code_dir"
		cp -r "$source_dir/$code_dir" "$target_dir/$code_dir"
	fi
done
for asset_dir in addons assets audio; do
	if [[ -d "$source_dir/$asset_dir" ]]; then
		mkdir -p "$target_dir/$asset_dir"
		rsync -rt --delete "$source_dir/$asset_dir/" "$target_dir/$asset_dir/"
	fi
done
rm -f "$source_dir/.godot/imported/"*.etc2.ctex "$source_dir/.godot/imported/"*.s3tc.ctex
rsync -rt --delete "$source_dir/.godot/imported/" "$target_dir/.godot/imported/"
echo "Synced $source_dir -> $target_dir"

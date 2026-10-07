#!/usr/bin/env bash
# Mirrors project/ into shared storage so the Godot Android editor can open and run it.
# The editor's own .godot import cache in the target is left alone.
set -euo pipefail

source_dir="$(cd "$(dirname "$0")/../project" && pwd)"
target_dir="${1:-/sdcard/Documents/blackmarket_godot}"

mkdir -p "$target_dir"
rsync -rt --delete --exclude '.godot/' "$source_dir/" "$target_dir/"
echo "Synced $source_dir -> $target_dir"

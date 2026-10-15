#!/bin/bash

# Read version from export_presets.cfg
VERSION=$(grep "^version/name=" project/export_presets.cfg | cut -d'"' -f2)

# Accept custom name as argument, or auto-increment based on version
if [ -n "$1" ]; then
  APK_NAME="$black-market"
else
  # Auto-increment: v1.0.0-dev.test1.apk, v1.0.0-dev.test2.apk, etc.
  BASE_NAME="${VERSION}-dev.test"
  count=1
  while [ -f "build/${BASE_NAME}${count}.apk" ]; do
    count=$((count + 1))
  done
  APK_NAME="${BASE_NAME}${count}.apk"
fi

cd project
../Godot_v4.3-stable_linux.arm64 --headless --export-release "Android" "../build/$APK_NAME"

if [ $? -eq 0 ]; then
  echo "Build successful: build/$APK_NAME"
  ls -lh "../build/$APK_NAME"
else
  echo "Build failed"
  exit 1
fi

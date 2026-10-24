#!/bin/bash

# Auto-bump version code and update git hash in export_presets.cfg
OLD_CODE=$(grep "^version/code=" project/export_presets.cfg | cut -d'=' -f2)
NEW_CODE=$((OLD_CODE + 1))
GIT_HASH=$(git rev-parse --short HEAD)
NEW_VERSION="1.0.0-dev+${GIT_HASH}"

sed -i "s/^version\/code=.*/version\/code=${NEW_CODE}/" project/export_presets.cfg
sed -i "s/^version\/name=.*/version\/name=\"${NEW_VERSION}\"/" project/export_presets.cfg

echo "Building version code ${NEW_CODE} (${NEW_VERSION})..."

# Accept custom name or build from updated version
if [ -n "$1" ]; then
    APK_NAME="$1.apk"
else
    APK_NAME="blackmarket-v${NEW_CODE}-${GIT_HASH}.apk"
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

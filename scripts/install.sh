#!/usr/bin/env bash
# Builds a Release StreamBubble and puts it in /Applications.
#
# The build is signed with the personal team (see project.yml), so macOS keeps the Screen
# Recording, Camera, and Microphone grants when you install a newer build over an older one.
set -euo pipefail

cd "$(dirname "$0")/.."
xcodegen generate --quiet
# DEVELOPMENT_TEAM in the environment overrides the team in project.yml, so a contributor
# can sign with their own team.
xcodebuild -project StreamBubble.xcodeproj -scheme StreamBubble -configuration Release \
  -derivedDataPath build/DerivedData -quiet build ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"}

app="build/DerivedData/Build/Products/Release/StreamBubble.app"
pkill -x StreamBubble 2>/dev/null || true
# An `open` while the old process still quits fails with error -600, so wait for it.
while pgrep -x StreamBubble >/dev/null; do sleep 0.2; done
rm -rf /Applications/StreamBubble.app
cp -R "$app" /Applications/
open /Applications/StreamBubble.app
echo "Installed /Applications/StreamBubble.app"

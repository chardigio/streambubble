#!/usr/bin/env bash
# Renders the StreamBubble app icon masters into the asset catalog.
#
# The masters are SVG in brand/. Each size here is a render, not a source,
# so edit the SVG (or build.py, which writes app-icon.svg) and run this script again.
#
# 16 px uses its own master, app-icon-16.svg: at 16 px the face and the glass detail of the
# full icon turn into noise, so that size shows only the window and a plain record.circle.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
marks="$here/brand"
out="$here/StreamBubble/Assets.xcassets/AppIcon.appiconset"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

render() { # <svg> <png>: a 1024 px render with a transparent background
  printf '<!doctype html><html><body style="margin:0;background:transparent"><img src="file://%s" width="1024" height="1024" style="display:block"></body></html>' "$1" >"$tmp/page.html"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=1024,1024 \
    --default-background-color=00000000 --screenshot="$2" "file://$tmp/page.html" 2>/dev/null
}

render "$marks/app-icon.svg" "$tmp/full.png"
render "$marks/app-icon-16.svg" "$tmp/small.png"

mkdir -p "$out"
for px in 32 64 128 256 512 1024; do
  magick "$tmp/full.png" -filter Lanczos -resize "${px}x${px}" -strip "$out/icon_$px.png"
done
magick "$tmp/small.png" -filter Lanczos -resize 16x16 -strip "$out/icon_16.png"

cat >"$out/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' >"$here/StreamBubble/Assets.xcassets/Contents.json"
echo "Wrote $out"

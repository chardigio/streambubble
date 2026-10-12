#!/usr/bin/env bash
# Archives a Release StreamBubble and uploads it to App Store Connect for the Mac App Store.
#
# Needs an App Store Connect API key with the App Manager role, in these variables:
#   ASC_KEY_PATH    the .p8 file
#   ASC_KEY_ID      the key ID
#   ASC_ISSUER_ID   the issuer ID
# Optional:
#   BUILD_NUMBER    defaults to the UTC time (YYYYMMDDHHMM), so each upload is higher than the last
#   DEVELOPMENT_TEAM  overrides the team in project.yml
#
# The key lets xcodebuild make the Mac App Distribution and Mac Installer Distribution
# certificates and the profile in the cloud, so no certificate has to be in the keychain first.
set -euo pipefail

: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to the App Store Connect API key (.p8)}"
: "${ASC_KEY_ID:?Set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
build_number="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"

cd "$(dirname "$0")/.."
xcodegen generate --quiet

out="build/release/$build_number"
rm -rf "$out"
mkdir -p "$out"

auth=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

xcodebuild archive -project StreamBubble.xcodeproj -scheme StreamBubble -configuration Release \
  -destination "generic/platform=macOS" -archivePath "$out/StreamBubble.xcarchive" -quiet \
  CURRENT_PROJECT_VERSION="$build_number" \
  ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"} "${auth[@]}"

cat >"$out/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$out/StreamBubble.xcarchive" \
  -exportOptionsPlist "$out/ExportOptions.plist" -exportPath "$out/export" "${auth[@]}"

echo "Uploaded StreamBubble build $build_number. App Store Connect processes it in a few minutes."

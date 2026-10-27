#!/bin/bash
# Archive ResQApp and upload it to TestFlight.
# Build number = UTC timestamp (YYYYMMDD.HHMM), so every upload is higher than the last
# and project.yml never needs a manual bump. Override with: BUILD_NUMBER=123 ./testflight.sh
set -euo pipefail
cd "$(dirname "$0")"

BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d.%H%M)}"
ARCHIVE="build/ResQApp-$BUILD_NUMBER.xcarchive"
mkdir -p build

xcodegen generate

echo "Archiving build $BUILD_NUMBER..."
xcodebuild archive -project ResQApp.xcodeproj -scheme ResQApp -configuration Release \
  -destination generic/platform=iOS -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" > "build/archive-$BUILD_NUMBER.log" 2>&1 \
  || { tail -20 "build/archive-$BUILD_NUMBER.log"; exit 1; }

echo "Uploading..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
  -exportPath "build/export-$BUILD_NUMBER" -allowProvisioningUpdates > "build/upload-$BUILD_NUMBER.log" 2>&1 \
  || { grep -v DVTProvisioningProfileManager "build/upload-$BUILD_NUMBER.log" | tail -20; exit 1; }

version=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$ARCHIVE/Info.plist")
echo "Uploaded ResQ $version ($BUILD_NUMBER) to App Store Connect."

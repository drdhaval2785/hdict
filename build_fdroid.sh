#!/bin/bash

# Build script for F-Droid release
# Usage: ./build_fdroid.sh

set -e

echo "=========================================="
echo "Building F-Droid APK for hdict"
echo "=========================================="

# Get version from pubspec.yaml
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
BUILD_CODE=$(echo $VERSION | cut -d'+' -f2)

echo "Version: $VERSION"
echo "Build Code: $BUILD_CODE"

# Clean previous builds
echo ""
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo ""
echo "Getting dependencies..."
flutter pub get

# Build F-Droid release APK
echo ""
echo "Building F-Droid APK..."
flutter build apk --flavor fdroid --release

# Output location
OUTPUT_DIR="build/app/outputs/apk/fdroid/release"
APK_NAME="hdict-${VERSION}-fdroid.apk"

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "APK location: $OUTPUT_DIR/app-fdroid-release.apk"
echo ""
echo "To rename for release:"
echo "  cp $OUTPUT_DIR/app-fdroid-release.apk $APK_NAME"
echo ""
echo "Then upload $APK_NAME to GitHub release"
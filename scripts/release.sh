#!/usr/bin/env bash
# Build a distributable Eyeline.app and zip it for a GitHub Release.
#
# Eyeline is NOT notarized (no paid Apple Developer ID), so this produces an ad-hoc-signed
# build that users open via "Open Anyway" / the xattr step — see the README's Install section.
# When/if a Developer ID is added, a sign + notarize + staple step slots in after the build.
#
# Usage: scripts/release.sh [version]
#   version defaults to MARKETING_VERSION in project.yml.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep -m1 'MARKETING_VERSION:' project.yml | sed -E 's/.*"(.*)".*/\1/')}"
BUILD_DIR=".release-build"
DIST_DIR="dist"
ZIP="$DIST_DIR/Eyeline-v$VERSION.zip"

echo "==> Building Eyeline $VERSION (Release)…"
rm -rf "$BUILD_DIR"
xcodebuild \
  -project Eyeline.xcodeproj \
  -scheme Eyeline \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  build | tail -3

APP="$BUILD_DIR/Build/Products/Release/Eyeline.app"
[ -d "$APP" ] || { echo "ERROR: build did not produce $APP" >&2; exit 1; }

echo "==> Packaging -> ${ZIP} ..."
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
# ditto (not plain `zip`) preserves the bundle's symlinks + code signature so the .app stays runnable.
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "==> Done."
echo "    Artifact: $ZIP"
echo "    Size:     $(du -h "$ZIP" | cut -f1)"
echo "    SHA-256:  $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

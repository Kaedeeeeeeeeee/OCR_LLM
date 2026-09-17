#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.derivedData/OCRTests"
PROJECT="$ROOT_DIR/QuickOCRLLM/QuickOCRLLM.xcodeproj"
APP="$DERIVED_DATA/Build/Products/Debug/Cheese! OCR.app"
BUILD_ARGS=(-project "$PROJECT" -scheme QuickOCRLLM -configuration Debug
  -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED_DATA"
  -only-testing:QuickOCRLLMTests -parallel-testing-enabled NO)
xcodebuild "${BUILD_ARGS[@]}" build-for-testing
# Xcode adds test-host exceptions to ALL macOS entitlements during test builds,
# including helpers. Apple requires an inheriting helper to have exactly these
# two entitlements. Restore its normal signature before test-without-building.
# See docs/ocr-reliability.md for the Apple guidance and build-system source.
SIGNING_IDENTITY="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
test -n "$SIGNING_IDENTITY"
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp=none \
  --identifier com.cheeseocr.app.worker \
  --entitlements "$ROOT_DIR/QuickOCRLLM/OCRWorker/OCRWorker.entitlements" \
  "$APP/Contents/MacOS/CheeseOCRWorker"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none \
  --preserve-metadata=identifier,entitlements,flags "$APP"
codesign --verify --deep --strict "$APP"
xcodebuild "${BUILD_ARGS[@]}" test-without-building

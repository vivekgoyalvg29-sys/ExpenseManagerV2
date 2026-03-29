#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter CLI not found in PATH. Install Flutter first, then re-run this script." >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-app-directory>" >&2
  exit 1
fi

TARGET_DIR="$1"
SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -e "$TARGET_DIR" ]]; then
  echo "Error: target directory '$TARGET_DIR' already exists." >&2
  exit 1
fi

flutter create -t app "$TARGET_DIR"

cp -R "$SOURCE_DIR/lib" "$TARGET_DIR/"
cp -R "$SOURCE_DIR/assets" "$TARGET_DIR/"
cp "$SOURCE_DIR/pubspec.yaml" "$TARGET_DIR/pubspec.yaml"

cat <<MSG

New Flutter app scaffold created at: $TARGET_DIR
Copied from old project:
  - lib/
  - assets/
  - pubspec.yaml

Next steps:
  1) cd "$TARGET_DIR"
  2) flutter pub get
  3) Re-apply platform-specific customizations (google-services, widgets, entitlements, etc.) as needed.

MSG

#!/usr/bin/env bash
# Build and test against the iOS Simulator SDK.
#
# `xcode-select -p` on this machine points at /Library/Developer/CommandLineTools,
# which makes xcodebuild refuse to run ("requires Xcode"). Xcode itself is installed,
# so DEVELOPER_DIR overrides the selection for this command only -- no sudo, and no
# change to the machine's global toolchain setting.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEVICE="${DEVICE:-iPhone 17 Pro}"
cd "$(dirname "$0")/.."

if [ ! -d "$DEVELOPER_DIR" ]; then
  echo "Xcode not found at $DEVELOPER_DIR. Set DEVELOPER_DIR to your Xcode.app/Contents/Developer." >&2
  exit 1
fi

exec xcodebuild "${1:-test}" \
  -project SleepTokenKB.xcodeproj \
  -scheme SleepTokenKB \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  CODE_SIGNING_ALLOWED=NO

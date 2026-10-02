#!/bin/zsh
# Builds ScrollToggle.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"
APP="ScrollToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -o "$APP/Contents/MacOS/ScrollToggle" main.swift \
  -framework Cocoa -framework ServiceManagement
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $PWD/$APP"

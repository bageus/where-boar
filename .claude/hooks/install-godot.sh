#!/bin/bash
# Installs headless Godot into cloud Claude Code sessions so agents can run headless tests.
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

VERSION="4.7.2"
if command -v godot >/dev/null && godot --version 2>/dev/null | grep -q "^${VERSION}\.stable"; then
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 4 -o "$tmp/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
unzip -q "$tmp/godot.zip" -d "$tmp"
install -m 755 "$tmp/Godot_v${VERSION}-stable_linux.x86_64" /usr/local/bin/godot
godot --version

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$PWD" == /workspace/* ]]; then
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.config}"
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.cache}"
  export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.local/share}"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
fi
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/.build.XXXXXX")
trap 'rm -rf "$stage"' EXIT
godot --headless --path . --editor --import --quit
python3 tools/build_info.py
godot --headless --path . --export-release macOS "$stage/Brick-Outbreak-macOS.zip"
python3 tests/verify.py "$stage/Brick-Outbreak-macOS.zip" > "$stage/VALIDATION.txt"
cat "$stage/VALIDATION.txt"
python3 tools/package.py --output-dir "$stage"
# Verify the exact repacked download, not just the pre-packaging export.
python3 tests/verify.py --package-only "$stage/Brick-Outbreak-macOS.zip" > "$stage/FINAL-VALIDATION.txt"
cat "$stage/FINAL-VALIDATION.txt"
for name in Brick-Outbreak-macOS.zip Brick-Outbreak-Source.zip TEST-REPORT.txt VALIDATION.txt BUILD-INFO.json SHA256SUMS.txt; do
  mv -f "$stage/$name" "dist/$name"
done
(cd dist && sha256sum -c SHA256SUMS.txt)

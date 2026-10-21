#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
godot --headless --editor --import --quit
godot --headless --export-release macOS dist/Brick-Outbreak-macOS.zip
python3 tests/verify.py dist/Brick-Outbreak-macOS.zip > dist/VALIDATION.txt
cat dist/VALIDATION.txt
python3 tools/package.py

"""Fingerprint the runtime inputs so an exported app can prove which source it contains."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "build-info.json"


def version():
    return re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)[1]


def runtime_inputs():
    paths = set()
    for pattern in ("*.gd", "*.gd.uid", "*.tscn", "*.godot", "*.cfg", "icon.svg", "icon.svg.import"):
        paths.update(path for path in ROOT.glob(pattern) if path.is_file())
    paths.update(p for p in (ROOT / "assets").rglob("*") if p.is_file() and p != MANIFEST)
    return sorted(paths)


def fingerprint():
    digest = hashlib.sha256()
    for path in runtime_inputs():
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def write():
    info = {
        "version": version(),
        "runtime_sha256": fingerprint(),
        "base_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "note": "runtime_sha256 identifies the exact runtime files, including uncommitted changes",
    }
    MANIFEST.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(info))


if __name__ == "__main__":
    write()

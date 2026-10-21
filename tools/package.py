"""Package a freshly exported app without altering its signed bundle contents."""
from pathlib import Path
import hashlib
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
dist = root / 'dist'
package = dist / 'Brick-Outbreak-macOS.zip'
validation = (dist / 'VALIDATION.txt').read_text()
assert validation.rstrip().endswith('ALL CHECKS PASSED'), 'Run verification before packaging.'
assert validation.count('SMOKE TEST COMPLETE') == 2, 'Source and exported resources must both pass.'
(dist / 'TEST-REPORT.txt').write_text("""Brick Outbreak MVP 0.4.0 — articulated zombie appearances and bestiary
Validated on Linux x86_64 / Godot 4.6.3.

PASS: 110 source gameplay/model checks and same 110 checks against exported PCK.
PASS: ZIP CRC, application plist, executable permissions, x86_64 + arm64 slices.
PASS: Code signature load commands present (not Apple signature validation).
PASS: Real OpenGL zombie front/back gallery and updated battle demonstrations inspected.

New checks: five real zombie rigs, limp/open-jaw attack animation, nested hit
flash/freeze restoration, health bar position, mesh merging and shared geometry,
slowed gait, mouth-launched acid collision, and five-model draggable bestiary.
See VALIDATION.txt for the complete automated test output.

Not tested: macOS executable on a Mac, performance on Mac, Apple signature
validation, Gatekeeper acceptance or notarization. Ad-hoc signed test build.
Original procedural models inspired by the reference; no detailed ornamental
sculpting, transparent plastic shader or horse model.
""")
extras = {
    '安装说明-README.txt': root / 'README.md',
    'TEST-REPORT.txt': dist / 'TEST-REPORT.txt',
    'VALIDATION.txt': dist / 'VALIDATION.txt',
    'LICENSES/THIRD_PARTY_NOTICES.txt': root / 'THIRD_PARTY_NOTICES.txt',
    'LICENSES/FONT-LICENSE.txt': root / 'assets/FONT-LICENSE.txt',
    'LICENSES/GODOT-COPYRIGHT.txt': root / 'assets/GODOT-COPYRIGHT.txt',
}
temporary = dist / '.package.tmp'
with zipfile.ZipFile(package) as original, zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for item in original.infolist():
        if item.filename not in extras:
            with original.open(item) as source, z.open(item, 'w') as target:
                shutil.copyfileobj(source, target)
    for name, path in extras.items():
        z.write(path, name)
temporary.replace(package)
with zipfile.ZipFile(package) as z:
    assert z.testzip() is None
with zipfile.ZipFile(dist / 'Brick-Outbreak-Source.zip', 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if path.is_file() and not any(part in {'.git', '.godot', 'dist', '__pycache__'} for part in rel.parts):
            z.write(path, str(Path('Brick-Outbreak-Source') / rel))
    for name in ['heroes.png', 'heroes-back.png', 'gameplay.png', 'combat-0.png', 'combat-1.png', 'combat-2.png', 'zombies.png', 'zombies-back.png']:
        z.write(dist / name, str(Path('Brick-Outbreak-Source/dist') / name))
checksums = []
for name in ['Brick-Outbreak-macOS.zip', 'Brick-Outbreak-Source.zip']:
    path = dist / name
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    checksums.append(f'{digest}  {name}')
    print(f'{name}: {path.stat().st_size / 1024 / 1024:.2f} MiB')
(dist / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')

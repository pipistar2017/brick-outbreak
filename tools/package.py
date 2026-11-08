"""Package a freshly exported app without altering its signed bundle contents."""
from pathlib import Path
import argparse
import hashlib
import shutil
import zipfile

from build_info import MANIFEST, version

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path, default=root / 'dist')
dist = parser.parse_args().output_dir
package = dist / 'Brick-Outbreak-macOS.zip'
validation = (dist / 'VALIDATION.txt').read_text()
assert validation.rstrip().endswith('ALL CHECKS PASSED'), 'Run verification before packaging.'
assert validation.count('SMOKE TEST COMPLETE') == 2, 'Source and exported resources must both pass.'
shutil.copyfile(MANIFEST, dist / 'BUILD-INFO.json')
(dist / 'TEST-REPORT.txt').write_text(f"""Brick Outbreak MVP {version()} — energy circles, redesigned enemies, click movement and galaxy ending
Validated on Linux x86_64 / Godot 4.6.3.

PASS: 589 source gameplay/model checks and the same 589 checks against exported PCK.
PASS: ZIP CRC, application plist, executable permissions, x86_64 + arm64 slices.
PASS: Code signature load commands present (not Apple signature validation).
PASS: Exported runtime fingerprint matches the current source and build manifest.
This packaging command does not assess screenshots or graphical performance.
PASS: The complete campaign remains covered by the exported-resource checks.

New checks cover per-stage hero health and retained armour, all three difficulty
settings and actual movement/attack changes, Q/E adjustments, third-skill directional
coverage, landing time, damage totals, upgrade scaling, cooldowns, pause and cleanup,
plus F-key and button input.
Campaign checks cover all three energy circles, airborne immunity, ten-kill descent,
continuous capped spawning beyond the former quotas, full basic damage, reduced
Q/E/F damage and impact timing, live health display, destruction cleanup,
intermission upgrades, retained progress and final victory.
Model checks cover eighteen themed enemies, articulated quadrupeds and soldiers,
material feedback, cache isolation, ranged launch/hits and three bestiary pages.
Click movement checks cover ground picking in all three views, arrival, keyboard
override, arena bounds, circle detours, landing replans and pause/transition cleanup.
Ending checks cover all three winning heroes, sky descent, dialogue order,
recruitment and future teamwork, skip/finish and restart/menu cleanup.
Existing hero/combat/camera checks retained and updated for the campaign rules.
See VALIDATION.txt for the complete automated test output.

Not tested: macOS executable on a Mac, performance on Mac, Apple signature
validation, Gatekeeper acceptance or notarization. Ad-hoc signed test build.
Original procedural brick-style models and environments. No iOS/iPad build.
""")
extras = {
    'BUILD-INFO.json': dist / 'BUILD-INFO.json',
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
    for name in ['heroes.png', 'heroes-back.png', 'gameplay.png', 'combat-0.png', 'combat-1.png', 'combat-2.png', 'zombies.png', 'zombies-back.png', 'view-0.png', 'view-1.png', 'view-2.png', 'stage-0.png', 'stage-1.png', 'stage-2.png', 'intermission.png', 'victory.png', 'ultimate-0.png', 'ultimate-1.png', 'ultimate-2.png', 'difficulty.png']:
        z.write(root / 'dist' / name, str(Path('Brick-Outbreak-Source/dist') / name))
checksums = []
for name in ['Brick-Outbreak-macOS.zip', 'Brick-Outbreak-Source.zip']:
    path = dist / name
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    checksums.append(f'{digest}  {name}')
    print(f'{name}: {path.stat().st_size / 1024 / 1024:.2f} MiB')
(dist / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')

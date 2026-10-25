"""Verify source and (optionally) exported macOS game resources; requires Godot 4.6.3."""
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]

def run(args):
    result = subprocess.run(['godot', '--headless', *args, '--', '--smoke-test'],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=90)
    print(result.stdout)
    assert result.returncode == 0, f'Godot exited {result.returncode}'
    assert not re.search(r'(?:SCRIPT ERROR|ERROR:|FAIL:)', result.stdout), 'Engine errors'
    assert 'SMOKE TEST COMPLETE' in result.stdout, 'Suite did not complete'
    count = result.stdout.count('PASS:')
    assert count == 277, f'Expected 277 checks, got {count}'
    return count

print('SOURCE CHECKS')
run(['--path', str(root)])
if len(sys.argv) > 1:
    with zipfile.ZipFile(sys.argv[1]) as z:
        assert z.testzip() is None, 'ZIP CRC failure'
        names = z.namelist()
        plist_name = next(n for n in names if n.endswith('.app/Contents/Info.plist'))
        info = plistlib.loads(z.read(plist_name))
        assert info['CFBundleShortVersionString'] == '0.6.0', 'Wrong app version'
        binary_name = plist_name.removesuffix('Info.plist') + 'MacOS/' + info['CFBundleExecutable']
        blob = z.read(binary_name)
        magic, count = struct.unpack_from('>II', blob)
        assert magic == 0xCAFEBABE and count == 2, 'Expected universal Mach-O'
        architectures = []
        for i in range(count):
            cpu, subtype, offset, size, align = struct.unpack_from('>IIIII', blob, 8 + i * 20)
            architectures.append(cpu)
            assert blob[offset:offset + 4] == b'\xcf\xfa\xed\xfe', 'Invalid Mach-O slice'
            ncmds = struct.unpack_from('<I', blob, offset + 16)[0]
            cursor = offset + 32
            signature = False
            for _ in range(ncmds):
                cmd, length = struct.unpack_from('<II', blob, cursor)
                assert length >= 8
                if cmd == 0x1D:
                    signature = True
                cursor += length
            assert signature, 'Missing code signature load command'
        assert set(architectures) == {0x1000007, 0x100000C}, architectures
        mode = z.getinfo(binary_name).external_attr >> 16
        assert mode & 0o111, 'Executable permission missing'
        print('PASS: ZIP CRC, Info.plist, x86_64 + arm64, signature presence, executable permission')
        print('Note: signature presence is not Apple signature validation or notarization.')
        pck = next(n for n in names if n.endswith('.pck'))
        with tempfile.TemporaryDirectory() as work:
            pack = Path(work) / 'game.pck'
            pack.write_bytes(z.read(pck))
            print('EXPORTED RESOURCE CHECKS (Linux engine, not macOS binary)')
            run(['--main-pack', str(pack)])
print('ALL CHECKS PASSED')

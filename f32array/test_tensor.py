#!/usr/bin/env python3
"""Check NumPy tensor files on Bun and native Bend, including a sparse 4 GiB offset."""
from pathlib import Path
import subprocess
import tempfile
import numpy as np

HERE = Path(__file__).resolve().parent
PATTERNS = np.array([
    0, 0x80000000, 0x3f800000, 0xc0000000, 0x00010000, 0x007f0000,
    0x7f800000, 0xff800000, 0x7fc10000, 0xff830000, 0x7f7f0000,
    0x00800000, 0x3f000000,
], dtype='<u4')

with tempfile.TemporaryDirectory(prefix='f32array-tensor-') as tmp:
    tmp = Path(tmp)
    with (tmp / 'tensor-fixture.bin').open('wb') as f:
        f.write(bytes([1, 2, 3]))
        PATTERNS.view('<f4').tofile(f)
        f.seek(100)
        (PATTERNS >> 16).astype('<u2').tofile(f)
        f.seek(2**32 - 3)
        PATTERNS.view('<f4').tofile(f)
        f.seek(2**32 + 100)
        (PATTERNS >> 16).astype('<u2').tofile(f)
    for target, command in [('native', None), ('js', ['bun'])]:
        out = tmp / ('check' if target == 'native' else 'check.js')
        subprocess.run(['bend', str(HERE / 'tensor_check.bend'), '-o', str(out)], check=True)
        subprocess.run([str(out)] if command is None else command + [str(out), '--js'], cwd=tmp, check=True)

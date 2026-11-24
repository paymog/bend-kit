#!/usr/bin/env python3
"""Compare destination reads with allocation plus an element copy (macOS RSS)."""
from pathlib import Path
import re
import statistics
import subprocess
import tempfile
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
subprocess.run(['bend', str(HERE / 'load.bend'), '-o', str(OUT / 'load')], check=True)
with tempfile.TemporaryDirectory(prefix='f32array-load-') as tmp:
    for n in [8, 2**20]:
        np.ones(n, dtype='<f4').tofile(Path(tmp) / 'load.bin')
        for mode in ['into', 'copy']:
            times, rss = [], []
            for _ in range(3):
                run = subprocess.run(['/usr/bin/time', '-l', str(OUT / 'load'), mode, str(n),
                                      '+RTS', '--threads', '1'], cwd=tmp,
                                     capture_output=True, text=True, check=True)
                assert float(re.search(r'^sum (.+)$', run.stdout, re.M)[1]) == n, run.stdout
                times.append(float(re.search(r'^ms (.+)$', run.stdout, re.M)[1]))
                rss.append(int(re.search(r'(\d+)\s+maximum resident set size', run.stderr)[1]))
            print(n, mode, 'ms', statistics.median(times), 'peak_rss_bytes', statistics.median(rss))

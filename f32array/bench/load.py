#!/usr/bin/env python3
"""Compare warm F32/BF16 loads, runtime allocation requests, and process RSS."""
from pathlib import Path
import os
import platform
import re
import statistics
import subprocess
import tempfile
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / 'out'
OUT.mkdir(exist_ok=True)
BEND = os.environ.get('BEND', 'bend')
CC = os.environ.get('CC', 'cc')
SYSTEM = platform.system()
if SYSTEM == 'Darwin':
    TIME_ARGS = ['-l']
    RSS_PATTERN, RSS_SCALE = r'(\d+)\s+maximum resident set size', 1
    CPU = subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip()
elif SYSTEM == 'Linux':
    TIME_ARGS = ['-f', 'peak_rss_kib %M']
    RSS_PATTERN, RSS_SCALE = r'^peak_rss_kib (\d+)$', 1024
    CPU = next((line.split(':', 1)[1].strip()
                for line in Path('/proc/cpuinfo').read_text().splitlines()
                if line.startswith(('model name', 'Hardware'))), platform.machine())
else:
    raise RuntimeError(f'Unsupported RSS platform: {SYSTEM}')
source = OUT / 'load.c'
subprocess.run([BEND, str(HERE / 'load.bend'), '-o', str(source)], check=True)

def instrument(code):
    patches = {
        'INLINE u64 heap_alloc(Env e, u32 cls) {': '''
static _Atomic unsigned long long load_count, load_bytes;
static _Atomic int load_active;
INLINE u64 heap_alloc(Env e, u32 cls) {
  if (atomic_load_explicit(&load_active, memory_order_relaxed)) {
    atomic_fetch_add_explicit(&load_count, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&load_bytes, 8ull << cls, memory_order_relaxed);
  }''',
        'Term mono_raw_run(Env e, Term* f, IoWork* w) {': '''
Term mono_raw_run(Env e, Term* f, IoWork* w) {
  if (atomic_exchange(&load_active, !atomic_load(&load_active))) {
    fprintf(stderr, "alloc_count %llu\\nalloc_bytes %llu\\n",
      atomic_load(&load_count), atomic_load(&load_bytes));
  }''',
    }
    for old, new in patches.items():
        if code.count(old) != 1:
            raise RuntimeError(f'Unsupported Bend runtime: expected one {old!r}')
        code = code.replace(old, new)
    return code

code = source.read_text()
counted = OUT / 'load_counted.c'
counted.write_text(instrument(code))
for src, binary in [(source, OUT / 'load'), (counted, OUT / 'load_counted')]:
    subprocess.run([CC, '-O2', '-std=c11', str(src), '-lm', '-lpthread',
                    '-o', str(binary)], check=True)
print(subprocess.check_output([BEND, 'version'], text=True).strip())
print(platform.platform(), CPU)
print('Python', platform.python_version(), 'NumPy', np.__version__)
print(subprocess.check_output([CC, '--version'], text=True).splitlines()[0], '-O2')

with tempfile.TemporaryDirectory(prefix='f32array-load-') as tmp:
    for n in [8, 2**20]:
        values = (np.arange(n) % 8 - 2).astype('<f4')
        for fmt in ['f32', 'bf16']:
            data = values if fmt == 'f32' else (values.view('<u4') >> 16).astype('<u2')
            path = Path(tmp) / 'load.bin'
            data.tofile(path)
            path.read_bytes()
            for mode in ['into', 'copy']:
                times, rss, counts, sizes = [], [], [], []
                for binary in ['load', 'load_counted']:
                    for _ in range(3):
                        run = subprocess.run(['/usr/bin/time', *TIME_ARGS, str(OUT / binary),
                                              mode, fmt, str(n), '+RTS', '--threads', '1'],
                                             cwd=tmp, capture_output=True, text=True, check=True)
                        assert float(re.search(r'^sum (.+)$', run.stdout, re.M)[1]) == float(
                            values.sum(dtype=np.float64)), run.stdout
                        assert re.search(r'^valid True$', run.stdout, re.M), run.stdout
                        if binary == 'load':
                            times.append(float(re.search(r'^ms (.+)$', run.stdout, re.M)[1]))
                            rss.append(int(re.search(
                                RSS_PATTERN, run.stderr, re.M)[1]) * RSS_SCALE)
                        else:
                            counts.append(int(re.search(r'^alloc_count (\d+)$', run.stderr, re.M)[1]))
                            sizes.append(int(re.search(r'^alloc_bytes (\d+)$', run.stderr, re.M)[1]))
                assert len(set(counts)) == len(set(sizes)) == 1, (counts, sizes)
                print(fmt, n, mode, 'ms', statistics.median(times),
                      'peak_rss_bytes', statistics.median(rss),
                      'runtime_alloc_count', counts[0], 'runtime_alloc_bytes', sizes[0], flush=True)

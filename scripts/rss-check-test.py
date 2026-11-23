#!/usr/bin/env python3
"""Check command status and descendant memory enforcement without large allocations."""
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location('rss_check', Path(__file__).with_name('rss-check.py'))
rss_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rss_check)
assert rss_check.run([sys.executable, '-c', 'pass']) == 0
assert rss_check.run([sys.executable, '-c', 'raise SystemExit(7)']) == 7
rss_check.CEILING_KIB = 32 * 1024
child = 'import time; memory = bytearray(64 * 1024 * 1024); time.sleep(30)'
parent = 'import subprocess, sys; subprocess.run([sys.executable, "-c", sys.argv[1]], check=True)'
assert rss_check.run([sys.executable, '-c', parent, child]) == 1
print('PASS RSS guard: success, failure status, and descendant memory ceiling')

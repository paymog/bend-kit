#!/usr/bin/env python3
"""Check mTLS harness failures and DNS-free fixture startup."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

HTTP = Path(__file__).resolve().parent
TOOL = f'#!{sys.executable}\n' + r'''
import os
from pathlib import Path
import runpy
import socket
import sys

case = os.environ['MTLS_CASE']
args = sys.argv[1:]
if Path(sys.argv[0]).name == 'bend':
    source = Path(args[0]).stem
    if case == f'compile {source}':
        raise SystemExit(23)
    Path(args[args.index('-o') + 1]).touch()
else:
    args = [arg for arg in args if arg != '-u']
    source = Path(args[0]).name
    if source == 'mtls-server.py':
        print('fixture diagnostic marker', flush=True)
        if case == 'server startup':
            raise SystemExit(23)
        def no_dns(*args):
            raise AssertionError('fixture startup must not resolve host names')
        socket.getfqdn = no_dns
        sys.argv = args
        runpy.run_path(args[0], run_name='__main__')
    elif source == 'mtls-server-check.py':
        sys.argv = args
        runpy.run_path(args[0], run_name='__main__')
    elif source == 'loopback-run.py':
        assert os.environ['WIRE_LOOPBACK_ONLY'] == '1'
        program = Path(args[2] if args[1] == 'bun' else args[1]).stem
        if case == f'run {program}':
            raise SystemExit(23)
'''

with tempfile.TemporaryDirectory(prefix='mtls-harness-test-') as temporary:
    root = Path(temporary)
    tools = root / 'bin'
    tools.mkdir()
    for name in ('bend', 'python3'):
        path = tools / name
        path.write_text(TOOL)
        path.chmod(0o755)
    for lane in ('native', 'js'):
        for case in ('compile check', 'compile mtls_check', 'compile h2_pool_check',
                     'server startup', 'run check', 'run mtls_check', 'run h2_pool_check'):
            result = subprocess.run(
                ['sh', str(HTTP / 'mtls-check.sh'), lane], capture_output=True,
                text=True, timeout=30, env={**os.environ,
                    'PATH': f'{tools}{os.pathsep}{os.environ["PATH"]}',
                    'MTLS_CASE': case, 'WIRE_LOOPBACK_ONLY': '1', 'TMPDIR': temporary})
            assert result.returncode == 23, (case, result.returncode, result.stdout, result.stderr)
            phase = case if case == 'server startup' else f'{case} ({lane})'
            assert f'mTLS failed during {phase} (exit 23)' in result.stderr, result.stderr
            if not case.startswith('compile'):
                assert 'fixture diagnostic marker' in result.stderr, result.stderr
            assert 'PRIVATE KEY' not in result.stdout + result.stderr
            assert sorted(path.name for path in root.iterdir()) == ['bin'], list(root.iterdir())
            print(f'PASS {lane}: {case}')

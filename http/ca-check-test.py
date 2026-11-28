#!/usr/bin/env python3
"""Check both private-CA listeners without reverse DNS."""
from http.server import ThreadingHTTPServer
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
from unittest.mock import patch

harness = Path(__file__).with_name('ca-check.sh').read_text()
source = harness.split("cat >\"$dir/server.py\" <<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
with tempfile.TemporaryDirectory(prefix='http-ca-startup-') as directory:
    root = Path(directory)
    cert, key, ports = (root / name for name in ('server.pem', 'server.key', 'ports'))
    subprocess.run([
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
        '-subj', '/CN=localhost', '-keyout', str(key), '-out', str(cert),
    ], check=True, capture_output=True)
    namespace = {}
    with patch.object(socket, 'getfqdn', side_effect=AssertionError('reverse DNS during startup')), \
         patch.object(threading.Thread, 'start'), \
         patch.object(ThreadingHTTPServer, 'serve_forever'), \
         patch.object(sys, 'argv', ['server.py', str(cert), str(key), str(ports)]):
        try:
            exec(compile(source, 'ca-check.sh fixture', 'exec'), namespace)
            listeners = [namespace[name] for name in ('s', 'proxy')]
            assigned = [listener.server_port for listener in listeners]
            assert all(0 < port < 65536 for port in assigned), assigned
            assert assigned[0] != assigned[1], assigned
            assert ports.read_text() == f'{assigned[0]} {assigned[1]}\n'
            for listener in listeners:
                assert listener.server_address == ('127.0.0.1', listener.server_port)
                assert listener.socket.getsockname() == listener.server_address
                assert listener.server_name == 'localhost'
        finally:
            for name in ('s', 'proxy'):
                if name in namespace:
                    namespace[name].server_close()
print('PASS private-CA origin and CONNECT proxy startup without reverse DNS')

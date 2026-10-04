#!/usr/bin/env python3
"""Sequential native/JS real-socket startup and runtime-context acceptance."""
import json
import os
from pathlib import Path
import selectors
import socket
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
CEILING_KIB = 20 * 1024 * 1024
RECEIPTS = []


def monitor(process, stop, samples):
    while not stop.wait(0.1):
        output = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], capture_output=True, text=True).stdout.strip()
        if output:
            rss = int(output)
            samples.append(rss)
            if rss > CEILING_KIB:
                process.kill()


def start(command, **kwargs):
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kwargs)
    stop = threading.Event()
    samples = []
    thread = threading.Thread(target=monitor, args=(process, stop, samples), daemon=True)
    thread.start()
    return process, stop, thread, samples


def finish(handle, prefix='', expected=0):
    process, stop, thread, samples = handle
    try:
        output, _ = process.communicate(timeout=90)
    except BaseException:
        process.kill()
        process.communicate()
        raise
    finally:
        stop.set()
        thread.join()
    output = prefix + output
    receipt = {'command': process.args, 'status': process.returncode, 'output': output, 'peak_sampled_rss_kib': max(samples, default=0)}
    RECEIPTS.append(receipt)
    assert process.returncode == expected, receipt
    return output


def ready(process):
    seen = ''
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            if selector.select(0.1):
                chunk = os.read(process.stdout.fileno(), 4096).decode()
                seen += chunk
                if 'READY\n' in seen:
                    return seen
                assert chunk, seen
        raise AssertionError('no ready signal: ' + seen)
    finally:
        selector.close()


def response(stream, token):
    status = stream.readline()
    assert status == b'HTTP/1.1 200 OK\r\n', status
    headers = {}
    while (line := stream.readline()) != b'\r\n':
        assert line, 'EOF in response headers'
        key, value = line.split(b':', 1)
        headers[key.lower()] = value.strip()
    body = stream.read(int(headers[b'content-length']))
    assert body == token.encode(), body


def run_lane(lane, executable, folder):
    env = dict(os.environ, STARTUP_TOKEN='runtime-created-once-' + lane)
    token = env['STARTUP_TOKEN']
    with socket.socket() as occupied:
        occupied.bind(('127.0.0.1', 0))
        occupied.listen()
        port = occupied.getsockname()[1]
        path = folder / (lane + '-failure')
        output = finish(start(executable + ['bind', str(port), str(path)], env=env))
        assert 'BIND FAILED ' in output and 'READY' not in output
        assert path.read_text() == 'bind recovered\n'
        assert 'OWNER CLOSED' in output
    for field in ('body', 'headers', 'connections', 'requests', 'header_ms', 'body_ms', 'idle_ms', 'write_ms', 'port', 'huge_header_ms', 'huge_body_ms', 'huge_idle_ms', 'huge_write_ms'):
        path = folder / (lane + '-' + field)
        output = finish(start(executable + [field, str(port), str(path)], env=env))
        assert 'INVALID\n' in output and 'READY' not in output
        assert path.read_text() == 'invalid recovered\n'
    with socket.socket() as reserved:
        reserved.bind(('127.0.0.1', 0))
        port = reserved.getsockname()[1]
    path = folder / (lane + '-success')
    handle = start(executable + ['success', str(port), str(path)], env=env)
    try:
        prefix = ready(handle[0])
        # Connection one: ordered pipeline, same runtime channel and token.
        with socket.create_connection(('127.0.0.1', port), timeout=5) as client:
            client.sendall(b'GET /one HTTP/1.1\r\nHost: localhost\r\n\r\nGET /two HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n')
            with client.makefile('rb') as stream:
                response(stream, token)
                response(stream, token)
                assert stream.read(1) == b''
        # Connection two receives the same context, not a reconstructed one.
        with socket.create_connection(('127.0.0.1', port), timeout=5) as client:
            client.sendall(b'GET /three HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n')
            with client.makefile('rb') as stream:
                response(stream, token)
                assert stream.read(1) == b''
        output = finish(handle, prefix)
        assert output.count('CONTEXT CREATED') == 1 and 'THREE CALLS' in output
        assert path.read_text() == 'success recovered\n'
    finally:
        if handle[0].poll() is None:
            handle[0].kill()
            finish(handle)
    # Exercise the public continuous loop too; host termination is not graceful drain.
    handle = start(executable + ['run', str(port), str(folder / (lane + '-run'))], env=env)
    try:
        prefix = ready(handle[0])
        with socket.create_connection(('127.0.0.1', port), timeout=5) as client:
            client.sendall(b'GET /run HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n')
            with client.makefile('rb') as stream:
                response(stream, token)
                assert stream.read(1) == b''
        handle[0].terminate()
        finish(handle, prefix, expected=-15)
    finally:
        if handle[0].poll() is None:
            handle[0].kill()
            finish(handle, expected=-9)
    print(lane + ': bind rollback, thirteen invalid configs, accepting readiness, three shared-context requests PASS')


def main():
    assert os.statvfs(ROOT).f_bavail * os.statvfs(ROOT).f_frsize > 10 * 1024**3, 'less than 10GiB disk headroom'
    with tempfile.TemporaryDirectory(prefix='http-startup-') as directory:
        folder = Path(directory)
        native = folder / 'startup'
        js = folder / 'startup.js'
        finish(start(['bend', 'http/startup_check.bend', '-o', str(native)]))
        run_lane('native', [str(native), '--threads', '1', '--gpu', 'off'], folder)
        finish(start(['bend', 'http/startup_check.bend', '-o', str(js)]))
        run_lane('js', ['bun', str(js)], folder)
    (ROOT / 'http/startup_results.json').write_text(json.dumps(RECEIPTS, indent=2) + '\n')


if __name__ == '__main__':
    main()

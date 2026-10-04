#!/usr/bin/env python3
"""Compile and exercise shared production limits in native and JS, sequentially."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

import startup_check as Harness

ROOT = Path(__file__).resolve().parent.parent
RESULTS = []


def connect(port):
    return socket.create_connection(('127.0.0.1', port), timeout=5)


def response(reader):
    line = reader.readline()
    assert line.startswith(b'HTTP/1.1 '), line
    status = int(line.split()[1])
    headers = {}
    while (line := reader.readline()) != b'\r\n':
        assert line, 'EOF in headers'
        key, value = line.split(b':', 1)
        headers[key.lower()] = value.strip()
    return status, reader.read(int(headers[b'content-length'])), headers


def request(path=b'/', framing=b'', body=b'', close=True):
    return (b'POST ' + path + b' HTTP/1.1\r\nHost: x\r\n' + framing
            + (b'Connection: close\r\n' if close else b'') + b'\r\n' + body)


def expected(mode, body):
    return str(len(body)).encode() if mode == 'stream' else body


def record(lane, mode, name, start, **details):
    RESULTS.append(dict(lane=lane, mode=mode, case=name, elapsed_s=round(time.monotonic() - start, 3), **details))


def exchange(port, lane, mode, name, data, status, body=None, eof=True):
    start = time.monotonic()
    with connect(port) as client:
        client.sendall(data)
        with client.makefile('rb') as reader:
            got, payload, headers = response(reader)
            assert got == status, (name, got, payload)
            if body is not None:
                assert payload == body, (name, payload, body)
            if eof:
                assert reader.read(1) == b'', name
    record(lane, mode, name, start, status=got, body_hex=payload.hex())


def expiry(port, lane, mode, name, prefix, pieces=(), idle_delay=0):
    with connect(port) as client:
        if idle_delay:
            time.sleep(idle_delay)
        start = time.monotonic()
        client.sendall(prefix)
        for piece in pieces:
            time.sleep(0.15)
            client.sendall(piece)
        with client.makefile('rb') as reader:
            status, body, headers = response(reader)
            elapsed = time.monotonic() - start
            assert status == 408, (name, status)
            assert 0.45 <= elapsed < 0.9, (name, elapsed)
            assert headers[b'connection'] == b'close'
            assert reader.read(1) == b''
        record(lane, mode, name, start, status=status, response_elapsed_s=round(elapsed, 3))


def cases(port, lane, mode, handle):
    data = bytes([0, 255, 128, 13, 10, 1, 2, 3])
    exchange(port, lane, mode, 'fixed-at-cap-binary', request(framing=b'Content-Length: 8\r\n', body=data), 200, expected(mode, data))
    chunked = b'1;x=y\r\n' + data[:1] + b'\r\n7\r\n' + data[1:] + b'\r\n0\r\nTrailer: yes\r\n\r\n'
    exchange(port, lane, mode, 'chunked-at-decoded-cap-with-framing', request(framing=b'Transfer-Encoding: chunked\r\n', body=chunked), 200, expected(mode, data))
    for name, raw, status in (
        ('oversize-header', request(framing=b'X-Pad: ' + b'a' * 128 + b'\r\n'), 431),
        ('partial-oversize-header', b'GET / HTTP/1.1\r\nX-Pad: ' + b'a' * 128, 431),
        ('fixed-over-cap', request(framing=b'Content-Length: 9\r\n', body=b'123456789'), 413),
        ('chunked-over-cap', request(framing=b'Transfer-Encoding: chunked\r\n', body=b'9\r\n123456789\r\n0\r\n\r\n'), 413),
        ('chunked-over-cap-across-reads', None, 413),
        ('bad-chunk-size', request(framing=b'Transfer-Encoding: chunked\r\n', body=b'z\r\n'), 400),
        ('conflicting-framing', request(framing=b'Content-Length: 1\r\nTransfer-Encoding: chunked\r\n'), 400),
        ('conflicting-content-length', request(framing=b'Content-Length: 1\r\nContent-Length: 2\r\n'), 400),
    ):
        if raw is None:
            with connect(port) as client:
                start = time.monotonic()
                client.sendall(request(framing=b'Transfer-Encoding: chunked\r\n', body=b'5\r\n12345\r\n', close=False))
                time.sleep(0.1)
                client.sendall(b'4\r\n6789\r\n0\r\n\r\n')
                with client.makefile('rb') as reader:
                    assert response(reader)[0] == 413
                    assert reader.read(1) == b''
                record(lane, mode, name, start, status=413)
        else:
            exchange(port, lane, mode, name, raw, status)
    # Exact complete header boundary includes the terminating CRLFCRLF.
    base = request(framing=b'X-Pad: \r\n')
    exact = request(framing=b'X-Pad: ' + b'a' * (128 - len(base)) + b'\r\n')
    assert len(exact) == 128
    exchange(port, lane, mode, 'header-at-cap', exact, 200, expected(mode, b''))
    fixed_head = request(framing=b'Content-Length: 8\r\nX-Pad: \r\n')
    together = request(framing=b'Content-Length: 8\r\nX-Pad: '
                       + b'a' * (128 - len(fixed_head)) + b'\r\n', body=data)
    assert len(together) == 136
    exchange(port, lane, mode, 'independent-header-and-body-at-cap-one-send',
             together, 200, expected(mode, data))
    start = time.monotonic()
    with connect(port) as client:
        client.sendall(request(framing=b'Transfer-Encoding: chunked\r\n', body=chunked, close=False) + request(body=b''))
        with client.makefile('rb') as reader:
            first = response(reader)
            second = response(reader)
            assert first[:2] == (200, expected(mode, data)), first
            assert second[:2] == (200, expected(mode, b'')), second
            if mode == 'whole':
                assert first[2][b'x-context'] == second[2][b'x-context'] == b'runtime-' + lane.encode()
            assert reader.read(1) == b''
    record(lane, mode, 'chunked-pipeline-shared-context', start, status=200)
    expiry(port, lane, mode, 'header-trickle-nonresetting', b'G', (b'E', b'T', b' '))
    expiry(port, lane, mode, 'partial-header', b'GET / HTTP/1.1\r\nHost: x\r\n')
    expiry(port, lane, mode, 'header-starts-at-first-byte', b'G', idle_delay=0.4)
    expiry(port, lane, mode, 'fixed-body-trickle-nonresetting', request(framing=b'Content-Length: 8\r\n', body=b'a', close=False), (b'b', b'c', b'd'))
    expiry(port, lane, mode, 'partial-fixed-body', request(framing=b'Content-Length: 8\r\n', body=b'a', close=False))
    expiry(port, lane, mode, 'chunked-body-trickle-nonresetting', request(framing=b'Transfer-Encoding: chunked\r\n', body=b'8\r\na', close=False), (b'b', b'c', b'd'))
    start = time.monotonic()
    with connect(port) as client:
        client.sendall(request(close=False))
        with client.makefile('rb') as reader:
            assert response(reader)[:2] == (200, expected(mode, b''))
            idle_start = time.monotonic()
            assert reader.read(1) == b''
            elapsed = time.monotonic() - idle_start
            assert 0.65 <= elapsed < 1.4, elapsed
    record(lane, mode, 'keepalive-idle-silent-close', start, idle_elapsed_s=round(elapsed, 3))
    start = time.monotonic()
    with connect(port) as client:
        assert client.recv(1) == b''
        elapsed = time.monotonic() - start
        assert 0.65 <= elapsed < 1.4, elapsed
    record(lane, mode, 'initial-idle-silent-close', start)
    start = time.monotonic()
    with connect(port) as client:
        client.sendall(request(close=False) + b'G')
        with client.makefile('rb') as reader:
            assert response(reader)[:2] == (200, expected(mode, b''))
            assert response(reader)[0] == 408
            assert reader.read(1) == b''
    record(lane, mode, 'keepalive-pipelined-partial-header', start, status=408)
    # No handler-work timeout: the whole handler sleeps beyond every read/write budget.
    if mode == 'whole':
        exchange(port, lane, mode, 'handler-not-cancelled-or-timed-out', request(path=b'/cpu', framing=b'Content-Length: 1\r\n', body=b'x'), 200, b'x')
    if mode == 'stream':
        with connect(port) as client:
            start = time.monotonic()
            client.sendall(request(path=b'/discard', framing=b'Content-Length: 8\r\n', body=b'abc', close=False))
            time.sleep(0.1)
            client.sendall(b'defgh' + request())
            with client.makefile('rb') as reader:
                assert response(reader)[:2] == (200, b'3')
                assert response(reader)[:2] == (200, b'0')
                assert reader.read(1) == b''
            record(lane, mode, 'discard-and-pipeline', start, status=200)
        with connect(port) as client:
            start = time.monotonic()
            client.sendall(request(close=False) + request(path=b'/slow-start',
                framing=b'Content-Length: 8\r\n', body=b'abc', close=False))
            with client.makefile('rb') as reader:
                assert response(reader)[:2] == (200, b'0')
                assert response(reader)[0] == 408
                elapsed = time.monotonic() - start
                assert 0.45 <= elapsed < 0.9, elapsed
                assert reader.read(1) == b''
            record(lane, mode, 'pipelined-body-phase-starts-before-upload-callback',
                   start, status=408)
    if mode == 'writer':
        start = time.monotonic()
        with connect(port) as client:
            client.sendall(request(path=b'/progress', close=False))
            with client.makefile('rb') as reader:
                status, payload, headers = response(reader)
                elapsed = time.monotonic() - start
                assert status == 200 and 0 < len(payload) < 8, (status, payload)
                assert 0.45 <= elapsed < 1.15, elapsed
                assert reader.read(1) == b''
        record(lane, mode, 'writer-progress-nonresetting-close-before-callback-return', start,
               received_prefix_hex=payload.hex())
    start = time.monotonic()
    with connect(port) as client:
        client.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024)
        client.sendall(request(path=b'/large', close=False))
        time.sleep(1.3)
        client.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
        accepted = 0
        while block := client.recv(65536):
            accepted += len(block)
        assert 0 < accepted < 16777216, accepted
    record(lane, mode, 'slow-reader-bounded-write-close', start, received_prefix_bytes=accepted)


def run_lane(lane, command):
    for mode in ('whole', 'stream', 'writer'):
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1', 0))
            port = reserved.getsockname()[1]
        handle = Harness.start(command + [mode, str(port)], env=dict(os.environ, LIMITS_CONTEXT='runtime-' + lane))
        try:
            for _ in range(100):
                try:
                    with connect(port):
                        break
                except OSError:
                    assert handle[0].poll() is None, handle[0].communicate()
                    time.sleep(0.05)
            else:
                raise AssertionError('server not accepting')
            cases(port, lane, mode, handle)
            handle[0].terminate()
            output = Harness.finish(handle, expected=-15)
            if mode == 'writer':
                assert 'WRITE_FAILED_CLOSED' in output, output
            print(f'{lane}/{mode}: shared size/phase socket scenarios PASS', flush=True)
        finally:
            if handle[0].poll() is None:
                handle[0].kill()
                Harness.finish(handle, expected=-9)


def main():
    assert os.statvfs(ROOT).f_bavail * os.statvfs(ROOT).f_frsize > 10 * 1024**3, 'less than 10GiB disk headroom'
    try:
        with tempfile.TemporaryDirectory(prefix='http-limits-') as directory:
            folder = Path(directory)
            for lane, suffix in (('native', ''), ('js', '.js')):
                target = folder / ('limits' + suffix)
                Harness.finish(Harness.start(['bend', 'http/limits_check.bend', '-o', str(target)]))
                command = [str(target), '--threads', '1', '--gpu', 'off'] if lane == 'native' else ['bun', str(target)]
                run_lane(lane, command)
    finally:
        (ROOT / 'http/limits_results.json').write_text(json.dumps(dict(scenarios=RESULTS, commands=Harness.RECEIPTS), indent=2) + '\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Sequential native/JS production bursts; all observations are real copied counts."""
import json
import os
from pathlib import Path
import socket
import struct
import tempfile
import threading
import time

import startup_check as Harness

ROOT = Path(__file__).resolve().parent.parent
RESULTS = []


def request(path, body=b'', close=True, method='POST'):
    return (method.encode() + b' ' + path.encode() + b' HTTP/1.1\r\nHost: x\r\n'
            + b'Content-Length: ' + str(len(body)).encode() + b'\r\n'
            + (b'Connection: close\r\n' if close else b'') + b'\r\n' + body)


def response(client):
    with client.makefile('rb') as reader:
        line = reader.readline()
        assert line.startswith(b'HTTP/1.1 '), line
        status = int(line.split()[1])
        headers = {}
        while (line := reader.readline()) != b'\r\n':
            assert line, 'EOF in response headers'
            key, value = line.split(b':', 1)
            headers[key.lower()] = value.strip()
        if b'content-length' in headers:
            body = reader.read(int(headers[b'content-length']))
        elif headers.get(b'transfer-encoding') == b'chunked':
            body = b''
            while (size := int(reader.readline().strip(), 16)):
                body += reader.read(size)
                assert reader.read(2) == b'\r\n'
            assert reader.readline() == b'\r\n'
        else:
            body = b''
        assert reader.read(1) == b'', 'response must close'
        return status, body, headers


class Server:
    def __init__(self, command, lane, mode, profile, folder):
        self.lane, self.mode, self.profile = lane, mode, profile
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1', 0))
            self.port = reserved.getsockname()[1]
        self.path = folder / f'{lane}-{mode}-{profile}.journal'
        self.handle = Harness.start(command + [mode, profile, str(self.port)],
                                    env=dict(os.environ, ADMISSION_JOURNAL=str(self.path)))
        self.lines, self.counts = [], []
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()
        self.wait(lambda: 'READY' in self.lines)

    def read(self):
        for line in self.handle[0].stdout:
            line = line.strip()
            self.lines.append(line)
            if line.startswith('COUNTS '):
                counts = tuple(map(int, line.removeprefix('COUNTS ').split(',')))
                self.counts.append(counts)

    def wait(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            assert self.handle[0].poll() is None, self.lines
            time.sleep(0.01)
        raise AssertionError((self.lane, self.mode, self.profile, self.lines[-20:]))

    def state(self, c, a, b):
        self.wait(lambda: bool(self.counts) and self.counts[-1][:3] == (c, a, b))

    def effect(self, line):
        self.wait(lambda: 'EFFECT ' + line in self.lines)

    def connect(self):
        return socket.create_connection(('127.0.0.1', self.port), timeout=5)

    def exchange(self, path, expected, body=b''):
        with self.connect() as client:
            client.sendall(request(path, body))
            status, payload, headers = response(client)
            assert status == expected, (path, status, payload)
            assert headers[b'connection'] == b'close', headers
            if expected == 200:
                assert payload == (str(len(body)).encode() if self.mode == 'stream' else body), payload

    def close(self):
        process, stop, monitor, samples = self.handle
        try:
            process.terminate()
            process.wait(timeout=5)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            stop.set()
            monitor.join()
            self.reader.join(timeout=5)
            process.stdout.close()
        caps = (2 if self.profile == 'connections' else 16,
                2 if self.profile == 'active' else 16,
                2 if self.profile == 'buffered' else 16)
        assert self.counts
        for row in self.counts:
            assert all(0 <= row[i] <= caps[i] for i in range(3)), (caps, row)
            assert all(row[i] <= row[i + 3] <= caps[i] for i in range(3)), (caps, row)
            assert row[0] == row[2], row
        RESULTS.append(dict(lane=self.lane, mode=self.mode, profile=self.profile,
                            caps=caps, counts=self.counts, journal=self.path.read_text() if self.path.exists() else '',
                            command=process.args, exit_status=process.returncode,
                            peak_sampled_rss_kib=max(samples, default=0)))


def unsafe_close(client):
    try:
        assert client.recv(1) == b'', 'unsafe excess must not receive an HTTP response'
    except ConnectionResetError:
        pass  # An unsafe, unread socket is explicitly allowed to reset.


def socket_burst(server):
    held = [server.connect() for _ in range(2)]
    try:
        server.state(2, 0, 2)
        # Independent cap bursts: no request bytes or business callbacks retained.
        for _ in range(8):
            with server.connect() as excess:
                unsafe_close(excess)
        rejection_index = 6 if server.profile == 'connections' else 8
        server.wait(lambda: server.counts[-1][rejection_index] == 8)
        assert not any(line.startswith('EFFECT ') for line in server.lines)
        # Partial headers own the reserved work unit before any callback.
        for client in held:
            client.sendall(b'POST /partial HTTP/1.1\r\nX-Partial: ')
        server.state(2, 0, 2)
        assert not any(line.startswith('EFFECT ') for line in server.lines)
    finally:
        for client in held:
            client.close()
    server.state(0, 0, 0)
    server.exchange('/recovered', 200, b'healthy')
    server.state(0, 0, 0)
    assert server.counts[-1][rejection_index] == 8


def active_burst(server):
    held = [server.connect() for _ in range(2)]
    for i, client in enumerate(held):
        client.sendall(request(f'/hold-{i}', b'hi'))
    server.effect('start /hold-0')
    server.effect('start /hold-1')
    server.state(2, 2, 2)
    # Close peers while their original callbacks are actually sleeping.
    for client in held:
        client.close()
    server.state(2, 2, 2)
    for i in range(8):
        server.exchange(f'/rejected-{i}', 503)
    with server.connect() as rejected:
        rejected.sendall(request('/rejected-head', method='HEAD'))
        status, body, headers = response(rejected)
        assert status == 503 and body == b'' and headers[b'connection'] == b'close'
    server.wait(lambda: server.counts[-1][7] == 9)
    assert not any('start /rejected-' in line for line in server.lines)
    assert not any('return /hold-' in line for line in server.lines), server.lines
    server.effect('return /hold-0')
    server.effect('return /hold-1')
    server.state(0, 0, 0)
    server.exchange('/recovered', 200, b'healthy')
    server.state(0, 0, 0)
    assert server.counts[-1][4] == 2 and server.counts[-1][7] == 9

    # Pipeline storage stays inside its connection reservation; subsequent callbacks
    # do not run while the first operation holds that same socket and its remainder.
    client = server.connect()
    client.sendall(request('/hold-pipeline', close=False)
                   + b''.join(request(f'/queued-{i}', close=False) for i in range(2048)))
    server.effect('start /hold-pipeline')
    server.state(1, 1, 1)
    assert not any('start /queued-' in line for line in server.lines)
    client.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
    client.close()
    server.state(1, 1, 1)
    server.effect('return /hold-pipeline')
    server.state(0, 0, 0)
    assert not any('start /queued-' in line for line in server.lines)

    # Body truncation/read expiry release transport capacity, not new business work.
    before = len([line for line in server.lines if line.startswith('EFFECT start')])
    with server.connect() as partial:
        partial.sendall(b'POST /short HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\nx')
        server.wait(lambda: server.counts[-1][0] == 1)
        if server.mode == 'stream':
            server.effect('start /short')  # Stream callbacks intentionally start after headers.
        partial.shutdown(socket.SHUT_WR)
        status, _, _ = response(partial)
        assert status == 400
    server.state(0, 0, 0)
    with server.connect() as partial:
        partial.sendall(b'POST /slow HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\nx')
        status, _, _ = response(partial)
        assert status == 408
    server.state(0, 0, 0)
    after = len([line for line in server.lines if line.startswith('EFFECT start')])
    assert after - before == (2 if server.mode == 'stream' else 0)

    if server.mode == 'writer':
        failed = [server.connect() for _ in range(2)]
        for i, client in enumerate(failed):
            client.sendall(request(f'/failed-{i}', b'prefix'))
            assert client.recv(4096).startswith(b'HTTP/1.1 200')
            client.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
            client.close()
        server.state(2, 2, 2)
        server.effect('write-aborted /failed-0')
        server.effect('write-aborted /failed-1')
        server.exchange('/failed-replacement', 503)
        assert 'EFFECT start /failed-replacement' not in server.lines
        assert not any('writer-return /failed-' in line for line in server.lines)
        server.effect('writer-return /failed-0')
        server.effect('writer-return /failed-1')
        server.state(0, 0, 0)
        server.exchange('/writer-recovered', 200, b'ok')
        server.state(0, 0, 0)


def main():
    stats = os.statvfs(ROOT)
    assert stats.f_bavail * stats.f_frsize >= 10 * 1024**3
    try:
        with tempfile.TemporaryDirectory(prefix='http-admission-') as directory:
            folder = Path(directory)
            for lane, suffix in (('native', ''), ('js', '.js')):
                target = folder / ('admission' + suffix)
                Harness.finish(Harness.start(['bend', 'http/admission_check.bend', '-o', str(target)]))
                command = [str(target), '--threads', '1', '--gpu', 'off'] if lane == 'native' else ['bun', str(target)]
                stats_path = folder / (lane + '-stats-close.journal')
                output = Harness.finish(Harness.start(command + ['stats-close', 'active', '0'],
                    env=dict(os.environ, ADMISSION_JOURNAL=str(stats_path))))
                assert output.count('POST CLOSED') == 128 and output.count('STATS CLOSED') == 2 and 'OBSERVERS JOINED' in output, output
                RESULTS.append(dict(lane=lane, case='public-concurrent-and-post-close-stats', post_close_reads=128, output=output))
                for mode in ('whole', 'stream', 'writer'):
                    for profile in ('connections', 'buffered', 'active'):
                        server = Server(command, lane, mode, profile, folder)
                        try:
                            (active_burst if profile == 'active' else socket_burst)(server)
                        finally:
                            server.close()
                        print(f'{lane}/{mode}/{profile}: exact bounds, rejection journal, release/recovery PASS', flush=True)
    finally:
        (ROOT / 'http/admission_results.json').write_text(json.dumps(dict(scenarios=RESULTS, commands=Harness.RECEIPTS), indent=2) + '\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Actual native/JS response outcomes; resets are RST, not inferred from FIN."""
import json
import os
from pathlib import Path
import socket
import struct
import tempfile
import threading
import time

import admission_check as Admission
import startup_check as Harness

ROOT = Path(__file__).resolve().parent.parent
RESULTS = []


class Server:
    def __init__(self, command, lane, mode, folder):
        self.lane, self.mode = lane, mode
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1', 0))
            self.port = reserved.getsockname()[1]
        self.path = folder / f'{lane}-{mode}.journal'
        self.handle = Harness.start(command + [mode, str(self.port)],
                                    env=dict(os.environ, ADMISSION_JOURNAL=str(self.path)))
        self.lines = []
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()
        # No readiness is invented for the convenience/config wrapper API.
        deadline = time.monotonic() + 10
        while True:
            try:
                with self.connect():
                    break
            except OSError:
                assert self.handle[0].poll() is None, self.lines
                assert time.monotonic() < deadline, self.lines
                time.sleep(0.02)

    def read(self):
        for line in self.handle[0].stdout:
            self.lines.append(line.strip())

    def journal(self):
        return self.path.read_text().splitlines() if self.path.exists() else []

    def wait(self, predicate, timeout=8):
        deadline = time.monotonic() + timeout
        while not predicate():
            assert self.handle[0].poll() is None, self.lines
            assert time.monotonic() < deadline, (self.mode, self.journal(), self.lines[-20:])
            time.sleep(0.01)

    def connect(self):
        return socket.create_connection(('127.0.0.1', self.port), timeout=8)

    def owners(self):
        return [line for line in self.journal() if line.startswith('owner ')]

    def complete(self, before, status, outcome, path=None, stage=None):
        self.wait(lambda: len(self.owners()) > before)
        if path is not None:
            self.wait(lambda: 'completed ' + path in self.journal())
        time.sleep(0.04)
        assert len(self.owners()) == before + 1, self.journal()
        owner = self.owners()[-1].split()
        assert int(owner[1]) == status and owner[2].startswith(outcome), owner
        if path is not None:
            rows = [line for line in self.journal() if line.startswith('payload ' + path + ' ')]
            assert len(rows) == 1, rows
            fields = rows[0].split()
            assert int(fields[2]) == stage and int(fields[3]) == status, rows
            assert fields[4] == owner[2], rows
        RESULTS.append(dict(lane=self.lane, mode=self.mode, case=path or f'generated-{status}',
                            owner=self.owners()[-1], stage=stage))

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
        RESULTS.append(dict(lane=self.lane, mode=self.mode, case='process-release',
                            command=process.args, status=process.returncode,
                            peak_sampled_rss_kib=max(samples, default=0),
                            journal=self.journal(), output=self.lines))
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1', self.port))


def receive(client):
    parts = []
    while True:
        try:
            part = client.recv(65536)
        except ConnectionResetError:
            break  # Failed/early close may reset unread client input; bytes stay recorded.
        if not part:
            break
        parts.append(part)
    return b''.join(parts)


def reset(client):
    client.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
    client.close()


def happy(server):
    stage = 3 if server.mode.startswith('stream') else 2
    for path, method, status in (('/ok', 'GET', 200), ('/head', 'HEAD', 200),
                                 ('/204', 'GET', 204), ('/304', 'GET', 304)):
        before = len(server.owners())
        with server.connect() as client:
            client.sendall(Admission.request(path, method=method))
            wire = receive(client)
        head, body = wire.split(b'\r\n\r\n', 1)
        assert int(head.split()[1]) == status, wire
        if method == 'HEAD' or status in (204, 304):
            assert body == b'', wire
        else:
            assert b'ok' in body, wire
        server.complete(before, status, 'accepted', path,
                        1 if server.mode.startswith('writer') and not body else stage)
        assert server.journal().count('business ' + path) == 1, server.journal()


def generated(server):
    for request, status in ((b'POST /bad HTTP/1.1\r\nHost: x\r\nContent-Length: no\r\n\r\n', 400),
                            (Admission.request('/oversize', b'123456789'), 413)):
        before = len(server.owners())
        business = len([line for line in server.journal() if line.startswith('business ')])
        with server.connect() as client:
            client.sendall(request)
            wire = receive(client)
        assert wire.startswith(f'HTTP/1.1 {status} '.encode()), wire
        server.complete(before, status, 'accepted')
        assert len([line for line in server.journal() if line.startswith('business ')]) == business
    if '-convenience' not in server.mode:
        before = len(server.owners())
        with server.connect() as client:
            client.sendall(b'POST /late HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nx')
            wire = receive(client)
        assert wire.startswith(b'HTTP/1.1 408 '), wire
        server.complete(before, 408, 'accepted')


def continue_response(server):
    before = len(server.owners())
    with server.connect() as client:
        client.sendall(b'POST /continue HTTP/1.1\r\nHost: x\r\nExpect: 100-continue\r\nContent-Length: 2\r\nConnection: close\r\n\r\n')
        interim = b''
        while b'\r\n\r\n' not in interim:
            interim += client.recv(1024)
        assert interim == b'HTTP/1.1 100 Continue\r\n\r\n', interim
        assert len(server.owners()) == before, server.journal()
        client.sendall(b'ok')
        assert receive(client).startswith(b'HTTP/1.1 200 ')
    server.complete(before, 200, 'accepted', '/continue', 3 if server.mode.startswith('stream') else 2)


def failed_write(server, path='/reset'):
    before = len(server.owners())
    client = server.connect()
    client.sendall(Admission.request(path))
    server.wait(lambda: 'business ' + path in server.journal())
    prefix = b''
    if path == '/partial':
        while b'prefix-' not in prefix:
            prefix += client.recv(1024)
    reset(client)
    if path == '/partial':
        server.wait(lambda: 'writer-written ' + path in server.journal())
        assert len(server.owners()) == before, server.journal()
        assert 'writer-return ' + path not in server.journal(), server.journal()
    stage = 1 if path == '/header-reset' else (3 if server.mode.startswith('stream') else 2)
    server.complete(before, 200, 'failed:', path, stage)
    assert server.journal().count('business ' + path) == 1, server.journal()
    if path == '/header-reset':
        assert 'writer-enter ' + path not in server.journal(), server.journal()
    if prefix:
        RESULTS[-1]['committed_prefix_hex'] = prefix.hex()
        assert prefix.count(b'HTTP/1.1 ') == 1, prefix


def writer_boundaries(server):
    for path, expected_length, expected_body in (
            ('/known-short', 12, b'prefix-ok'),
            ('/known-overshoot', 8, b'prefix-')):
        before = len(server.owners())
        with server.connect() as client:
            client.sendall(Admission.request(path))
            wire = receive(client)
        head, body = wire.split(b'\r\n\r\n', 1)
        assert head.startswith(b'HTTP/1.1 200 ') and f'content-length: {expected_length}'.encode() in head.lower(), wire
        assert body == expected_body and wire.count(b'HTTP/1.1 ') == 1, wire
        server.complete(before, 200, 'incomplete', path, 2)
        RESULTS[-1]['committed_prefix_hex'] = wire.hex()
    before = len(server.owners())
    client = server.connect()
    client.sendall(Admission.request('/terminator-reset'))
    prefix = b''
    while not prefix.endswith(b'2\r\nok\r\n'):
        prefix += client.recv(1024)
    server.wait(lambda: 'writer-written /terminator-reset' in server.journal())
    assert len(server.owners()) == before and b'0\r\n\r\n' not in prefix, prefix
    reset(client)
    server.complete(before, 200, 'failed:', '/terminator-reset', 2)
    assert server.journal().count('writer-return /terminator-reset') == 1
    RESULTS[-1]['committed_prefix_hex'] = prefix.hex()


def deadline(server):
    before = len(server.owners())
    with server.connect() as client:
        client.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024)
        client.sendall(Admission.request('/deadline'))
        if server.mode == 'writer':
            server.wait(lambda: 'writer-written /deadline' in server.journal())
            assert len(server.owners()) == before and 'writer-return /deadline' not in server.journal()
        server.complete(before, 200, 'failed:', '/deadline', 3 if server.mode == 'stream' else 2)
        # Local acceptance is not receipt: retain only the prefix actually read.
        prefix = client.recv(4096)
        assert prefix.startswith(b'HTTP/1.1 200 '), prefix
        assert prefix.count(b'HTTP/1.1 ') == 1, prefix
        RESULTS[-1]['committed_prefix_hex'] = prefix.hex()
        client.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)
        committed = prefix + receive(client)
        assert len(committed) < 16777216, 'deadline must leave an incomplete response'
        assert committed.count(b'HTTP/1.1 ') == 1, 'failed prefix must never replay'
        RESULTS[-1]['received_bytes_before_terminal_close'] = len(committed)


def disposable(server):
    for path in ('/absent', '/closed'):
        before = len(server.owners())
        with server.connect() as client:
            client.sendall(Admission.request(path))
            assert receive(client).startswith(b'HTTP/1.1 200 ')
        server.complete(before, 200, 'accepted')
        assert not any(line.startswith('payload ' + path + ' ') for line in server.journal())
    # A subsequent request proves transport/admission recovery after observer disposal.
    before = len(server.owners())
    with server.connect() as client:
        client.sendall(Admission.request('/recovered'))
        assert receive(client).startswith(b'HTTP/1.1 200 ')
    server.complete(before, 200, 'accepted', '/recovered', 3 if server.mode.startswith('stream') else 2)


def held_completion(server):
    before = len(server.owners())
    with server.connect() as client:
        client.sendall(Admission.request('/completion-hold'))
        server.wait(lambda: any(line.startswith('payload /completion-hold ') for line in server.journal()))
        time.sleep(0.1)
        counts = [tuple(map(int, line.removeprefix('COUNTS ').split(',')))
                  for line in server.lines if line.startswith('COUNTS ')]
        assert counts and counts[-1][:3] == (1, 1, 1), counts[-10:]
        assert 'completed /completion-hold' not in server.journal()
        assert receive(client).startswith(b'HTTP/1.1 200 ')
    server.complete(before, 200, 'accepted', '/completion-hold', 2)
    server.wait(lambda: any(line.startswith('COUNTS 0,0,0,') for line in server.lines[-10:]))


def late_observer(command, lane, folder):
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    journal = folder / (lane + '-late.journal')
    handle = Harness.start(command + ['late', str(port)],
                           env=dict(os.environ, ADMISSION_JOURNAL=str(journal)))
    try:
        prefix = Harness.ready(handle[0])
        with socket.create_connection(('127.0.0.1', port), timeout=5) as client:
            client.sendall(Admission.request('/late'))
            assert receive(client).endswith(b'ok')
        output = Harness.finish(handle, prefix)
    except BaseException:
        if handle[0].poll() is None:
            handle[0].kill()
            Harness.finish(handle, expected=handle[0].wait())
        raise
    assert output.index('TRANSPORT RETURNED BEFORE OBSERVER RECEIVE') < output.index('EFFECT late-observed'), output
    rows = journal.read_text().splitlines()
    assert rows == ['owner-stats 1 1 1', 'owner 200 accepted', 'late-observed /late accepted'], rows
    RESULTS.append(dict(lane=lane, case='late-observer-after-transport-return', journal=rows, output=output))
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind(('127.0.0.1', port))


def main():
    stats = os.statvfs(ROOT)
    assert stats.f_bavail * stats.f_frsize >= 10 * 1024 ** 3, 'less than 10 GiB disk headroom'
    try:
        with tempfile.TemporaryDirectory(prefix='http-outcome-') as directory:
            folder = Path(directory)
            for lane, suffix in (('native', ''), ('js', '.js')):
                target = folder / ('outcome' + suffix)
                Harness.finish(Harness.start(['bend', 'http/outcome_check.bend', '-o', str(target)]))
                command = [str(target), '--threads', '1', '--gpu', 'off'] if lane == 'native' else ['bun', str(target)]
                late_observer(command, lane, folder)
                for mode in ('whole', 'stream', 'writer', 'whole-convenience', 'stream-convenience', 'writer-convenience'):
                    server = Server(command, lane, mode, folder)
                    try:
                        happy(server)  # Small actual socket input precedes adverse large writes.
                        generated(server)
                        continue_response(server)
                        failed_write(server)
                        if mode.startswith('writer'):
                            failed_write(server, '/header-reset')
                            failed_write(server, '/partial')
                            writer_boundaries(server)
                        if '-convenience' not in mode:
                            deadline(server)
                        disposable(server)
                        if mode == 'whole':
                            held_completion(server)
                    except BaseException as error:
                        RESULTS.append(dict(lane=lane, mode=mode, adverse=repr(error)))
                        raise
                    finally:
                        server.close()
                    print(f'{lane}/{mode}: real outcomes, typed payload, effects once, observer disposal PASS', flush=True)
    finally:
        (ROOT / 'http/outcome_results.json').write_text(json.dumps(dict(scenarios=RESULTS, commands=Harness.RECEIPTS), indent=2) + '\n')


if __name__ == '__main__':
    main()

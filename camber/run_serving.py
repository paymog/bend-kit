#!/usr/bin/env python3
"""Sequential public serving evidence with explicit gates and descendant guard."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'camber/serving_results.json'
RECEIPTS = json.loads(EVIDENCE.read_text()) if EVIDENCE.exists() else []


def processes():
    rows = {}
    output = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss=,lstart='], text=True)
    for line in output.splitlines():
        pid, parent, rss, identity = line.split(None, 3)
        rows[int(pid)] = (int(parent), int(rss), identity)
    return rows


class Guard:
    def __init__(self, argv, timeout=120):
        if shutil.disk_usage(ROOT).free < 10 * 1024**3:
            raise RuntimeError('less than 10 GiB disk headroom')
        self.argv = list(map(str, argv))
        self.output = tempfile.TemporaryFile(mode='w+')
        self.process = subprocess.Popen(self.argv, cwd=ROOT, stdout=self.output,
                                        stderr=subprocess.STDOUT, start_new_session=True)
        self.timeout = timeout
        self.peak = 0
        self.error = None
        self.observed = {}
        self.forced_cleanup = False
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.monitor)
        self.thread.start()
        print('$', ' '.join(self.argv), flush=True)

    def text(self):
        return os.pread(self.output.fileno(), 8 * 1024 * 1024, 0).decode(errors='replace')

    def monitor(self):
        started = time.monotonic()
        try:
            while not self.stop.wait(.05):
                rows = processes()
                members = {self.process.pid}
                while True:
                    expanded = members | {pid for pid, (parent, rss, identity) in rows.items() if parent in members}
                    if expanded == members:
                        break
                    members = expanded
                for pid in members & rows.keys():
                    self.observed[pid] = rows[pid][2]
                rss = sum(rows[pid][1] for pid in members & rows.keys())
                self.peak = max(self.peak, rss)
                if rss > 20 * 1024**2 or time.monotonic() - started > self.timeout:
                    self.error = 'aggregate RSS exceeds 20 GiB' if rss > 20 * 1024**2 else 'timeout'
                    self.kill()
                    return
        except BaseException as error:
            self.error = f'guard failed: {error}'
            self.kill()

    def kill(self):
        self.forced_cleanup = True
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def surviving(self):
        rows = processes()
        return {pid: identity for pid, identity in self.observed.items()
                if pid in rows and rows[pid][2] == identity}

    def finish(self):
        try:
            status = self.process.wait(timeout=self.timeout + 5)
        except BaseException:
            self.kill()
            status = self.process.wait()
            self.error = self.error or 'wait timeout'
        finally:
            self.stop.set()
            self.thread.join()
        survivors = self.surviving()
        if survivors:
            self.kill()
            deadline = time.monotonic() + 5
            while survivors and time.monotonic() < deadline:
                time.sleep(.05)
                survivors = self.surviving()
        text = self.text()
        self.output.close()
        receipt = dict(command=self.argv, cwd=str(ROOT), status=status, output=text,
                       peak_aggregate_descendant_rss_kib=self.peak, guard_error=self.error,
                       root_reaped=True, observed_process_identities=self.observed,
                       surviving_observed_processes=survivors, forced_group_cleanup=self.forced_cleanup,
                       observed_descendants_released=not survivors)
        RECEIPTS.append(receipt)
        EVIDENCE.write_text(json.dumps(RECEIPTS, indent=2) + '\n')
        print(text, end='')
        print(f'exit={status} peak_aggregate_rss_kib={self.peak}', flush=True)
        assert status == 0 and self.error is None and not survivors and not self.forced_cleanup, receipt
        return text

    def wait_for(self, marker):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            text = self.text()
            if marker in text:
                return text
            assert self.process.poll() is None, text
            time.sleep(.02)
        raise AssertionError(f'missing {marker}: {self.text()}')


def run(argv):
    return Guard(argv).finish()


def free_port():
    with socket.socket() as peer:
        peer.bind(('127.0.0.1', 0))
        return peer.getsockname()[1]


def request(port, method, target, body=b'', media='application/json', deny=''):
    with socket.create_connection(('127.0.0.1', port), timeout=5) as peer:
        peer.sendall((f'{method} {target} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n'
                      f'Content-Length: {len(body)}\r\nContent-Type: {media}\r\nX-Deny: {deny}\r\n\r\n').encode() + body)
        raw = b''
        while chunk := peer.recv(65536):
            raw += chunk
    head, packed = raw.split(b'\r\n\r\n', 1)
    lines = head.split(b'\r\n')
    fields = {}
    for line in lines[1:]:
        name, value = line.split(b':', 1)
        if name.lower() not in (b'connection', b'content-length'):
            fields[name.decode().lower()] = value.strip().decode('latin1')
    return int(lines[0].split()[1]), fields, packed


def command(control_port, path):
    result = request(control_port, 'GET', path)
    assert result[0] == 200, result
    return result[2]


def direct(executable, journal, method, target, body, media, deny):
    text = run(executable + ['direct', str(journal), method, target, media, deny, body.hex()])
    status = int(next(line[7:] for line in text.splitlines() if line.startswith('STATUS ')))
    fields = dict(line[7:].split('=', 1) for line in text.splitlines() if line.startswith('HEADER ') and not line.endswith('='))
    packed = bytes.fromhex(next(line[5:] for line in text.splitlines() if line.startswith('BODY ')))
    assert journal.read_text().splitlines().count('CLOSED') == 1
    return status, fields, packed


def descriptors(server, journal, expected):
    argv = ['/usr/sbin/lsof', '-Fn', '-p', str(server.process.pid)]
    observed = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True)
    assert observed.returncode in (0, 1), observed.stderr
    count = observed.stdout.splitlines().count('n' + str(journal))
    RECEIPTS.append(dict(command=argv, status=observed.returncode,
                         journal=str(journal), open_journal_descriptors=count))
    EVIDENCE.write_text(json.dumps(RECEIPTS, indent=2) + '\n')
    assert count == expected, (journal, count, expected)


def released(port):
    with socket.socket() as peer:
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        peer.bind(('127.0.0.1', port))
    RECEIPTS.append(dict(listener_port=port, listener_released=True))
    EVIDENCE.write_text(json.dumps(RECEIPTS, indent=2) + '\n')


def finish_server(server, control_port, app_port):
    command(control_port, '/finish')
    text = server.finish()
    assert 'JOINED CLOSED' in text and 'CONTROL JOINED' in text
    released(app_port)
    released(control_port)
    return text


def lane(executable, folder, small):
    app_port, control_port = free_port(), free_port()
    journal = folder / 'small-journal'
    text = run(executable + ['small', str(app_port), str(journal), str(control_port)])
    assert 'JOINED CLOSED' in text and text.count('BUNDLE CLOSED') == 1
    assert journal.read_text() == 'CLOSED\n'
    released(app_port)
    if small:
        return
    for mode in ('invalid', 'registration'):
        journal = folder / mode
        text = run(executable + [mode, str(app_port), str(journal), str(control_port)])
        assert 'STARTUP FAILED' in text and 'READY' not in text
        assert journal.read_text() == 'CLOSED\n' and text.count('BUNDLE CLOSED') == 1
    with socket.socket() as occupied:
        occupied.bind(('127.0.0.1', 0))
        occupied.listen()
        journal = folder / 'bind'
        text = run(executable + ['bind', str(occupied.getsockname()[1]), str(journal), str(control_port)])
        assert 'STARTUP FAILED' in text and 'READY' not in text
        assert journal.read_text() == 'CLOSED\n' and text.count('BUNDLE CLOSED') == 1
    rows = [
        ('POST', '/plain', b'\x00\xff\x80packed', 'application/octet-stream', '', 201),
        ('HEAD', '/plain', b'head', 'application/octet-stream', '', 201),
        ('POST', '/json', b'{"name":"Ada"}', 'application/json', '', 201),
        ('POST', '/json', b'{"x":1,"x":2}', 'application/json', '', 400),
        ('POST', '/json', b'"\\uD800"', 'application/json', '', 400),
        ('POST', '/json', b'"\xff"', 'application/json', '', 400),
        ('POST', '/json', b'{}', 'text/plain', '', 415),
        ('POST', '/json', b'{', 'application/json', 'yes', 401),
        ('GET', '/error', b'', 'application/json', '', 500),
        ('GET', '/missing', b'', 'application/json', '', 404),
        ('GET', '/%FF', b'', 'application/json', '', 400),
        ('DELETE', '/plain', b'', 'application/json', '', 405),
        ('GET', '/empty', b'', 'application/json', '', 204),
        ('GET', '/cached', b'', 'application/json', '', 304),
    ]
    expected = [direct(executable, folder / f'direct-{i}', *row[:-1]) for i, row in enumerate(rows)]
    journal = folder / 'live'
    server = Guard(executable + ['live', str(app_port), str(journal), str(control_port)])
    try:
        server.wait_for('READY\n')
        beside = request(control_port, 'POST', '/plain', b'\x00\xffbeside')
        assert beside == (201, {'x-plain': 'packed'}, b'\x00\xffbeside'), beside
        for row, comparison in zip(rows, expected):
            result = request(app_port, *row[:-1])
            assert result[0] == row[-1] == comparison[0], (row, result, comparison)
            assert result[1] == comparison[1], (row, result, comparison)
            assert result[2] == (b'' if row[0] == 'HEAD' or row[-1] in (204, 304) else comparison[2]), (row, result, comparison)
        text = finish_server(server, control_port, app_port)
        assert text.count('BUNDLE CLOSED') == 1 and journal.read_text().splitlines().count('CLOSED') == 1
    finally:
        if server.process.poll() is None:
            server.kill()
            server.finish()
    for mode, target, status in (('overload', '/hold', 200), ('wait', '/plain', 201)):
        journal = folder / mode
        server = Guard(executable + [mode, str(app_port), str(journal), str(control_port)])
        results, errors = [], []
        def operation():
            try:
                results.append(request(app_port, 'GET', target))
            except BaseException as error:
                errors.append(str(error))
        client = threading.Thread(target=operation)
        try:
            server.wait_for('READY\n')
            client.start()
            if mode == 'overload':
                server.wait_for('HELD\n')
                descriptors(server, journal, 1)
                for _ in range(24):
                    assert request(app_port, 'POST', '/plain', b'rejected')[0] == 503
                assert command(control_port, '/counts') == b'1 1'
                command(control_port, '/stop')
                assert 'STOP REQUESTED' in server.text()
                assert 'BUNDLE CLOSED' not in server.text() and 'JOINED CLOSED' not in server.text()
                assert command(control_port, '/counts') == b'1 1'
                assert journal.read_text() == 'BUSINESS hold\n'
            else:
                # A real active reservation proves the request entered the
                # bounded owner wait; no clock delay releases that wait.
                deadline = time.monotonic() + 5
                while command(control_port, '/counts') != b'1 1':
                    assert time.monotonic() < deadline, 'dependency waiter not admitted'
                assert journal.read_text() == ''
            command(control_port, '/release')
            client.join(5)
            assert not client.is_alive() and not errors and results[0][0] == status, (results, errors)
            if mode == 'overload':
                server.wait_for('BUNDLE CLOSED\n')
                descriptors(server, journal, 0)
            text = finish_server(server, control_port, app_port)
            assert journal.read_text() == ('BUSINESS hold\nCLOSED\n' if mode == 'overload' else 'BUSINESS plain\nCLOSED\n')
            if mode == 'overload':
                assert text.count('CAPACITY REJECTED') == 24
                assert text.index('STOP REQUESTED') < text.index('APPLICATION 200') < text.index('BUNDLE CLOSED') < text.index('JOINED CLOSED')
            else:
                assert 'DEPENDENCY RELEASED' in text
        finally:
            if server.process.poll() is None:
                server.kill()
                server.finish()
            client.join(5)


def owner_journals(text, cwd):
    for line in text.splitlines():
        if not line.startswith('JOURNAL '):
            continue
        journal = cwd / line.removeprefix('JOURNAL ')
        observed = []
        for slot in range(2):
            a = Path(f'{journal}-a-{slot}').read_text()
            b = Path(f'{journal}-b-{slot}').read_text()
            assert a == b, (journal, slot, a, b)
            observed.extend(a.splitlines())
        assert sorted(observed) == ['10', '12', '7', '8'], observed
        assert text.splitlines().count('PARTIAL CLOSED') == 1
        assert text.splitlines().count('CLOSED 0') == 2
        assert text.splitlines().count('CLOSED 1') == 3
        RECEIPTS.append(dict(owner_journal=str(journal), paired_principals=observed,
                             partial_closed=1, slot0_closed=2, slot1_closed=3))
        EVIDENCE.write_text(json.dumps(RECEIPTS, indent=2) + '\n')
        for owned in journal.parent.glob(journal.name + '-*'):
            owned.unlink()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--small', action='store_true')
    parser.add_argument('--checks', action='store_true')
    args = parser.parse_args()
    if args.checks:
        text = run(['bash', ROOT / 'scripts/check.sh', 'camber'])
        owner_journals(text, ROOT / 'camber')
    with tempfile.TemporaryDirectory(prefix='serving-', dir=ROOT / 'camber') as temporary:
        folder = Path(temporary)
        for extension, prefix in (('', []), ('.js', ['bun'])):
            executable = folder / ('serving' + extension)
            run(['bend', ROOT / 'camber/serving_check.bend', '-o', executable])
            lane(prefix + [str(executable)], folder, args.small)
        if not args.small:
            # Includes Busy -> same affine Owner retry and disposed Data replies.
            for extension, prefix in (('', []), ('.js', ['bun'])):
                executable = folder / ('owner' + extension)
                run(['bend', ROOT / 'camber/check.bend', '-o', executable])
                text = run(prefix + [str(executable)])
                assert 'camber owner: PASS' in text and 'close lost occupied capacity' not in text
                owner_journals(text, ROOT)
    EVIDENCE.write_text(json.dumps(RECEIPTS, indent=2) + '\n')
    print('PUBLIC SERVING PASS')


if __name__ == '__main__':
    main()

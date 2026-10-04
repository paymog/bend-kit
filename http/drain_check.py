#!/usr/bin/env python3
"""Public cooperative stop/drain; actual sockets and actual child completion."""
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import tempfile
import threading
import time

import admission_check as Admission

ROOT = Path(__file__).resolve().parent.parent
LIMIT_KIB = 20 * 1024 * 1024
RESULTS = []
COMMANDS = []


def disk_floor():
    stat = os.statvfs(ROOT)
    assert stat.f_bavail * stat.f_frsize >= 10 * 1024**3, 'less than 10GiB free'


def descendants(pid):
    rows = subprocess.run(['ps', '-axo', 'pid=,ppid=,rss='], capture_output=True, text=True, check=True).stdout
    tree = [tuple(map(int, row.split())) for row in rows.splitlines() if row.strip()]
    owned = {pid}
    while True:
        larger = owned | {child for child, parent, rss in tree if parent in owned}
        if larger == owned:
            return owned, sum(rss for child, parent, rss in tree if child in owned)
        owned = larger


class Process:
    def __init__(self, command, env=None):
        disk_floor()
        self.process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, start_new_session=True)
        self.lines, self.peak, self.owned, self.adverse = [], 0, {self.process.pid}, None
        self.ended = threading.Event()
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.guard = threading.Thread(target=self.watch, daemon=True)
        self.reader.start()
        self.guard.start()
        self.started = time.monotonic()

    def read(self):
        for line in self.process.stdout:
            self.lines.append(line.rstrip())

    def watch(self):
        while not self.ended.wait(.05):
            owned, rss = descendants(self.process.pid)
            self.owned |= owned
            self.peak = max(self.peak, rss)
            if rss > LIMIT_KIB:
                self.adverse = 'aggregate descendant RSS exceeded20GiB'
                os.killpg(self.process.pid, signal.SIGKILL)
                return

    def wait_for(self, predicate, timeout=8):
        deadline = time.monotonic() + timeout
        while not predicate():
            if self.process.poll() is not None:
                self.reader.join(timeout=1)
                assert predicate(), self.lines
                return
            assert time.monotonic() < deadline, self.lines[-30:]
            time.sleep(.01)

    def finish(self, expected=0, timeout=90):
        try:
            self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.adverse = f'actual process completion exceeded{timeout} seconds'
        finally:
            if self.process.poll() is None:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait(timeout=5)
            self.ended.set()
            self.reader.join(timeout=5)
            self.guard.join(timeout=5)
            self.process.stdout.close()
        assert not self.reader.is_alive() and not self.guard.is_alive()
        survivors = subprocess.run(['ps', '-o', 'pid=', '-p', ','.join(map(str, self.owned))],
                                   capture_output=True, text=True).stdout.strip()
        receipt = dict(command=self.process.args, status=self.process.returncode,
                       elapsed_s=round(time.monotonic() - self.started, 3),
                       peak_aggregate_descendant_rss_kib=self.peak, output=self.lines,
                       surviving_owned_processes=survivors, adverse=self.adverse)
        COMMANDS.append(receipt)
        assert not survivors and self.adverse is None, receipt
        assert self.process.returncode == expected, receipt
        return receipt

    def kill(self):
        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGKILL)
        return self.finish(-signal.SIGKILL)


class Server:
    def __init__(self, executable, lane, mode, case, folder):
        self.lane, self.mode, self.case = lane, mode, case
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0))
            self.port = reservation.getsockname()[1]
        self.journal_path = folder / f'{lane}-{mode}-{case}.journal'
        self.gate = folder / f'{lane}-{mode}-{case}.gate'
        for suffix in ('.stop', '.work', '.callback', '.cleanup', '.head'):
            Path(str(self.gate) + suffix).write_bytes(b'')
        env = dict(os.environ, ADMISSION_JOURNAL=str(self.journal_path),
                   DRAIN_GATE=str(self.gate), DRAIN_MODE=mode, BEND_NO_TELEMETRY='1')
        self.child = Process([*executable, mode, str(self.port)], env)
        self.child.wait_for(lambda: 'READY' in self.child.lines)
        self.peers = []

    def connect(self, slow=False):
        peer = socket.socket()
        if slow:
            peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024)
        peer.settimeout(5)
        peer.connect(('127.0.0.1', self.port))
        self.peers.append(peer)
        return peer

    def journal(self):
        return self.journal_path.read_text().splitlines() if self.journal_path.exists() else []

    def wait_journal(self, marker):
        self.child.wait_for(lambda: marker in self.journal())

    def release(self, suffix):
        Path(str(self.gate) + suffix).write_bytes(b'go')

    def counts(self):
        return [tuple(map(int, line.split(' ', 1)[1].split(',')))
                for line in self.child.lines if line.startswith('COUNTS ')]

    def stop(self):
        self.release('.stop')
        self.child.wait_for(lambda: 'STOP REQUESTED' in self.child.lines)
        deadline = time.monotonic() + 2
        while True:
            probe = socket.socket()
            probe.settimeout(.1)
            try:
                probe.connect(('127.0.0.1', self.port))
            except ConnectionRefusedError:
                self.refused_at = time.monotonic()
                return
            finally:
                probe.close()
            assert time.monotonic() < deadline, 'listener still accepts after stop'
            time.sleep(.01)

    def held(self):
        before = len(self.counts())
        self.child.wait_for(lambda: len(self.counts()) >= before + 3)
        samples = self.counts()[before:]
        assert all(row[0] >= 1 and row[1] == 1 and row[2] >= 1 for row in samples), samples
        assert self.child.process.poll() is None
        assert not any(line.startswith('OWNER COMPLETION') for line in self.child.lines)
        return samples

    def file_handles(self):
        path = Path(str(self.journal_path) + '.application').resolve()
        assert path.exists()
        command = ['lsof', '-a', '-p', str(self.child.process.pid), '-Fn', '--', str(path)]
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode in (0, 1) and not result.stderr, result
        paths = [line[1:] for line in result.stdout.splitlines() if line.startswith('n')]
        assert all(Path(value).resolve() == path for value in paths), paths
        return dict(command=command, status=result.returncode, output=result.stdout,
                    open_application_descriptors=len(paths))

    def finish(self, forced=False):
        receipt = self.child.kill() if forced else self.child.finish(timeout=12)
        forced_prefixes = [receive(peer).hex() for peer in self.peers] if forced else []
        for peer in self.peers:
            peer.close()
        with socket.socket() as rebound:
            rebound.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            rebound.bind(('127.0.0.1', self.port))
        rows = self.journal()
        if not forced:
            assert any(line.startswith('OWNER COMPLETION COUNTS 0,0,0,') for line in self.child.lines), receipt
            assert 'OWNER HANDLE CLOSED' in self.child.lines and 'POST CLOSED' in self.child.lines, receipt
            assert 'ACCOUNTING CLOSED' in self.child.lines, receipt
        RESULTS.append(dict(lane=self.lane, mode=self.mode, case=self.case,
                            journal=rows, counts=self.counts(), command_receipt=len(COMMANDS) - 1,
                            actual_owner_completion=not forced, natural_exit=not forced,
                            listener_rebound=True, forced_peer_closure=forced_prefixes))
        return receipt

    def abort(self):
        if self.child.process.poll() is None:
            self.child.kill()
        for peer in self.peers:
            peer.close()


def receive(peer):
    chunks = []
    while True:
        try:
            chunk = peer.recv(65536)
        except ConnectionResetError:
            break
        if not chunk:
            break
        chunks.append(chunk)
    return b''.join(chunks)


def once(server, path):
    rows = server.journal()
    assert rows.count('business ' + path) == 1, rows
    assert rows.count('callback-begin ' + path) == 1, rows
    assert rows.count('callback-end ' + path) == 1, rows
    assert 'business /successor' not in rows, rows


def idle(server):
    idle_peer = server.connect()
    header = server.connect()
    header.sendall(b'GET /partial HTTP/1.1\r\nHost:')
    body = None
    if server.mode != 'stream':
        body = server.connect()
        body.sendall(b'POST /partial-body HTTP/1.1\r\nHost: local\r\nContent-Length: 8\r\n\r\nab')
    server.child.wait_for(lambda: server.counts() and server.counts()[-1][0] == (2 if body is None else 3))
    server.stop()
    assert receive(idle_peer) == b'' and receive(header) == b''
    if body:
        assert receive(body) == b''
    server.finish()
    assert not any(line.startswith('business ') for line in server.journal())


def work(server):
    peer = server.connect()
    peer.sendall(Admission.request('/work', close=False) + Admission.request('/successor', close=False))
    server.wait_journal('business /work')
    idle_peer = server.connect()
    server.stop()
    assert receive(idle_peer) == b''
    held = server.held()
    server.release('.work')
    wire = receive(peer)
    assert wire.startswith(b'HTTP/1.1 200 ') and b'ok' in wire, wire
    assert wire.count(b'HTTP/1.1 200 ') == 1, wire
    server.finish()
    once(server, '/work')
    RESULTS[-1].update(held_after_stop=held, wire_hex=wire.hex())


def callback(server, stuck=False):
    path = '/stuck' if stuck else '/callback'
    peer = server.connect()
    peer.sendall(Admission.request(path, close=False))
    server.wait_journal('callback-begin ' + path)
    peer.sendall(Admission.request('/successor', close=False))
    server.stop()
    held = server.held()
    if stuck:
        assert 'callback-end /stuck' not in server.journal()
        server.finish(forced=True)
        assert 'OWNER HANDLE CLOSED' not in server.child.lines
        RESULTS[-1].update(held_after_stop=held, forced_exit_observed=True,
                           cleanup_not_fabricated=True)
    else:
        server.release('.callback')
        wire = receive(peer)
        assert wire.startswith(b'HTTP/1.1 200 ') and wire.count(b'HTTP/1.1 200 ') == 1, wire
        server.finish()
        once(server, path)
        RESULTS[-1].update(held_after_stop=held, wire_hex=wire.hex())


def expected_failure(server):
    first = server.connect()
    first.sendall(Admission.request('/expected-failure'))
    assert receive(first).startswith(b'HTTP/1.1 200 ')
    server.wait_journal('callback-end /expected-failure')
    assert any(row.startswith('expected-notification-failure ') for row in server.journal())
    second = server.connect()
    second.sendall(Admission.request('/after-failure'))
    assert receive(second).startswith(b'HTTP/1.1 200 ')
    server.wait_journal('callback-end /after-failure')
    server.stop()
    server.finish()
    once(server, '/expected-failure')
    once(server, '/after-failure')


def partial_upload(server):
    peer = server.connect()
    peer.sendall(b'POST /upload HTTP/1.1\r\nHost: local\r\nContent-Length: 8\r\n\r\nab')
    server.wait_journal('business /upload')
    server.stop()
    held = server.held()
    assert 'application-handle-closed' not in server.journal()
    peer.sendall(b'cdefgh' + Admission.request('/successor', close=False))
    wire = receive(peer)
    assert wire.startswith(b'HTTP/1.1 200 ') and wire.count(b'HTTP/1.1 200 ') == 1, wire
    server.finish()
    once(server, '/upload')
    assert server.journal().count('application-handle-closed') == 1
    assert server.journal().count('upload-complete /upload 8') == 1
    RESULTS[-1].update(held_after_stop=held, wire_hex=wire.hex())


def aborted_upload(server, failure):
    path = '/abort-' + failure
    peer = server.connect()
    if failure == 'framing':
        initial = (f'POST {path} HTTP/1.1\r\nHost: local\r\nTransfer-Encoding: chunked\r\n\r\n'
                   '2\r\nab\r\n').encode()
    else:
        initial = (f'POST {path} HTTP/1.1\r\nHost: local\r\nContent-Length: 8\r\n\r\nab').encode()
    peer.sendall(initial)
    server.wait_journal('application-opened ' + path)
    opened = server.file_handles()
    assert opened['open_application_descriptors'] == 1, opened
    server.stop()
    admitted = server.held()
    failure_started = time.monotonic()
    if failure == 'eof':
        peer.shutdown(socket.SHUT_WR)
    elif failure == 'framing':
        peer.sendall(b'g\r\n')
    elif failure == 'reset':
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
        peer.close()
    server.wait_journal('application-closed ' + path)
    elapsed = time.monotonic() - failure_started
    closed = server.file_handles()
    assert closed['open_application_descriptors'] == 0, closed
    cleanup_held = server.held()
    rows = server.journal()
    aborted = [row for row in rows if row.startswith('upload-aborted ' + path + ' ')]
    assert len(aborted) == 1, rows
    if failure in ('eof', 'framing'):
        assert aborted[0].endswith('status 400'), aborted
    elif failure == 'expiry':
        assert aborted[0].endswith('status 408'), aborted
    else:
        assert ' read ' in aborted[0] or aborted[0].endswith('status 400'), aborted
    assert not any(row.startswith('upload-complete ' + path) for row in rows), rows
    assert 'callback-begin ' + path not in rows, rows
    server.release('.cleanup')
    wire = b'' if failure == 'reset' else receive(peer)
    if failure != 'reset':
        status = b'408' if failure == 'expiry' else b'400'
        assert wire.startswith(b'HTTP/1.1 ' + status + b' '), wire
    server.finish()
    assert server.journal().count('application-closed ' + path) == 1
    RESULTS[-1].update(held_after_stop=admitted, held_during_actual_cleanup=cleanup_held,
                       application_descriptor_before=opened, application_descriptor_after=closed,
                       actual_abort_classification=aborted[0], failure_observed_s=round(elapsed, 3),
                       successful_finish_not_replayed=True, wire_hex=wire.hex())


def skipped_writer(server, path, status, reset=False):
    peer = server.connect()
    method = 'HEAD' if path == '/head' else 'GET'
    peer.sendall((f'{method} {path} HTTP/1.1\r\nHost: local\r\n\r\n').encode())
    server.wait_journal('application-opened ' + path)
    opened = server.file_handles()
    assert opened['open_application_descriptors'] == 1, opened
    if reset:
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
        peer.close()
    else:
        peer.sendall(Admission.request('/successor', close=False))
    server.stop()
    admitted = server.held()
    server.release('.head')
    server.wait_journal('write-disposed ' + path)
    server.wait_journal('application-closed ' + path)
    closed = server.file_handles()
    assert closed['open_application_descriptors'] == 0, closed
    cleanup_held = server.held()
    assert 'callback-begin ' + path not in server.journal()
    server.release('.cleanup')
    wire = b'' if reset else receive(peer)
    server.finish()
    once(server, path)
    rows = server.journal()
    assert rows.count('write-disposed ' + path) == 1, rows
    assert rows.count('application-closed ' + path) == 1, rows
    assert 'write-begin ' + path not in rows and 'write-return ' + path not in rows, rows
    outcomes = [row for row in rows if row.startswith('outcome ' + path + ' ')]
    assert len(outcomes) == 1, outcomes
    if reset:
        assert ' failed-' in outcomes[0], outcomes
    else:
        assert wire.startswith(b'HTTP/1.1 ' + str(status).encode() + b' '), wire
        # Any rejected buffered successor may have its own 503 response; the
        # original HEAD/204/304 response carries no application body bytes.
        assert b'ok' not in wire, wire
        assert outcomes[0].endswith(' accepted'), outcomes
    RESULTS[-1].update(held_after_stop=admitted, held_during_actual_cleanup=cleanup_held,
                       application_descriptor_before=opened, application_descriptor_after=closed,
                       actual_write_outcome=outcomes[0], body_callback_not_replayed=True,
                       wire_hex=wire.hex())


def writing(server):
    peer = server.connect(slow=True)
    peer.sendall(Admission.request('/write', close=False))
    server.wait_journal('business /write')
    if server.mode == 'writer':
        server.wait_journal('write-begin /write')
    server.stop()
    held = server.held()
    server.child.wait_for(lambda: 'callback-end /write' in server.journal(), timeout=5)
    server.child.wait_for(lambda: 'OWNER HANDLE CLOSED' in server.child.lines, timeout=5)
    wire = receive(peer)
    assert wire.startswith(b'HTTP/1.1 200 ') and 0 < len(wire) < 16777216, len(wire)
    receipt = server.finish()
    outcomes = [row for row in server.journal() if row.startswith('outcome /write ')]
    assert len(outcomes) == 1 and outcomes[0].startswith('outcome /write failed-'), outcomes
    once(server, '/write')
    RESULTS[-1].update(held_after_stop=held, actual_write_outcome=outcomes[0],
                       drain_elapsed_s=receipt['elapsed_s'], accepted_wire_prefix_bytes=len(wire))


def run_lane(lane, executable, folder):
    for mode in ('whole', 'stream', 'writer', 'camber'):
        scenarios = [('idle-partial', idle), ('admitted-pipeline', work),
                     ('delayed-callback', callback), ('expected-callback-failure', expected_failure),
                     ('stuck-callback', lambda server: callback(server, stuck=True))]
        if mode == 'stream':
            scenarios.append(('admitted-partial-upload', partial_upload))
            scenarios.extend(('admitted-upload-' + failure,
                              lambda server, failure=failure: aborted_upload(server, failure))
                             for failure in ('eof', 'expiry', 'framing', 'reset'))
        else:
            scenarios.append(('stop-during-write', writing))
        if mode == 'writer':
            scenarios.extend([
                ('dispose-HEAD', lambda server: skipped_writer(server, '/head', 200)),
                ('dispose-204', lambda server: skipped_writer(server, '/no-body', 204)),
                ('dispose-304', lambda server: skipped_writer(server, '/not-modified', 304)),
                ('dispose-header-failure', lambda server: skipped_writer(server, '/header-reset', 200, reset=True)),
            ])
        for case, scenario in scenarios:
            server = Server(executable, lane, mode, case, folder)
            try:
                scenario(server)
            finally:
                server.abort()
            print(f'{lane}/{mode}/{case}: actual stop, retained counts, completion/process release PASS', flush=True)


def main():
    try:
        with tempfile.TemporaryDirectory(prefix='http-drain-') as directory:
            folder = Path(directory)
            for lane, suffix in (('native', ''), ('javascript', '.js')):
                binary = folder / ('drain' + suffix)
                Process(['bend', str(ROOT / 'http/drain_check.bend'), '-o', str(binary)]).finish()
                executable = [str(binary), '--threads', '1', '--gpu', 'off'] if lane == 'native' else ['bun', str(binary)]
                run_lane(lane, executable, folder)
    finally:
        (ROOT / 'http/drain_results.json').write_text(json.dumps(dict(scenarios=RESULTS, commands=COMMANDS), indent=2) + '\n')


if __name__ == '__main__':
    main()

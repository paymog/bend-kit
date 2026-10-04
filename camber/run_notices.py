#!/usr/bin/env python3
"""Actual direct/native/JS completions; reuse the existing descendant/disk guard."""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import struct
import tempfile
import time
import run_serving as serving

ROOT = serving.ROOT
serving.EVIDENCE = ROOT / 'camber/notices_results.json'
serving.RECEIPTS = json.loads(serving.EVIDENCE.read_text()) if serving.EVIDENCE.exists() else []
OWNED = []


def save(**receipt):
    serving.RECEIPTS.append(receipt)
    serving.EVIDENCE.write_text(json.dumps(serving.RECEIPTS, indent=2) + '\n')


def notices(text):
    lines = [line.split()[1:] for line in text.splitlines() if line.startswith('NOTICE ')]
    assert all(int(fields[4]) >= 0 for fields in lines), lines
    return [tuple(fields[:4]) for fields in lines]


def logs(text):
    lines = [json.loads(line) for line in text.splitlines() if line.startswith('{')]
    for line in lines:
        assert set(line) == {'time', 'level', 'msg', 'status', 'duration_ms', 'mapped', 'stopped', 'outcome'}, line
        assert line['msg'] == 'access' and int(line['duration_ms']) >= 0, line
    for secret in ('BODY_SECRET', 'QUERY_SECRET', 'AUTH_SECRET', 'CREDENTIAL_SECRET', 'COOKIE_SECRET', 'INTERNAL_SECRET'):
        assert secret not in text, (secret, text)
    return lines


def assert_access(line, status, mapped, stopped, outcome):
    assert (line['status'], line['mapped'], line['stopped'], line['outcome']) == (status, mapped, stopped, outcome), line


def assert_duration(text, counts):
    values = [int(line.split()[5]) for line in text.splitlines() if line.startswith('NOTICE ')]
    offset = 0
    for count in counts:
        durations = values[offset:offset + count]
        assert len(durations) == count and all(value >= 0 for value in durations), durations
        assert len(set(durations)) == 1, durations  # same captured Notice, not a wall-time expectation
        offset += count
    assert offset == len(values), values


def request(port, method, target, deny='', body=b'BODY_SECRET', media='application/json'):
    with socket.create_connection(('127.0.0.1', port), timeout=5) as peer:
        peer.sendall((f'{method} {target} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n'
                      f'Content-Length: {len(body)}\r\nContent-Type: {media}\r\nX-Deny: {deny}\r\n'
                      'Authorization: AUTH_SECRET\r\nCookie: COOKIE_SECRET\r\nX-Credential: CREDENTIAL_SECRET\r\n\r\n').encode() + body)
        raw = b''
        while b'\r\n\r\n' not in raw:
            chunk = peer.recv(65536)
            assert chunk, raw
            raw += chunk
        head, packed = raw.split(b'\r\n\r\n', 1)
        status = int(head.split()[1])
        fields = dict(line.lower().split(b':', 1) for line in head.split(b'\r\n')[1:])
        length = 0 if method == 'HEAD' or status in (204, 304) else int(fields[b'content-length'])
        while len(packed) < length:
            chunk = peer.recv(65536)
            assert chunk, (head, packed)
            packed += chunk
    assert len(packed) == length, (head, packed)
    return status, packed


def wait_notices(server, count):
    end = time.monotonic() + 10
    while time.monotonic() < end:
        text = server.text()
        if len(notices(text)) >= count:
            return text
        assert server.process.poll() is None, text
        time.sleep(.02)
    raise AssertionError(('missing notices', count, server.text()))


def start(executable, folder, mode):
    port, control = serving.free_port(), serving.free_port()
    journal = folder / (mode + '-journal')
    server = serving.Guard(executable + [mode, str(port), str(journal), str(control)])
    OWNED.append((server, port, control))
    server.wait_for('READY')
    return server, port, control, journal


def finish(server, port, control):
    serving.command(control, '/finish')
    try:
        text = server.finish()
    finally:
        OWNED.remove((server, port, control))
        serving.released(port)
        serving.released(control)
    assert 'JOINED CLOSED' in text and 'CONTROL JOINED' in text, text
    logs(text)
    return text


def case_rows():
    return [
        ('GET', '/ok?token=QUERY_SECRET', '', b'BODY_SECRET', 200, ['route', 'group', 'root']),
        ('GET', '/ok', 'root', b'', 202, ['root']),
        ('GET', '/ok', 'group', b'', 202, ['group', 'root']),
        ('GET', '/ok', 'route', b'', 202, ['route', 'group', 'root']),
        ('GET', '/missing?secret=QUERY_SECRET', '', b'', 404, ['root']),
        ('GET', '/%FF?secret=QUERY_SECRET', '', b'', 400, ['root']),
        ('DELETE', '/ok', '', b'', 405, ['group', 'root']),
        ('OPTIONS', '/ok', '', b'', 204, ['group', 'root']),
        ('OPTIONS', '*', '', b'', 204, ['root']),
        ('POST', '/decode', '', b'{', 400, ['route', 'group', 'root']),
        ('GET', '/handler', '', b'', 500, ['route', 'group', 'root']),
        ('GET', '/transform', '', b'', 500, ['route', 'group', 'root']),
        ('GET', '/validation', '', b'', 500, ['route', 'group', 'root']),
        ('GET', '/mapper-fail', '', b'', 500, ['route', 'group', 'root']),
        ('GET', '/mapper-invalid', '', b'', 500, ['route', 'group', 'root']),
        ('HEAD', '/ok', '', b'', 200, ['route', 'group', 'root']),
        ('GET', '/empty', '', b'', 204, ['route', 'group', 'root']),
        ('GET', '/ok', '', b'', 200, ['route', 'group', 'root']),
    ]


def lane(executable, folder, small):
    journal = folder / 'direct'
    direct_rows = case_rows()[:1] if small else case_rows()
    for method, target, deny, body, status, entered in direct_rows:
        # Decoder input is deliberately invalid in both direct and live cases.
        text = serving.run(executable + ['direct', str(journal), method, target, deny])
        assert notices(text) == [(name, '7', str(status), 'application_only') for name in entered], text
        assert f'STATUS {status}' in text and 'host_accepted' not in text, text
        assert len(logs(text)) == 1 and logs(text)[0]['outcome'] == 'application_only'
        assert journal.read_text().splitlines().count('CLOSED') == 1
        assert text.splitlines().count('MAPPER') == (1 if status in (400, 404, 405, 500) else 0), text
        assert_access(logs(text)[0], status, status in (400, 404, 405, 500),
                      target in ('/transform', '/validation', '/mapper-fail', '/mapper-invalid'), 'application_only')
        assert_duration(text, [len(entered)])
        if target in ('/mapper-fail', '/mapper-invalid'):
            assert 'BODY_SIZE 0' in text, text
    server, port, control, journal = start(executable, folder, 'enabled')
    expected = []
    rows = case_rows()[:1] if small else case_rows()
    for method, target, deny, body, status, entered in rows:
        actual_status, packed = request(port, method, target, deny, body)
        assert actual_status == status, (method, target, actual_status, status)
        if method == 'HEAD' or status == 204:
            assert packed == b'', packed
        if status == 500:
            assert b'INTERNAL_SECRET' not in packed, packed
        if target in ('/mapper-fail', '/mapper-invalid'):
            assert packed == b'', packed  # actual fixed minimal500, not the ordinary mapped500
        expected += [(name, '7', str(status), 'host_accepted') for name in entered]
        text = wait_notices(server, len(expected))
        assert notices(text) == expected, text
    text = finish(server, port, control)
    assert notices(text) == expected and len(logs(text)) == len(rows), text
    assert text.count('COUNTED ') == len(expected), text
    assert journal.read_text().splitlines().count('CLOSED') == 1
    assert text.splitlines().count('MAPPER') == sum(row[4] in (400, 404, 405, 500) for row in rows), text
    assert 'BUSINESS 1' not in journal.read_text(), journal.read_text()
    for line, row in zip(logs(text), rows, strict=True):
        assert_access(line, row[4], row[4] in (400, 404, 405, 500),
                      row[1] in ('/transform', '/validation', '/mapper-fail', '/mapper-invalid'), 'host_accepted')
    assert_duration(text, [len(row[5]) for row in rows])
    if small:
        return
    for mode in ('disabled', 'disabled-fail', 'notice-fail', 'stall'):
        server, port, control, journal = start(executable, folder, mode)
        status, packed = request(port, 'GET', '/ok?secret=QUERY_SECRET')
        assert status == 200 and packed == b'BODY_SECRET'
        if mode == 'stall':
            server.wait_for('CALLBACK STALLED')
            counts = serving.command(control, '/counts').decode().split()
            assert all(int(value) >= 1 for value in counts), counts
            assert notices(server.text()) == [('route', '7', '200', 'host_accepted')]
            serving.command(control, '/release')
        text = wait_notices(server, 3)
        text = finish(server, port, control)
        assert notices(text) == [(name, '7', '200', 'host_accepted') for name in ('route', 'group', 'root')]
        assert len(logs(text)) == (0 if mode.startswith('disabled') else 1), text
        assert text.count('OWNER NOTICE ERROR') == (1 if mode.endswith('fail') else 0), text
        for line in logs(text):
            assert_access(line, 200, False, False, 'host_accepted')
        assert_duration(text, [3])
    server, port, control, journal = start(executable, folder, 'reset')
    peer = socket.create_connection(('127.0.0.1', port), timeout=5)
    peer.sendall(b'GET /reset?secret=QUERY_SECRET HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n')
    server.wait_for('EFFECT COMMITTED')
    assert journal.read_text() == 'BUSINESS 5\n', journal.read_text()
    peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
    peer.close()
    serving.command(control, '/release')
    text = wait_notices(server, 3)
    assert notices(text) == [(name, '7', '200', 'write_failed') for name in ('route', 'group', 'root')], text
    assert request(port, 'GET', '/ok')[0] == 200
    text = finish(server, port, control)
    assert len(logs(text)) == 2, text
    for line, outcome in zip(logs(text), ('write_failed', 'host_accepted'), strict=True):
        assert_access(line, 200, False, False, outcome)
    assert_duration(text, [3, 3])
    assert journal.read_text().splitlines() == ['BUSINESS 5', 'BUSINESS 0', 'CLOSED']
    save(scenario='actual_completion_matrix', executable=executable, entered_order=expected,
         reset_after_observed_file_effect=True, response_unchanged_after_notice_failure=True,
         stats_inside_inline_callback=True, stalled_callback_remains_counted=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--small', action='store_true')
    parser.add_argument('--checks', action='store_true')
    args = parser.parse_args()
    save(source_sha256={str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in (ROOT / 'camber/camber.bend', ROOT / 'camber/notices.bend',
                                     ROOT / 'camber/notices_check.bend', Path(__file__))},
         scheduling='exclusive coordinator-granted slot; native then JS; 10GiB disk/20GiB aggregate RSS guards')
    if args.checks:
        text = serving.run(['bash', ROOT / 'scripts/check.sh', 'camber'])
        serving.owner_journals(text, ROOT / 'camber')
    with tempfile.TemporaryDirectory(prefix='notices-', dir=ROOT / 'camber') as temporary:
        folder = Path(temporary)
        for extension, prefix in (('', []), ('.js', ['bun'])):
            executable = folder / ('notices' + extension)
            serving.run(['bend', ROOT / 'camber/notices_check.bend', '-o', executable])
            try:
                lane(prefix + [str(executable)], folder, args.small)
            except BaseException as error:
                save(scenario_failure=repr(error), executable=str(executable))
                for server, port, control in OWNED[:]:
                    server.kill()
                    try:
                        server.finish()
                    except AssertionError:
                        pass  # finish already appended the adverse command/cleanup receipt
                    OWNED.remove((server, port, control))
                    serving.released(port)
                    serving.released(control)
                raise
    print('ACTUAL NOTICES PASS')


if __name__ == '__main__':
    main()

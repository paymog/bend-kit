#!/usr/bin/env python3
"""Serialized published users consumer acceptance; no deployment/performance claims."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import socket
import sys
import tempfile
import threading
import time
import run_serving as shared

ROOT = Path(__file__).resolve().parents[1]
ATTEMPTS = ROOT / 'camber/users_attempts.json'
MATRIX = ROOT / 'camber/users_results.json'
shared.EVIDENCE = ATTEMPTS
shared.RECEIPTS = json.loads(ATTEMPTS.read_text()) if ATTEMPTS.exists() else []
RESULTS = []
RUNS = json.loads(MATRIX.read_text()) if MATRIX.exists() else []
SOURCES = ['camber/users.bend', 'camber/users_direct.bend', 'camber/users_live.bend', 'camber/users_owner.bend', 'camber/users_demo.bend', 'camber/run_users.py', 'camber/run_serving.py', 'camber/README.md', 'camber/SPEC.md', 'camber/author_study/RESULTS.md']


def hashes():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in SOURCES}


class Guard(shared.Guard):
    def __init__(self, argv, timeout=120):
        self.source_hashes = hashes()
        self.started = time.monotonic()
        super().__init__(argv, timeout)

    def finish(self):
        try:
            return super().finish()
        finally:
            if shared.RECEIPTS:
                shared.RECEIPTS[-1]['source_sha256'] = self.source_hashes
                shared.RECEIPTS[-1]['elapsed_seconds'] = time.monotonic() - self.started
                shared.RECEIPTS[-1]['root_pid'] = self.process.pid
                ATTEMPTS.write_text(json.dumps(shared.RECEIPTS, indent=2) + '\n')


def run(argv):
    return Guard(argv).finish()


def case(label, method='GET', target='/users/7', status=200, body=b'', token='Bearer seven', media='application/json', encoding='identity', expected=None, domain=None, scopes=None, header_scopes=None, fault=''):
    if expected is None:
        expected = {'id': 7, 'name': 'Alice'} if status == 200 else None
    if domain is None:
        domain = ['DOMAIN 7 lookup 7'] if status == 200 else []
    if scopes is None:
        scopes = [2, 1, 0]
    if header_scopes is None:
        header_scopes = scopes
    return dict(label=label, method=method, target=target, status=status, body=body, token=token,
                media=media, encoding=encoding, expected=expected, domain=domain, scopes=scopes, header_scopes=header_scopes, fault=fault)

def cases():
    rows = [
        case('health-noauth', target='/health', token='', expected={'ok': True}, domain=[], scopes=[2, 0]),
        case('health-head', method='HEAD', target='/health', token='', expected={'ok': True}, domain=[], scopes=[2, 0]),
        case('unknown-noauth', target='/unknown', token='', status=404, scopes=[0]),
        case('existing-id'),
        case('nonnumeric', target='/users/abc', status=400),
        case('overflow', target='/users/4294967296', status=400),
        case('u32-maximum', target='/users/4294967295', status=404, domain=['DOMAIN 7 lookup 4294967295']),
        case('missing-user', target='/users/99', status=404, domain=['DOMAIN 7 lookup 99']),
        case('principal-me', target='/users/me', token='Bearer eight', expected={'id': 8, 'name': 'Bob'}, domain=['DOMAIN 8 lookup 8']),
        case('literal-method-precedence', method='POST', target='/users/me', status=405, scopes=[1, 0]),
        case('create', method='POST', target='/users', status=201, body=b'{"name":"Cara"}', expected={'id': 9, 'name': 'Cara'}, domain=['DOMAIN 7 create']),
        case('coherent-created-lookup', target='/users/9', expected={'id': 9, 'name': 'Cara'}, domain=['DOMAIN 7 lookup 9']),
        case('auth-before-json', method='POST', target='/users', token='', body=b'{', status=401, scopes=[1, 0]),
        case('ordered-query', target='/users/7?tag=a&tag=b'),
        case('absolute-authority', target='http://example.test/users/7'),
        case('trailing-slash', target='/users/7/', status=404, scopes=[0]),
        case('double-slash', target='//users/7', status=404, scopes=[0]),
        case('empty-id', target='/users/', status=404, scopes=[0]),
        case('percent-once-valid', target='/users/%37'),
        case('percent-once-invalid', target='/users/%2537', status=400),
        case('encoded-slash', target='/users/a%2Fb', status=400, scopes=[0]),
        case('malformed-percent', target='/users/%', status=400, scopes=[0]),
        case('invalid-path-utf8', target='/users/%C0%AF', status=400, scopes=[0]),
        case('raw-nonascii', target='/users/é', status=400, scopes=[0]),
        case('query-utf8', target='/users/7?tag=%FF', status=400, scopes=[0]),
        case('wrong-method', method='DELETE', status=405, scopes=[1, 0]),
        case('generated-head', method='HEAD'),
        case('generated-options', method='OPTIONS', status=204, scopes=[1, 0]),
        case('options-star', method='OPTIONS', target='*', token='', status=204, scopes=[0]),
        case('get-star', target='*', token='', status=400, scopes=[0]),
    ]
    invalid = {
        'malformed-json': b'{', 'missing-name': b'{}', 'wrong-name': b'{"name":1}',
        'extra-field': b'{"name":"Cara","admin":true}', 'duplicate-name': b'{"name":"Cara","name":"Other"}',
        'escaped-duplicate': b'{"name":"Cara","na\\u006de":"Other"}', 'empty-name': b'{"name":""}',
        'empty-body': b'', 'array-body': b'[]', 'null-body': b'null',
        'invalid-body-utf8': b'{"name":"\xff"}', 'bom': b'\xef\xbb\xbf{"name":"Cara"}',
        'lone-surrogate': b'{"name":"\\uD800"}', 'trailing-json': b'{"name":"Cara"}{}',
        'name101-ascii': json.dumps({'name': 'a'*101}).encode(),
        'name101-nonbmp': json.dumps({'name': '😀'*101}, ensure_ascii=False).encode(),
        'depth65': b'['*65 + b'0' + b']'*65,
    }
    rows.extend(case(label, method='POST', target='/users', body=body, status=400) for label, body in invalid.items())
    for label, media, encoding in [('missing-media', '', 'identity'), ('wrong-media', 'text/plain', 'identity'), ('wrong-charset', 'application/json; charset=latin1', 'identity'), ('compressed', 'application/json', 'gzip')]:
        rows.append(case(label, method='POST', target='/users', body=b'{"name":"Cara"}', status=415, media=media, encoding=encoding))
    next_id = 10
    for label, name, media in [('name100-ascii', 'a'*100, 'application/json'), ('name100-nonbmp', '😀'*100, 'application/json'), ('suffix-media', 'Suffix', 'Application/Vnd.Demo+JSON; Charset="UTF-8"; profile=demo')]:
        rows.append(case(label, method='POST', target='/users', body=json.dumps({'name': name}, ensure_ascii=False).encode(), status=201, media=media, expected={'id': next_id, 'name': name}, domain=['DOMAIN 7 create']))
        next_id += 1
    return rows


def expected_body(row, live):
    if live and row['method'] == 'HEAD' or row['status'] in (204, 401, 500):
        return b''
    if isinstance(row['expected'], bytes):
        return row['expected']
    if row['expected'] is not None:
        return json.dumps(row['expected'], separators=(',', ':'), ensure_ascii=False).encode()
    titles = {400: 'Bad Request', 404: 'Not Found', 405: 'Method Not Allowed', 415: 'Unsupported Media Type'}
    return json.dumps({'type': 'about:blank', 'title': titles[row['status']], 'status': row['status']}, separators=(',', ':')).encode()


def verify(row, result, events, lane, live):
    status, headers, body = result
    assert status == row['status'], (row['label'], status, row['status'], events)
    assert body == expected_body(row, live), (row['label'], body, expected_body(row, live))
    if status == 201 and isinstance(row['expected'], dict):
        assert headers.get('location') == '/users/' + str(row['expected']['id'])
    if status == 401:
        assert headers.get('www-authenticate') == 'Bearer'
        assert not any(e.startswith('DECODE') for e in events), events
    if status == 405 or status == 204:
        assert headers.get('allow') == ('GET, HEAD, OPTIONS, POST' if row['target'] == '*' else 'GET, HEAD, OPTIONS')
    if status in (400, 404, 405, 415):
        assert headers.get('content-type') == 'application/problem+json'
    if status in (200, 201) and isinstance(row['expected'], dict):
        assert headers.get('content-type') == 'application/json'
    header_scopes = row.get('header_scopes', row['scopes'])
    expected_headers = {'x-plain': 'packed' if row['label'] == 'plain-packed' else '',
                        'x-root': 'yes' if 0 in header_scopes else '',
                        'x-group': 'yes' if 1 in header_scopes else '',
                        'x-route': 'yes' if 2 in header_scopes else ''}
    assert {name: headers.get(name, '') for name in expected_headers} == expected_headers, (row['label'], headers)
    assert [e for e in events if e.startswith('DOMAIN ')] == row['domain'], (row['label'], events)
    scopes = row['scopes']
    assert [int(e.split()[1]) for e in events if e.startswith('NOTICE ')] == scopes, (row['label'], events)
    assert [e.split()[1] for e in events if e.startswith('BEFORE ')] == [{0: 'root', 1: 'group', 2: 'route'}[s] for s in reversed(scopes)]
    assert [e.split()[1] for e in events if e.startswith('TRANSFORM ')] == row.get('transforms', [{0: 'root', 1: 'group', 2: 'route'}[s] for s in scopes])
    assert events.count('MAPPER') == int(status in (400, 401, 404, 405, 415, 500)), events
    assert all(('application_only' if not live else 'host_accepted') in e for e in events if e.startswith('NOTICE ')), events
    if row['label'] == 'default-no-request-logging':
        assert events == [], events
    if row['label'] == 'ordered-query':
        assert [e for e in events if e.startswith('QUERY ')] == ['QUERY tag=a', 'QUERY tag=b']
    if row['label'] == 'absolute-authority':
        assert 'HOST example.test' in events and 'HOST wrong.test' not in events
    RESULTS.append(dict(lane=lane, boundary='live' if live else 'direct', case=row['label'], status=status,
                        headers=headers, body_hex=body.hex(), effects=events, forbidden_domain_effects_absent=True, source_sha256=hashes()))


def direct(command, folder, lane, fixture='users', fault='trace', order='forward', rows=None):
    rows = cases() if rows is None else rows
    argv = command + [fixture, order, fault, str(folder / f'{lane}-direct-journal')]
    for row in rows:
        argv += [row['label'], row['method'], row['target'], row['token'], row['media'], row['encoding'], row['fault'], row['body'].hex()]
    text = run(argv)
    sections = text.split('CASE ')[1:]
    assert len(sections) == len(rows)
    for row, section in zip(rows, sections):
        lines = section.splitlines()[1:]
        record = next(json.loads(e[len('RESPONSE '):]) for e in lines if e.startswith('RESPONSE '))
        events = [e for e in lines if not e.startswith(('RESPONSE ', 'STATE CLOSED', 'STORE CLOSED', 'STORE JOINED'))]
        body = bytes.fromhex(record['body'])
        verify(row, (record['status'], {k: v for k, v in record.items() if k not in ('status', 'body')}, body), events, lane, False)
    assert (folder / f'{lane}-direct-journal').read_text().splitlines() == sum((r['domain'] for r in rows), []) + ['CLOSED']


def request(port, row):
    with socket.create_connection(('127.0.0.1', port), timeout=10) as peer:
        headers = f"{row['method']} {row['target']} HTTP/1.1\r\nHost: wrong.test\r\nConnection: close\r\nContent-Length: {len(row['body'])}\r\nAuthorization: {row['token']}\r\nX-Case: {row['label']}\r\nContent-Encoding: {row['encoding']}\r\nX-Invalid: {row['fault']}\r\n"
        if row['media']:
            headers += f"Content-Type: {row['media']}\r\n"
        peer.sendall(headers.encode('latin1') + b'\r\n' + row['body'])
        raw = b''
        while data := peer.recv(65536):
            raw += data
    head, body = raw.split(b'\r\n\r\n', 1)
    lines = head.split(b'\r\n')
    fields = {}
    for line in lines[1:]:
        name, value = line.split(b':', 1)
        fields[name.decode().lower()] = value.strip().decode('latin1')
    assert b'injected:' not in raw and b'PRIVATE' not in raw
    assert 'transfer-encoding' not in fields
    return int(lines[0].split()[1]), fields, body


def control(port, path):
    row = case('control', target=path, expected=None, domain=[])
    return request(port, row)


def rebind(port):
    with socket.socket() as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('127.0.0.1', port))
        listener.listen(1)


def wait_completed(guard, count):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if guard.text().splitlines().count('COMPLETED') >= count:
            return
        assert guard.process.poll() is None, guard.text()
        time.sleep(.01)  # Observe actual callback completion; not an overlap/ownership guess.
    raise AssertionError('missing actual completion')


def live(command, folder, lane, fixture='users', fault='trace', order='forward', rows=None):
    rows = cases() if rows is None else rows
    port, ctrl = shared.free_port(), shared.free_port()
    journal = folder / f'{lane}-live-journal'
    guard = Guard(command + [fixture, order, fault, str(port), str(ctrl), str(journal)])
    try:
        guard.wait_for('READY')
        for n, row in enumerate(rows, 1):
            offset = len(guard.text())
            result = request(port, row)
            wait_completed(guard, n)
            verify(row, result, [e for e in guard.text()[offset:].splitlines() if e != 'COMPLETED'], lane, True)
        control(ctrl, '/finish')
        text = guard.finish()
        assert all(marker in text for marker in ('APPLICATION JOINED', 'STORE JOINED', 'CONTROL JOINED'))
        assert journal.read_text().splitlines() == sum((r['domain'] for r in rows), []) + ['CLOSED']
        rebind(port)
        rebind(ctrl)
    except BaseException:
        if guard.process.poll() is None:
            guard.kill()
        try:
            guard.finish()
        except BaseException:
            pass
        raise


def plain_cases():
    packed = bytes([0, 255, 128, 1]) + b'packed'
    return [case('plain-packed', method='POST', target='/plain', status=201, body=packed, expected=packed, domain=[]),
            case('plain-crlf-rejected', method='POST', target='/plain', status=500, body=b'PRIVATE', expected=None, domain=[], fault='crlf'),
            case('plain-framing-rejected', method='POST', target='/plain', status=500, body=b'PRIVATE', expected=None, domain=[], fault='framing')]


def overlap(command, folder, lane):
    port, ctrl = shared.free_port(), shared.free_port()
    journal = folder / f'{lane}-overlap-journal'
    guard = Guard(command + ['users', 'forward', 'testing', str(port), str(ctrl), str(journal)])
    output, errors = [], []
    def held_request():
        try:
            row = case('held-principal', target='/users/me')
            row['fault'] = ''
            # Only the acceptance config enables hold and real failed-store injection.
            with socket.create_connection(('127.0.0.1', port), timeout=10) as peer:
                peer.sendall(b'GET /users/me HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nAuthorization: Bearer seven\r\nX-Hold: yes\r\n\r\n')
                raw = b''
                while data := peer.recv(65536):
                    raw += data
            output.append(raw)
        except BaseException as error:
            errors.append(error)
    try:
        guard.wait_for('READY')
        first = threading.Thread(target=held_request)
        first.start()
        guard.wait_for('REQUEST HELD')
        assert not output, 'first request did not overlap'
        with socket.create_connection(('127.0.0.1', port), timeout=10) as peer:
            peer.sendall(b'GET /users/me HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nAuthorization: Bearer eight\r\nX-Store-Fail: yes\r\n\r\n')
            failed = b''
            while data := peer.recv(65536):
                failed += data
        assert failed.startswith(b'HTTP/1.1 500 ') and failed.split(b'\r\n\r\n', 1)[1] == b'', failed
        guard.wait_for('STORE EXPECTED FILE FAILURE')
        assert not output, 'held principal ended before differing-principal failure'
        recovered = request(port, case('recovered-bob', target='/users/me', token='Bearer eight', expected={'id': 8, 'name': 'Bob'}))
        assert recovered[0] == 200 and recovered[2] == b'{"id":8,"name":"Bob"}'
        control(ctrl, '/release')
        first.join(15)
        assert not first.is_alive() and not errors and len(output) == 1
        assert output[0].startswith(b'HTTP/1.1 200 ') and output[0].split(b'\r\n\r\n', 1)[1] == b'{"id":7,"name":"Alice"}'
        wait_completed(guard, 3)
        output.clear()
        second = threading.Thread(target=held_request)
        second.start()
        deadline = time.monotonic() + 15
        while guard.text().count('REQUEST HELD') < 2:
            assert time.monotonic() < deadline and guard.process.poll() is None
            time.sleep(.01)
        control(ctrl, '/stop')
        assert not output and 'STORE CLOSED' not in guard.text(), 'stop falsely claimed drain'
        control(ctrl, '/release')
        second.join(15)
        assert not second.is_alive() and not errors and len(output) == 1
        assert output[0].split(b'\r\n\r\n', 1)[1] == b'{"id":7,"name":"Alice"}'
        wait_completed(guard, 4)
        control(ctrl, '/finish')
        text = guard.finish()
        assert text.count('MAPPER') == 1 and text.count('STORE EXPECTED FILE FAILURE') == 1
        assert 'APPLICATION JOINED' in text and 'STORE JOINED' in text
        domain = ['DOMAIN 8 lookup 8', 'DOMAIN 8 lookup 8', 'DOMAIN 7 lookup 7', 'DOMAIN 7 lookup 7']
        assert journal.read_text().splitlines() == domain + ['CLOSED']
        rebind(port)
        rebind(ctrl)
        RESULTS.append(dict(lane=lane, boundary='live', case='principal-overlap-store-failure-recovery-cooperative-drain',
                            expected_failure_status=500, successful_principals=[8, 7, 7], effects=domain,
                            explicit_close_join=True, real_listener_rebind=True, source_sha256=hashes()))
    except BaseException:
        if guard.process.poll() is None:
            guard.kill()
        try:
            guard.finish()
        except BaseException:
            pass
        raise


def standalone(command, folder, lane, rows=None):
    port, ctrl = shared.free_port(), shared.free_port()
    journal = folder / f'{lane}-standalone-journal'
    guard = Guard(command + [str(port), str(ctrl), str(journal)])
    observed = []
    try:
        guard.wait_for('READY users demo')
        if rows is None:
            rows = [case('CASE_SECRET', target='/health?tag=QUERY_SECRET', token='', expected={'ok': True}, domain=[]),
                    case('default-user'),
                    case('default-current-user', target='/users/me'),
                    case('default-create', method='POST', target='/users', status=201, body=b'{"name":"Cara"}', expected={'id': 9, 'name': 'Cara'}),
                    case('default-created-lookup', target='/users/9', expected={'id': 9, 'name': 'Cara'})]
        for row in rows:
            status, headers, body = request(port, row)
            assert status == row['status'] and body == expected_body(row, True), (row['label'], status, body)
            assert headers.get('content-type') == 'application/json'
            if status == 201:
                assert headers.get('location') == '/users/9'
            observed.append(dict(status=status, headers=headers, body_hex=body.hex()))
        stop = request(ctrl, case('owner-stop', method='POST', target='/stop'))
        assert stop[0] == 200 and stop[2] == b''
        text = guard.finish()
        assert 'SECRET' not in text and 'wrong.test' not in text
        assert not any(e.startswith(('HOST ', 'QUERY ', 'DOMAIN ', 'BEFORE ', 'TRANSFORM ', 'NOTICE ')) for e in text.splitlines())
        assert all(e in text for e in ['APPLICATION JOINED', 'STORE JOINED', 'OWNER CONTROL JOINED'])
        assert journal.read_text().splitlines() == ['CLOSED']
        rebind(port)
        rebind(ctrl)
        RESULTS.append(dict(lane=lane, boundary='standalone', case='default-application-cooperative-owner-close',
                            responses=observed, default_request_logging_absent=True, explicit_close_join=True,
                            real_listener_rebind=True, forced_termination=False, source_sha256=hashes()))
    except BaseException:
        if guard.process.poll() is None:
            guard.kill()
        try:
            if not guard.output.closed:
                guard.finish()
        except BaseException:
            pass
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', choices=['gates', 'small', 'full'], default='small')
    parser.add_argument('--lane', choices=['native', 'js', 'both'], default='both')
    parser.add_argument('--probe', choices=['rejection', 'secret'])
    args = parser.parse_args()
    started_ns = time.time_ns()
    failure = None
    try:
        if args.phase == 'gates':
            run(['bash', str(ROOT / 'scripts/check.sh'), 'camber'])
            return
        with tempfile.TemporaryDirectory(prefix='users-', dir=ROOT / 'camber') as tmp:
            folder = Path(tmp)
            for lane, extension, prefix in [('native', '', []), ('js', '.js', ['bun'])]:
                if args.lane not in ('both', lane):
                    continue
                direct_executable = folder / ('users-direct' + extension)
                live_executable = folder / ('users-live' + extension)
                run(['bend', str(ROOT / 'camber/users_direct.bend'), '-o', str(direct_executable)])
                run(['bend', str(ROOT / 'camber/users_live.bend'), '-o', str(live_executable)])
                direct_command = prefix + [str(direct_executable)]
                live_command = prefix + [str(live_executable)]
                rows = cases()[:2] if args.phase == 'small' else cases()
                if args.probe:
                    rows = [next(r for r in cases() if r['label'] == ('empty-name' if args.probe == 'rejection' else 'existing-id'))]
                direct(direct_command, folder, lane, rows=rows)
                live(live_command, folder, lane, rows=rows)
                if args.phase == 'full':
                    for order in ['forward', 'reverse']:
                        direct(direct_command, folder, lane, order=order, rows=[cases()[8]])
                        live(live_command, folder, lane, order=order, rows=[cases()[8]])
                    rejected = run(direct_command + ['duplicate', 'forward', '', str(folder / 'duplicate-journal')])
                    assert not any(e.startswith(('DOMAIN ', 'BEFORE ', 'READY')) for e in rejected.splitlines())
                    assert (folder / 'duplicate-journal').read_text().splitlines() == ['CLOSED']
                    RESULTS.append(dict(lane=lane, boundary='construction', case='duplicate-route-rejected',
                                        dispatch_or_listening_started=False, effects=[], source_sha256=hashes()))
                    owner = folder / ('owner' + extension)
                    run(['bend', str(ROOT / 'camber/users_owner.bend'), '-o', str(owner)])
                    text = run(prefix + [str(owner), str(folder / 'owner-journal')])
                    responses = [json.loads(e[len('RESPONSE '):]) for e in text.splitlines() if e.startswith('RESPONSE ')]
                    assert [(r['status'], bytes.fromhex(r['body'])) for r in responses] == [(500, b''), (200, b'{"id":7,"name":"Alice"}'), (200, b'{"id":8,"name":"Bob"}')]
                    owner_domain = ['DOMAIN 8 lookup 8', 'DOMAIN 7 lookup 7', 'DOMAIN 8 lookup 8', 'DOMAIN 7 hold', 'DOMAIN 8 lookup 8', 'DOMAIN 7 lookup 7']
                    assert (folder / 'owner-journal').read_text().splitlines() == owner_domain + ['CLOSED']
                    assert (folder / 'owner-journal.edge').read_text().splitlines() == ['CLOSED']
                    RESULTS.append(dict(lane=lane, boundary='direct', case='principal-overlap-store-failure-exhaustion-disposed-reply',
                                        responses=responses, effects=owner_domain, explicit_close_join=True, source_sha256=hashes()))
                    quiet = case('default-no-request-logging', target='/users/7?tag=QUERY_SECRET', scopes=[], header_scopes=[2, 1, 0], domain=[])
                    direct(direct_command, folder, lane, fixture='default', fault='', rows=[quiet])
                    live(live_command, folder, lane, fixture='default', fault='', rows=[quiet])
                    demo = folder / ('users-demo' + extension)
                    run(['bend', str(ROOT / 'camber/users_demo.bend'), '-o', str(demo)])
                    standalone(prefix + [str(demo)], folder, lane)
                    direct(direct_command, folder, lane, fixture='plain', rows=plain_cases())
                    live(live_command, folder, lane, fixture='plain', rows=plain_cases())
                    transformed = case('transform-failure', status=500, domain=['DOMAIN 7 lookup 7'])
                    transformed['transforms'] = ['route']
                    transformed['header_scopes'] = []
                    direct(direct_command, folder, lane, fault='transform', rows=[transformed])
                    live(live_command, folder, lane, fault='transform', rows=[transformed])
                    overlap(live_command, folder, lane)
        print('USERS ACCEPTANCE PASS')
    except BaseException as error:
        failure = repr(error)
        shared.RECEIPTS.append(dict(command=[sys.executable, *sys.argv], cwd=str(ROOT), validation_failure=repr(error),
                                    phase=args.phase, probe=args.probe, lane=args.lane, source_sha256=hashes()))
        ATTEMPTS.write_text(json.dumps(shared.RECEIPTS, indent=2) + '\n')
        raise
    finally:
        RUNS.append(dict(started_ns=started_ns, phase=args.phase, probe=args.probe, lane=args.lane,
                         command=[sys.executable, *sys.argv], status='failed' if failure else 'passed', failure=failure,
                         source_sha256=hashes(), host=platform.platform(), python=sys.version,
                         dependencies={'Camber': '0.6.0.0', 'HTTP': '0.30.0.0', 'Json': '0.5.1.0'}, matrix=RESULTS,
                         exclusions=['host IO and runtime trust', 'empty human pure-law inventory is not behavioral proof', 'Camber/HTTP unsafe receive/serving loops and foreign host effects are excluded from pure proofs', 'external deployment/forced exit #339', 'full performance #340']))
        MATRIX.write_text(json.dumps(RUNS, indent=2) + '\n')


if __name__ == '__main__':
    main()

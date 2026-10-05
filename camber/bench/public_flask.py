"""Production WSGI application; runner starts Waitress, never Flask's development server."""
import json
import os
import time
from flask import Flask, request, Response, g
from waitress import create_server

started = time.monotonic()
app = Flask(__name__)
app.url_map.strict_slashes = True
app.config['MAX_CONTENT_LENGTH'] = 8388608
profile = int(os.environ['CAMBER_PROFILE'])


def result(status, body=b'', headers=None):
    return Response(body, status, headers or {})


def text(status, value):
    return result(status, value.encode(), {'content-type': 'text/plain; charset=utf-8'})


def encoded(value):
    return result(200, json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode(), {'content-type': 'application/json'})


def hooks(count):
    def check():
        if request.path == f'/hooks/{count}':
            if request.headers.get('authorization') != 'Bearer alice':
                return result(401, headers={'www-authenticate': 'Bearer'})
            g.hooks = getattr(g, 'hooks', 0) + 1
    return check


# Separate real before-request callbacks, not a claimed hook count without work.
for count in (1, 5):
    for _ in range(count):
        app.before_request(hooks(count))


def handler(op, parameter=None):
    expected = 'POST' if op in ('decode', 'echo') else 'GET'
    if request.method not in ((expected, 'HEAD') if expected == 'GET' else (expected,)):
        return result(405, headers={'allow': 'GET, HEAD, OPTIONS' if expected == 'GET' else 'OPTIONS, POST'})
    if op == 'text': return text(200, 'OK\n')
    if op == 'json': return result(200, b'{"ok":true}', {'content-type': 'application/json'})
    if op == 'parameter':
        if not parameter.isascii() or not parameter.isdecimal() or int(parameter) > 4294967295: return text(400, 'invalid id')
        return encoded({'id': int(parameter)})
    if op.startswith('route-'): return encoded({'id': int(op[6:])})
    if op.startswith('hooks-'): return result(200, b'{"ok":true}', {'content-type': 'application/json', 'x-hook-count': str(getattr(g, 'hooks', 0))})
    body = request.get_data()
    if op == 'echo': return result(200, body, {'content-type': 'application/octet-stream'})
    if request.headers.get('content-type') != 'application/json': return text(415, 'invalid name')
    try:
        value = json.loads(body.decode('utf-8'))
        if not isinstance(value, dict) or list(value) != ['name'] or not isinstance(value['name'], str) or not 1 <= len(value['name']) <= 100: return text(400, 'invalid name')
        return encoded(value)
    except (ValueError, UnicodeError): return text(400, 'invalid name')


registrations = [(f'/route/{n}', f'route-{n}') for n in range(profile)] if profile else [('/text', 'text'), ('/json', 'json'), ('/users/<parameter>', 'parameter'), ('/decode', 'decode'), ('/echo', 'echo'), *[(f'/hooks/{n}', f'hooks-{n}') for n in (0, 1, 5)]]
for index, (path, op) in enumerate(registrations):
    app.add_url_rule(path, str(index), lambda parameter=None, op=op: handler(op, parameter), methods=['GET', 'HEAD', 'POST', 'OPTIONS'], provide_automatic_options=False)
app.register_error_handler(404, lambda error: text(404, 'not found'))
app.register_error_handler(413, lambda error: result(413))
print('CONSTRUCTION_MS', (time.monotonic() - started) * 1000, flush=True)
print('READY', flush=True)
if __name__ == '__main__':
    server = create_server(app, host='127.0.0.1', port=int(os.environ['CAMBER_PORT']), threads=1, connection_limit=32, max_request_body_size=8388608, max_request_header_size=65536, channel_timeout=30)
    try:
        server.run()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        server.task_dispatcher.shutdown()
        for channel in list(server._map.values()):
            channel.close()
    print('JOINED', flush=True)

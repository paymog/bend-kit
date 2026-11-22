import os
import socket
import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ca, chain, key, ports_path = sys.argv[1:5]
ports = []

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            while True:
                size = int(self.rfile.readline().split(b';', 1)[0], 16)
                if not size:
                    for line in self.rfile:
                        if line == b'\r\n':
                            break
                    break
                self.rfile.read(size)
                assert self.rfile.read(2) == b'\r\n'
        else:
            self.rfile.read(int(self.headers.get('Content-Length', '0')))
        port = self.server.server_port
        required, optional = ports[:2]
        if port == required and self.path == '/same':
            status, body, location = 302, b'', f'https://localhost:{required}/who'
        elif port == required and self.path in ('/cross', '/back'):
            status, body, location = 302, b'', f'https://localhost:{optional}/' + ('inspect' if self.path == '/cross' else 'back')
        elif port == optional and self.path == '/back':
            status, body, location = 302, b'', f'https://localhost:{required}/who'
        elif port == optional:
            status, body, location = 200, b'leaked' if self.connection.getpeercert() else b'clean', None
        else:
            cert = self.connection.getpeercert()
            name = next((v for rdn in cert['subject'] for k, v in rdn if k == 'commonName'), '')
            status, body, location = 200, name.encode(), None
        self.send_response(status)
        if location:
            self.send_header('Location', location)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

for required in (True, False):
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    ports.append(server.server_port)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(chain, key)
    ctx.load_verify_locations(ca)
    ctx.verify_mode = ssl.CERT_REQUIRED if required else ssl.CERT_OPTIONAL
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()

def frame(kind, flags, stream, payload):
    return len(payload).to_bytes(3, 'big') + bytes([kind, flags]) + stream.to_bytes(4, 'big') + payload

# Each HTTP/2 connection answers one request with its number, then closes TCP without GOAWAY or close_notify.
def h2_conn(conn, number):
    buf = b''
    def take(n):
        nonlocal buf
        while len(buf) < n:
            more = conn.recv(65536)
            if not more:
                raise EOFError
            buf += more
        out, buf = buf[:n], buf[n:]
        return out
    try:
        take(24)
        conn.sendall(frame(4, 0, 0, b''))
        while True:
            head = take(9)
            kind, flags = head[3], head[4]
            stream = int.from_bytes(head[5:9], 'big') & 0x7fffffff
            take(int.from_bytes(head[:3], 'big'))
            if kind == 4 and not flags & 1:
                conn.sendall(frame(4, 1, 0, b''))
            elif kind in (0, 1) and flags & 1:
                break
        body = str(number).encode()
        conn.sendall(frame(1, 4, stream, b'\x88') + frame(0, 1, stream, body))
        conn.settimeout(0.2)
        while conn.recv(65536):
            pass
    except (EOFError, OSError):
        pass
    conn.close()

def h2_serve(listener, ctx):
    number = 0
    while True:
        raw, _ = listener.accept()
        number += 1
        try:
            conn = ctx.wrap_socket(raw, server_side=True)
        except OSError:
            raw.close()
            continue
        threading.Thread(target=h2_conn, args=(conn, number), daemon=True).start()

h2_listener = socket.create_server(('127.0.0.1', 0))
ports.append(h2_listener.getsockname()[1])
h2_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
h2_ctx.load_cert_chain(chain, key)
h2_ctx.set_alpn_protocols(['h2'])
threading.Thread(target=h2_serve, args=(h2_listener, h2_ctx), daemon=True).start()

def h2_stream_conn(conn, number):
    buf = b''
    cancelled = False
    uploads = {}
    def take(n):
        nonlocal buf
        while len(buf) < n:
            more = conn.recv(16384)
            if not more:
                raise EOFError
            buf += more
        out, buf = buf[:n], buf[n:]
        return out
    try:
        assert take(24) == b'PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n'
        conn.sendall(frame(4, 0, 0, b''))
        while True:
            head = take(9)
            kind, flags = head[3], head[4]
            stream = int.from_bytes(head[5:9], 'big') & 0x7fffffff
            payload = take(int.from_bytes(head[:3], 'big'))
            if kind == 4 and not flags & 1:
                conn.sendall(frame(4, 1, 0, b''))
            elif kind == 3:
                assert stream == 3 and payload == b'\0\0\0\x08'
                cancelled = True
                with open(ports_path + '.cancelled', 'w') as f:
                    f.write('cancelled\n')
            elif kind in (0, 1):
                if kind == 0:
                    uploads[stream] = uploads.get(stream, b'') + payload
                if not flags & 1:
                    continue
                if stream == 7:
                    conn.sendall(frame(7, 0, 0, stream.to_bytes(4, 'big') + b'\0\0\0\0'))
                conn.sendall(frame(1, 4, stream, b'\x08\x03' + b'103'))
                conn.sendall(frame(1, 4, stream, b'\x88'))
                if stream == 3:
                    assert uploads[stream] == b'upload'
                    continue
                assert stream == 1 or cancelled
                import time
                time.sleep(0.1)
                conn.sendall(frame(0, 0, stream, str(number).encode() + b'a'))
                conn.sendall(frame(0, 0, stream, b'b'))
                conn.sendall(frame(1, 5, stream, b'\x00\x06x-tail\x03yes'))
    except (EOFError, OSError):
        pass
    finally:
        conn.close()

def h2_stream_serve(listener):
    number = 0
    while True:
        raw, _ = listener.accept()
        number += 1
        with open(ports_path + '.streams', 'a') as f:
            f.write(str(number) + '\n')
        conn = h2_ctx.wrap_socket(raw, server_side=True)
        threading.Thread(target=h2_stream_conn, args=(conn, number), daemon=True).start()

stream_listener = socket.create_server(('127.0.0.1', 0))
ports.append(stream_listener.getsockname()[1])
threading.Thread(target=h2_stream_serve, args=(stream_listener,), daemon=True).start()

with open(ports_path + '.tmp', 'w') as f:
    f.write(' '.join(map(str, ports)) + '\n')
os.replace(ports_path + '.tmp', ports_path)
threading.Event().wait()

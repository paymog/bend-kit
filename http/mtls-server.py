import ssl
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ca, chain, key = sys.argv[1:4]

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        port = self.server.server_port
        if port == 39444 and self.path == '/same':
            status, body, location = 302, b'', 'https://localhost:39444/who'
        elif port == 39444 and self.path in ('/cross', '/back'):
            status, body, location = 302, b'', 'https://localhost:39445/' + ('inspect' if self.path == '/cross' else 'back')
        elif port == 39445 and self.path == '/back':
            status, body, location = 302, b'', 'https://localhost:39444/who'
        elif port == 39445:
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

for port, required in ((39444, True), (39445, False)):
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(chain, key)
    ctx.load_verify_locations(ca)
    ctx.verify_mode = ssl.CERT_REQUIRED if required else ssl.CERT_OPTIONAL
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()

threading.Event().wait()

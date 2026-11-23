import os
import socket
import ssl
import sys

cert, key, ports_path = sys.argv[1:4]
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain(cert, key)
protocols = os.environ.get('WIRE_TEST_ALPN', 'h2,http/1.1')
ctx.set_alpn_protocols(protocols.split(',') if protocols else [])
if len(sys.argv) > 4:
    ctx.load_verify_locations(sys.argv[4])
    ctx.verify_mode = ssl.CERT_REQUIRED

with socket.create_server(('127.0.0.1', 0)) as server:
    with open(ports_path + '.tmp', 'w') as f:
        f.write(f'{server.getsockname()[1]}\n')
    os.replace(ports_path + '.tmp', ports_path)
    while True:
        conn, _ = server.accept()
        with conn:
            try:
                with ctx.wrap_socket(conn, server_side=True) as tls:
                    while tls.recv(4096):
                        pass
            except OSError:
                pass

import http.client
import socket
import ssl
import sys

ca, cert, key, port = sys.argv[1:]
ctx = ssl.create_default_context(cafile=ca)
ctx.load_cert_chain(cert, key)
ctx.verify_flags &= ~ssl.VERIFY_X509_STRICT
with socket.create_connection(('localhost', int(port)), timeout=5) as tcp:
    with ctx.wrap_socket(tcp, server_hostname='localhost') as conn:
        conn.sendall(b'GET /who HTTP/1.1\r\nHost: localhost\r\n'
                     b'Transfer-Encoding: chunked\r\nConnection: close\r\n\r\n'
                     b'2\r\nhi\r\n')
        conn.settimeout(0.2)
        try:
            early = conn.recv(1)
        except socket.timeout:
            pass
        else:
            raise AssertionError(f'mTLS server replied before upload finished: {early!r}')
        conn.settimeout(5)
        conn.sendall(b'0\r\n\r\n')
        response = http.client.HTTPResponse(conn)
        response.begin()
        assert response.status == 200, response.status
        assert response.read() == b'client-one'
print('ok mTLS server waits for the complete upload')

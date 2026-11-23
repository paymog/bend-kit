"""Read the bound port from a live smoke server."""

import selectors


def ready(server):
    with selectors.DefaultSelector() as selector:
        selector.register(server.stdout, selectors.EVENT_READ)
        if not selector.select(timeout=10):
            raise RuntimeError("server did not report its bound port")
        line = server.stdout.readline().decode("ascii").strip()
    name, port = line.split()
    assert name == "READY" and 0 < int(port) <= 65535, line
    return int(port)

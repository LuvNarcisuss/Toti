"""Loopback-only CONNECT tunnel for agreement UI acceptance; never decrypts TLS."""
import argparse
import json
import select
import socket
import socketserver
import threading
from datetime import datetime, timezone


class State:
    lock = threading.Lock()
    offline = False
    tunnels = set()


def log(event, **fields):
    print(json.dumps(dict(time=datetime.now(timezone.utc).isoformat(), event=event, **fields)), flush=True)


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        client = self.request
        client.settimeout(10)
        header = b''
        try:
            while b'\r\n\r\n' not in header and len(header) < 16384:
                chunk = client.recv(4096)
                if not chunk:
                    return
                header += chunk
            method, target, _ = header.split(b'\r\n', 1)[0].decode('ascii').split()
            if method == 'GET' and target in ('/control/offline', '/control/online'):
                with State.lock:
                    State.offline = target.endswith('/offline')
                    if State.offline:
                        for connection in list(State.tunnels):
                            try:
                                connection.shutdown(socket.SHUT_RDWR)
                            except OSError:
                                pass
                    offline = State.offline
                log('mode', offline=offline)
                client.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK')
                return
            if method != 'CONNECT':
                return
            host, port = target.rsplit(':', 1)
            allowed = host == 'docs.google.com' or host.endswith(('.google.com', '.gstatic.com', '.googleusercontent.com'))
            with State.lock:
                offline = State.offline
            if not allowed or port != '443' or offline:
                log('blocked', host=host, offline=offline)
                client.sendall(b'HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
                return
            with socket.create_connection((host, 443), timeout=15) as remote:
                client.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n')
                log('tunnel', host=host)
                with State.lock:
                    State.tunnels.update((client, remote))
                try:
                    client.settimeout(None)
                    remote.settimeout(None)
                    while True:
                        with State.lock:
                            if State.offline:
                                return
                        readable, _, _ = select.select([client, remote], [], [], 1)
                        for source in readable:
                            data = source.recv(65536)
                            if not data:
                                return
                            (remote if source is client else client).sendall(data)
                finally:
                    with State.lock:
                        State.tunnels.difference_update((client, remote))
        except (OSError, ValueError) as error:
            log('transport_error', kind=type(error).__name__)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=18889)
    args = parser.parse_args()
    with Server(('127.0.0.1', args.port), Handler) as server:
        log('listening', port=args.port)
        server.serve_forever()

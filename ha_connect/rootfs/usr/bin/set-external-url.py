#!/usr/bin/env python3
"""Set Home Assistant external_url via Core WebSocket API (no REST endpoint exists)."""
from __future__ import annotations

import base64
import json
import os
import socket
import struct
import sys


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise RuntimeError("WebSocket closed unexpectedly")
        buf += chunk
    return buf


def ws_connect(host: str, port: int, path: str) -> socket.socket:
    sock = socket.create_connection((host, port), timeout=20)
    key = base64.b64encode(os.urandom(16)).decode()
    req = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}\r\n"
        f"Upgrade: websocket\r\n"
        f"Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        f"Sec-WebSocket-Version: 13\r\n"
        f"\r\n"
    )
    sock.sendall(req.encode())
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = sock.recv(4096)
        if not chunk:
            raise RuntimeError("WebSocket handshake failed")
        data += chunk
    status = data.split(b"\r\n", 1)[0]
    if b"101" not in status:
        raise RuntimeError(f"WebSocket upgrade failed: {status!r}")
    return sock


def ws_send(sock: socket.socket, text: str) -> None:
    payload = text.encode()
    mask = os.urandom(4)
    header = bytearray([0x81])  # FIN + text
    length = len(payload)
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", length))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", length))
    header.extend(mask)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    sock.sendall(header + masked)


def ws_recv(sock: socket.socket) -> str:
    while True:
        b1, b2 = _recv_exact(sock, 2)
        opcode = b1 & 0x0F
        masked = bool(b2 & 0x80)
        length = b2 & 0x7F
        if length == 126:
            length = struct.unpack("!H", _recv_exact(sock, 2))[0]
        elif length == 127:
            length = struct.unpack("!Q", _recv_exact(sock, 8))[0]
        mask = _recv_exact(sock, 4) if masked else b""
        payload = _recv_exact(sock, length)
        if masked:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        if opcode == 0x8:  # close
            raise RuntimeError("WebSocket closed by server")
        if opcode == 0x9:  # ping -> pong
            # send pong
            frame = bytearray([0x8A, 0x80 | len(payload)])
            m = os.urandom(4)
            frame.extend(m)
            frame.extend(bytes(b ^ m[i % 4] for i, b in enumerate(payload)))
            sock.sendall(frame)
            continue
        if opcode in (0x1, 0x2, 0x0):
            return payload.decode()
        # ignore other opcodes


def set_external_url(url: str, token: str) -> None:
    # Prefer supervisor proxy (works with SUPERVISOR_TOKEN + homeassistant_api)
    endpoints = [
        ("supervisor", 80, "/core/websocket"),
        ("homeassistant", 8123, "/api/websocket"),
    ]
    last_err: Exception | None = None
    for host, port, path in endpoints:
        try:
            sock = ws_connect(host, port, path)
            try:
                msg = json.loads(ws_recv(sock))
                if msg.get("type") != "auth_required":
                    raise RuntimeError(f"unexpected first message: {msg}")
                ws_send(sock, json.dumps({"type": "auth", "access_token": token}))
                msg = json.loads(ws_recv(sock))
                if msg.get("type") != "auth_ok":
                    raise RuntimeError(f"auth failed: {msg}")
                ws_send(
                    sock,
                    json.dumps(
                        {
                            "id": 1,
                            "type": "config/core/update",
                            "external_url": url,
                        }
                    ),
                )
                msg = json.loads(ws_recv(sock))
                if msg.get("type") == "result" and msg.get("success"):
                    print(f"ok via {host}{path}")
                    return
                raise RuntimeError(f"update failed: {msg}")
            finally:
                sock.close()
        except Exception as exc:  # noqa: BLE001 – try next endpoint
            last_err = exc
            continue
    raise RuntimeError(f"all websocket endpoints failed: {last_err}")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: set-external-url.py <url>", file=sys.stderr)
        return 2
    url = sys.argv[1]
    token = os.environ.get("SUPERVISOR_TOKEN", "")
    if not token:
        print("SUPERVISOR_TOKEN missing", file=sys.stderr)
        return 1
    try:
        set_external_url(url, token)
        return 0
    except Exception as exc:  # noqa: BLE001
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

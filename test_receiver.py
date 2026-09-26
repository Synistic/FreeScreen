"""Check the actual receiver capability response, without an iPhone."""
import plistlib
import socket
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 7001
with socket.create_connection(('127.0.0.1', port), timeout=5) as sock:
    sock.sendall(b'GET /info RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: FreeScreen-Diagnostic\r\n\r\n')
    data = b''
    while b'\r\n\r\n' not in data:
        chunk = sock.recv(4096)
        assert chunk, 'Connection closed before headers'
        data += chunk
    head, body = data.split(b'\r\n\r\n', 1)
    assert head.startswith(b'RTSP/1.0 200'), head.decode()
    headers = dict(line.split(b':', 1) for line in head.split(b'\r\n')[1:])
    size = int(headers[b'Content-Length'])
    while len(body) < size:
        chunk = sock.recv(4096)
        assert chunk, 'Connection closed before body'
        body += chunk
    info = plistlib.loads(body[:size])
    assert info['features'] & (1 << 7), 'Mirroring capability missing'
    display = info['displays'][0]
    assert display['width'] > 0 and display['height'] > 0
    assert display['maxFPS'] > 0
    print(f"PASS: {info['name']}, screen {display['width']}x{display['height']}, {display['maxFPS']} FPS, AirPlay mirroring advertised")
    payload = plistlib.dumps({'combinedGetInfoWithControlSetup': True}, fmt=plistlib.FMT_BINARY)
    sock.sendall((f'SETUP rtsp://127.0.0.1/test RTSP/1.0\r\nCSeq: 2\r\nContent-Type: application/x-apple-binary-plist\r\nContent-Length: {len(payload)}\r\n\r\n').encode() + payload)
    data = b''
    while b'\r\n\r\n' not in data:
        chunk = sock.recv(4096)
        assert chunk, 'Closed during combined SETUP'
        data += chunk
    head, body = data.split(b'\r\n\r\n', 1)
    assert head.startswith(b'RTSP/1.0 200'), head.decode()
    headers = dict(line.split(b':', 1) for line in head.split(b'\r\n')[1:])
    size = int(headers[b'Content-Length'])
    while len(body) < size:
        chunk = sock.recv(4096)
        assert chunk, 'Incomplete combined SETUP response'
        body += chunk
    combined = plistlib.loads(body[:size])
    assert combined['info']['displays'] == info['displays']
    assert combined['info']['features'] == info['features']
    print('PASS: combined control SETUP includes consistent receiver info')

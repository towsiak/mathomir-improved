import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

port_file, record_file = map(Path, sys.argv[1:3])
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))).decode('utf-8'))
        valid = (self.path == '/v1/responses' and self.headers.get('Authorization') == 'Bearer sk-mathomir-ci-only') or (self.path == '/openai/v1/responses' and self.headers.get('Authorization') == 'Bearer gsk_mathomir_ci_only')
        with record_file.open('a', encoding='utf-8') as f:
            f.write(json.dumps(dict(path=self.path, input=data.get('input'), model=data.get('model'), store=data.get('store'), stream=data.get('stream'), authenticated=valid), ensure_ascii=False) + '\n')
        text = data.get('input', '')
        if isinstance(text, list):
            text = text[-1].get('content', '')
        code = 200
        body = {'status': 'completed', 'output': [{'type': 'reasoning', 'summary': []}, {'type': 'message', 'role': 'assistant', 'content': [{'type': 'output_text', 'text': 'ln(2) ≈ 0.6931\n\nThis is an offline test-server response.'}]}]}
        if '[angle-format]' in text:
            body['output'][1]['content'][0]['text'] = r"""**Goal:** Turn an angle measured in radians into the equivalent number of degrees.

**Why it works:** A full circle is \(2\pi\) radians and also \(360^\circ\).
Therefore
\[
1\text{ rad} = \frac{360^\circ}{2\pi}= \frac{180^\circ}{\pi}
\]
### Step-by-step example
**Convert** \(\displaystyle \frac{5\pi}{6}\) **radians to degrees.**
1. **Write the conversion factor**
   \[\frac{180^\circ}{\pi}\]
2. **Multiply the radian measure by the factor**
   \[\frac{5\pi}{6}\times\frac{180^\circ}{\pi}\]
3. **Cancel the pi symbols**
   \[\frac{5}{6}\times180^\circ\]
4. **Do the arithmetic**
   \[180^\circ \times \frac{5}{6}=180^\circ\times0.8333\ldots=150^\circ\]
5. **Result**
   \[\frac{5\pi}{6}\text{ rad}=150^\circ\]
---
### Another quick check
Convert \(2\) radians to degrees.
\[2\times\frac{180}{3.14159}\approx114.5916^\circ\]
So \(2\) rad is approximately \(114.6^\circ\).
### Summary formula
\[\boxed{\text{degrees}=\text{radians}\times\dfrac{180^\circ}{\pi}}\]
"""
        if not valid:
            code = 401
        if '[rate-limit]' in text:
            code = 429
        if '[unavailable-model]' in text:
            code = 404
        if '[slow]' in text:
            time.sleep(2)
        if '[malformed]' in text:
            encoded = b'{bad'
        else:
            encoded = json.dumps(body, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        try:
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError):
            pass
server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
port_file.write_text(str(server.server_port))
server.serve_forever()

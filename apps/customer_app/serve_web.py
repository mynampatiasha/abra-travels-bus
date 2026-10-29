import http.server
import socketserver
import os
import sys

PORT = 5050
DIRECTORY = os.path.join(os.path.dirname(__file__), 'build', 'web')

class SPARequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Resolve target file path
        path = self.translate_path(self.path)
        if not os.path.exists(path):
            # Fallback to index.html for SPA routing
            self.path = '/index.html'
        return super().do_GET()

    def end_headers(self):
        # Avoid caching during development testing
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()

if __name__ == '__main__':
    os.chdir(DIRECTORY)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), SPARequestHandler) as httpd:
        print(f"Abra Customer Web App running at http://localhost:{PORT}")
        sys.stdout.flush()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass

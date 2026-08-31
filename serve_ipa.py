#!/usr/bin/env python3
"""
Newton IPA Local & Cloudflare Tunnel Server
Serves Newton.ipa via local network IP and a public Cloudflare Tunnel so you can download it directly on your iPhone.
"""

import os
import sys
import socket
import subprocess
import time
import re
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading

PORT = 8089
SERVE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "build", "Downloaded-IPA"))

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def generate_web_portal():
    os.makedirs(SERVE_DIR, exist_ok=True)
    html_path = os.path.join(SERVE_DIR, "index.html")
    
    ipa_size_str = "666 KB"
    ipa_file = os.path.join(SERVE_DIR, "Newton.ipa")
    if os.path.exists(ipa_file):
        size_mb = os.path.getsize(ipa_file) / (1024 * 1024)
        ipa_size_str = f"{size_mb:.2f} MB"
        
    html_content = f"""<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Descargar Newton iOS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400..700;1,6..72,400&family=JetBrains+Mono:wght@400;600&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg: #1F2528;
            --card: #283136;
            --border: #424E54;
            --sand: #E0BD80;
            --text-main: #D9CFB8;
            --text-sub: #94A197;
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', -apple-system, sans-serif; }}
        body {{
            background-color: var(--bg);
            color: var(--text-main);
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 24px;
        }}
        .container {{
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 28px;
            max-width: 440px;
            width: 100%;
            padding: 32px 24px;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0,0,0,0.3);
        }}
        .brand-title {{
            font-family: 'Newsreader', serif;
            font-size: 36px;
            font-weight: 700;
            color: var(--text-main);
            margin-bottom: 4px;
        }}
        .subtitle {{
            font-size: 14px;
            color: var(--text-sub);
            margin-bottom: 24px;
        }}
        .icon-badge {{
            width: 80px;
            height: 80px;
            background: #181D20;
            border: 1px solid var(--border);
            border-radius: 20px;
            margin: 0 auto 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 36px;
        }}
        .btn-download {{
            display: block;
            background: var(--sand);
            color: #000;
            text-decoration: none;
            font-weight: 600;
            font-size: 16px;
            padding: 16px 24px;
            border-radius: 18px;
            margin-bottom: 14px;
            transition: transform 0.2s, opacity 0.2s;
        }}
        .btn-download:active {{
            transform: scale(0.98);
            opacity: 0.9;
        }}
        .meta-info {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: var(--text-sub);
            margin-top: 16px;
        }}
        .instructions {{
            background: rgba(0,0,0,0.2);
            border-radius: 14px;
            padding: 14px;
            margin-top: 20px;
            font-size: 13px;
            color: var(--text-sub);
            text-align: left;
            line-height: 1.5;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="icon-badge">✨</div>
        <h1 class="brand-title">Newton iOS</h1>
        <p class="subtitle">Descarga directa para Sideloading (AltStore, Sideloadly, Scarlet, TrollStore)</p>
        
        <a href="/Newton.ipa" class="btn-download" download>
            ⬇️ Descargar Newton.ipa ({ipa_size_str})
        </a>
        
        <div class="instructions">
            <strong>Cómo instalar en iPhone:</strong><br>
            1. Toca el botón <strong>Descargar Newton.ipa</strong>.<br>
            2. Abre la descarga con <strong>AltStore</strong>, <strong>Sideloadly</strong>, <strong>TrollStore</strong> o <strong>Scarlet</strong>.<br>
            3. ¡Listo para usar!
        </div>
        
        <p class="meta-info">Versión 1.0.0 • Swift & SwiftUI Nativo</p>
    </div>
</body>
</html>
"""
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)

class QuietHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)
    def log_message(self, format, *args):
        pass

def start_http_server():
    server = HTTPServer(("0.0.0.0", PORT), QuietHandler)
    server.serve_forever()

def main():
    generate_web_portal()
    
    # Start local HTTP server
    t = threading.Thread(target=start_http_server, daemon=True)
    t.start()
    
    local_ip = get_local_ip()
    local_url = f"http://{local_ip}:{PORT}"
    
    print(f"\n=======================================================")
    print(f"🚀 Newton IPA Server Iniciado")
    print(f"🏠 Red Local (WiFi): {local_url}")
    print(f"📦 Archivo directo: {local_url}/Newton.ipa")
    print(f"=======================================================\n")
    
    # Start Cloudflare Tunnel
    cloudflared_bin = "/opt/local/bin/cloudflared"
    if not os.path.exists(cloudflared_bin):
        which_cf = subprocess.run(["which", "cloudflared"], capture_output=True, text=True).stdout.strip()
        if which_cf:
            cloudflared_bin = which_cf
            
    if os.path.exists(cloudflared_bin):
        print("🌐 Iniciando Cloudflare Tunnel...")
        proc = subprocess.Popen(
            [cloudflared_bin, "tunnel", "--url", f"http://127.0.0.1:{PORT}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        
        public_url = None
        for line in proc.stdout:
            match = re.search(r'(https://[a-zA-Z0-9-]+\.trycloudflare\.com)', line)
            if match:
                public_url = match.group(1)
                print(f"\n✨ ¡TÚNEL PÚBLICO CLOUDFLARE LISTO! ✨")
                print(f"🔗 Abre este link en tu iPhone (Safari):")
                print(f"👉 {public_url}")
                print(f"📦 Descarga directa del IPA:")
                print(f"👉 {public_url}/Newton.ipa\n")
                break
                
        # Keep process alive
        proc.wait()
    else:
        print("cloudflared no encontrado. Usa la IP local de tu red WiFi.")
        while True:
            time.sleep(3600)

if __name__ == "__main__":
    main()

#!/usr/bin/env bash
mkdir -p build
pkill -f "cloudflared tunnel" 2>/dev/null || true
/opt/local/bin/cloudflared tunnel --url http://127.0.0.1:8089 > build/tunnel.log 2>&1 &
sleep 4
grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' build/tunnel.log | head -n 1

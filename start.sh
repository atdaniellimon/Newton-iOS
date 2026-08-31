#!/bin/bash

clean_processes() {
    echo -e "\nDeteniendo servidores..."
    kill $PID_BACKEND 2>/dev/null
    kill $PID_FRONTEND 2>/dev/null
    exit 0
}

trap clean_processes SIGINT

python3 backend/app.py &
PID_BACKEND=$!

npx live-server --entry-file=index.html &
PID_FRONTEND=$!

echo "Presiona Ctrl+C para apagar ambos servidores."
wait

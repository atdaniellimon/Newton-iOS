#!/usr/bin/env python3
"""
Newton Backend — entrypoint.
Delegates everything to proxy.py (NWTN auth + quota + SSE proxy).
"""

import argparse
from proxy import run_server, BACKEND_PORT

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Newton Backend Server")
    parser.add_argument("--port", type=int, default=BACKEND_PORT,
                        help="Port to listen on")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Enable verbose logging")
    args = parser.parse_args()
    run_server(port=args.port, verbose=args.verbose)

#!/usr/bin/env python3
"""
Newton Proxy Server — NWTN Edition
Handles user auth (username/password → nwtn key), quota enforcement,
request forwarding to NWTN API, SSE streaming passthrough, usage logging.
"""

import json
import sys
import argparse
import sqlite3
import time
import threading
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import urllib.request
import urllib.error
import ssl
from pathlib import Path
from dotenv import load_dotenv
import certifi

load_dotenv()

# SSL context with certifi CA bundle (fixes macOS SSL verification)
def _ssl_ctx() -> ssl.SSLContext:
    ctx = ssl.create_default_context(cafile=certifi.where())
    return ctx

# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────
BACKEND_PORT    = int(os.getenv("PORT", 6742))
NWTN_UPSTREAM   = os.getenv("NWTN_UPSTREAM", "https://api.newton.daniellimon.uk/nwtn")
NWTN_ADMIN_TOKEN= os.getenv("NWTN_ADMIN_TOKEN", "")
DB_PATH         = os.getenv("DB_PATH", str(Path(__file__).parent / "users.db"))

# Quota constants
QUOTA_5H_MAX    = 150   # requests per 5-hour rolling window
QUOTA_5H_SECS   = 5 * 3600
QUOTA_WEEK_MSGS = 1200  # messages per week
QUOTA_WEEK_TOK  = 6_000_000  # tokens per week

# Password hashing using PBKDF2 (stdlib, no external deps)
import hashlib
import secrets
import base64

def _hash_password(password: str) -> str:
    """Hash password with PBKDF2-HMAC-SHA256. Returns 'pbkdf2$salt$hash'."""
    salt = secrets.token_hex(16)
    hash_bytes = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
    hash_b64 = base64.b64encode(hash_bytes).decode()
    return f"pbkdf2${salt}${hash_b64}"

def _verify_password(password: str, stored_hash: str) -> bool:
    """Verify password against stored PBKDF2 hash."""
    try:
        if stored_hash.startswith("pbkdf2$"):
            parts = stored_hash.split("$")
            if len(parts) != 3:
                return False
            _, salt, hash_b64 = parts
            expected = base64.b64decode(hash_b64)
            computed = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            return secrets.compare_digest(expected, computed)
        # Legacy bcrypt support (if any existing hashes)
        elif stored_hash.startswith("$2"):
            try:
                import bcrypt
                return bcrypt.checkpw(password.encode(), stored_hash.encode())
            except ImportError:
                return False
        return False
    except Exception:
        return False

# ──────────────────────────────────────────────
# DB helpers
# ──────────────────────────────────────────────
_db_lock = threading.Lock()

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def ensure_schema():
    with get_db() as conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            username        TEXT UNIQUE NOT NULL,
            password_hash   TEXT NOT NULL,
            nwtn_key        TEXT UNIQUE NOT NULL,
            nwtn_key_prefix TEXT NOT NULL,
            credits_total   INTEGER DEFAULT 100000,
            credits_used    INTEGER DEFAULT 0,
            rpm_limit       INTEGER DEFAULT 60,
            trial_ends_at   INTEGER,
            active          INTEGER DEFAULT 1,
            created_at      INTEGER NOT NULL,
            revoked_at      INTEGER
        );
        CREATE TABLE IF NOT EXISTS usage_log (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id         INTEGER NOT NULL REFERENCES users(id),
            endpoint        TEXT NOT NULL,
            timestamp       INTEGER NOT NULL,
            request_tokens  INTEGER DEFAULT 0,
            response_tokens INTEGER DEFAULT 0,
            total_tokens    INTEGER DEFAULT 0,
            credits_used    INTEGER DEFAULT 0,
            status_code     INTEGER NOT NULL,
            request_ip      TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_users_username    ON users(username);
        CREATE INDEX IF NOT EXISTS idx_users_nwtn_key    ON users(nwtn_key);
        CREATE INDEX IF NOT EXISTS idx_usage_user_time   ON usage_log(user_id, timestamp);
        CREATE INDEX IF NOT EXISTS idx_usage_time        ON usage_log(timestamp);
        """)

def get_user_by_username(username: str):
    with get_db() as conn:
        return conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()

def get_user_by_key(nwtn_key: str):
    with get_db() as conn:
        return conn.execute("SELECT * FROM users WHERE nwtn_key=? AND active=1", (nwtn_key,)).fetchone()

def log_usage(user_id, endpoint, req_tok, resp_tok, total_tok, credits, status, ip=""):
    with _db_lock:
        with get_db() as conn:
            conn.execute("""
                INSERT INTO usage_log(user_id,endpoint,timestamp,request_tokens,response_tokens,
                                     total_tokens,credits_used,status_code,request_ip)
                VALUES (?,?,?,?,?,?,?,?,?)
            """, (user_id, endpoint, int(time.time()), req_tok, resp_tok, total_tok, credits, status, ip))

# ──────────────────────────────────────────────
# Quota check
# ──────────────────────────────────────────────
def get_monday_epoch() -> int:
    """Return epoch of this week's Monday 00:00 local time."""
    t = time.time()
    import datetime
    now = datetime.datetime.fromtimestamp(t)
    monday = now - datetime.timedelta(days=now.weekday())
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    return int(monday.timestamp())

def check_quota(user_id: int) -> tuple:
    """Returns (ok: bool, reason: str). reason is empty string if ok."""
    now = int(time.time())
    window_5h = now - QUOTA_5H_SECS
    week_start = get_monday_epoch()

    with get_db() as conn:
        # 5-hour rolling window
        row5h = conn.execute(
            "SELECT COUNT(*) as cnt FROM usage_log WHERE user_id=? AND timestamp>=? AND status_code<400",
            (user_id, window_5h)
        ).fetchone()
        if row5h["cnt"] >= QUOTA_5H_MAX:
            reset_at = now + (QUOTA_5H_SECS - (now - window_5h))
            return False, f"Rate limit: {QUOTA_5H_MAX} requests per 5 hours. Resets in {(QUOTA_5H_SECS - (now - window_5h))//60} min."

        # Weekly
        row_wk = conn.execute(
            """SELECT COUNT(*) as msgs, COALESCE(SUM(total_tokens),0) as toks
               FROM usage_log WHERE user_id=? AND timestamp>=? AND status_code<400""",
            (user_id, week_start)
        ).fetchone()
        if row_wk["msgs"] >= QUOTA_WEEK_MSGS:
            return False, f"Weekly message quota reached ({QUOTA_WEEK_MSGS}/week). Resets Monday 00:00."
        if row_wk["toks"] >= QUOTA_WEEK_TOK:
            return False, f"Weekly token quota reached ({QUOTA_WEEK_TOK:,}/week). Resets Monday 00:00."

    return True, ""

# ──────────────────────────────────────────────
# NWTN Admin API helper
# ──────────────────────────────────────────────
def create_nwtn_key(name: str, credits: int = 100000, rpm: int = 60) -> str:
    """Call /admin/keys, return full ntwn-... key string."""
    base = NWTN_UPSTREAM.rstrip("/").replace("/nwtn", "")
    url = f"{base}/admin/keys"
    payload = json.dumps({"name": name, "credits": credits, "rpm_limit": rpm}).encode()
    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {NWTN_ADMIN_TOKEN}",
        "User-Agent": "Newton-iOS/2.0"
    }, method="POST")
    ctx = _ssl_ctx()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            data = json.loads(resp.read())
            return data.get("key") or data.get("api_key") or data.get("nwtn_key", "")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"[create_nwtn_key] Admin API error {e.code}: {body}")
        raise

# ──────────────────────────────────────────────
# HTTP Handler
# ──────────────────────────────────────────────
class NWTNHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS, DELETE, PATCH")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, x-api-key, X-Session-Id")
        self.send_header("Access-Control-Max-Age", "86400")

    def _send_json(self, code: int, data: dict, extra_headers: dict = None):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        for k, v in (extra_headers or {}).items():
            self.send_header(k, str(v))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length) if length > 0 else b""

    def _extract_bearer(self) -> str:
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            return auth[7:].strip()
        return self.headers.get("x-api-key", "").strip()

    # ── Route dispatch ──

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        p = urlparse(self.path).path
        if p in ("/health", "/api/health"):
            self._send_json(200, {"status": "ok", "service": "newton-proxy"})
        elif p == "/auth/me":
            self._handle_auth_me()
        elif p.startswith("/nwtn/"):
            self._handle_nwtn_proxy()
        else:
            self._send_json(404, {"error": {"code": "not_found", "message": "Not found"}})

    def _handle_auth_me(self):
        """Return current user's quota and usage info."""
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})

        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})

        now = int(time.time())
        window_5h = now - QUOTA_5H_SECS
        week_start = get_monday_epoch()

        with get_db() as conn:
            # 5-hour rolling window
            row5h = conn.execute(
                "SELECT COUNT(*) as cnt FROM usage_log WHERE user_id=? AND timestamp>=? AND status_code<400",
                (user["id"], window_5h)
            ).fetchone()
            req_5h = row5h["cnt"]

            # Weekly
            row_wk = conn.execute(
                """SELECT COUNT(*) as msgs, COALESCE(SUM(total_tokens),0) as toks
                   FROM usage_log WHERE user_id=? AND timestamp>=? AND status_code<400""",
                (user["id"], week_start)
            ).fetchone()
            msgs_week = row_wk["msgs"]
            toks_week = row_wk["toks"]

        self._send_json(200, {
            "ok": True,
            "username": user["username"],
            "credits_total": user["credits_total"],
            "credits_used": user["credits_used"],
            "credits_left": max(0, user["credits_total"] - user["credits_used"]),
            "trial_ends_at": user["trial_ends_at"],
            "rpm_limit": user["rpm_limit"],
            "quotas": {
                "req_5h": {"used": req_5h, "limit": QUOTA_5H_MAX, "reset_at": window_5h + QUOTA_5H_SECS},
                "msgs_week": {"used": msgs_week, "limit": QUOTA_WEEK_MSGS, "reset_at": week_start + 7*86400},
                "tokens_week": {"used": toks_week, "limit": QUOTA_WEEK_TOK, "reset_at": week_start + 7*86400}
            }
        })

    def do_POST(self):
        p = urlparse(self.path).path
        if p == "/auth/register":
            self._handle_register()
        elif p == "/auth/login":
            self._handle_login()
        elif p.startswith("/nwtn/"):
            self._handle_nwtn_proxy()
        else:
            self._send_json(404, {"error": {"code": "not_found", "message": "Not found"}})

    def do_DELETE(self):
        p = urlparse(self.path).path
        if p.startswith("/nwtn/"):
            self._handle_nwtn_proxy()
        else:
            self._send_json(404, {"error": {"code": "not_found", "message": "Not found"}})

    # ── Auth endpoints ──

    def _handle_register(self):
        try:
            body = json.loads(self._read_body())
        except Exception:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Invalid JSON"}})

        username = (body.get("username") or "").strip()
        password = (body.get("password") or "")
        credits  = int(body.get("credits", 100000))
        rpm      = int(body.get("rpm", 60))
        trial_days = int(body.get("trial_days", 30))

        if not username or len(username) < 3:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Username too short (min 3)"}})
        if not password or len(password) < 8:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Password too short (min 8)"}})

        # Check username taken
        if get_user_by_username(username):
            return self._send_json(409, {"error": {"code": "conflict", "message": "Username already taken"}})

        # Create NWTN key via admin API
        try:
            nwtn_key = create_nwtn_key(username, credits, rpm)
        except Exception as e:
            print(f"[register] ERROR creating key for '{username}': {e}")
            print(f"[register] Admin token used: {'adm-…'+NWTN_ADMIN_TOKEN[-4:] if NWTN_ADMIN_TOKEN.startswith('adm-') else 'INVALID/OLD token (not adm- prefix)'}")
            return self._send_json(502, {"error": {"code": "upstream_error", "message": f"Could not create key: {e}"}})

        if not nwtn_key or not nwtn_key.startswith("ntwn-"):
            return self._send_json(502, {"error": {"code": "upstream_error", "message": "Invalid key returned from NWTN admin API"}})

        nwtn_key_prefix = nwtn_key[5:17]  # 12 chars after "ntwn-"

        # Hash password
        pw_hash = _hash_password(password)

        trial_ends_at = None
        if trial_days > 0:
            trial_ends_at = int(time.time()) + trial_days * 86400

        with _db_lock:
            with get_db() as conn:
                try:
                    conn.execute("""
                        INSERT INTO users(username,password_hash,nwtn_key,nwtn_key_prefix,
                                         credits_total,credits_used,rpm_limit,trial_ends_at,
                                         active,created_at)
                        VALUES (?,?,?,?,?,0,?,?,1,?)
                    """, (username, pw_hash, nwtn_key, nwtn_key_prefix, credits, rpm,
                          trial_ends_at, int(time.time())))
                except sqlite3.IntegrityError:
                    return self._send_json(409, {"error": {"code": "conflict", "message": "Username already taken"}})

        self._send_json(201, {
            "ok": True,
            "nwtn_key": nwtn_key,
            "username": username,
            "credits": credits,
            "trial_ends_at": trial_ends_at
        })

    def _handle_login(self):
        try:
            body = json.loads(self._read_body())
        except Exception:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Invalid JSON"}})

        username = (body.get("username") or "").strip()
        password = (body.get("password") or "")

        user = get_user_by_username(username)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Invalid credentials"}})
        if not user["active"]:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Account revoked"}})

        if not _verify_password(password, user["password_hash"]):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Invalid credentials"}})

        self._send_json(200, {
            "ok": True,
            "nwtn_key": user["nwtn_key"],
            "username": user["username"],
            "credits_total": user["credits_total"],
            "credits_used": user["credits_used"],
            "trial_ends_at": user["trial_ends_at"]
        })

    # ── NWTN proxy ──

    def _handle_nwtn_proxy(self):
        # Extract and validate user key
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})

        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})

        # Trial check
        if user["trial_ends_at"] and int(time.time()) > user["trial_ends_at"]:
            # Trial expired but account still active — could allow paid use; for now just warn
            pass  # allow through; billing is handled by NWTN upstream credits

        # Quota check
        ok, reason = check_quota(user["id"])
        if not ok:
            return self._send_json(429, {"error": {"code": "quota_exceeded", "message": reason}})

        path = urlparse(self.path).path
        endpoint_path = path[5:] if path.startswith("/nwtn") else path  # strip /nwtn prefix → /chat etc
        target_url = NWTN_UPSTREAM.rstrip("/") + endpoint_path

        body = self._read_body()

        # Check if streaming
        is_stream = False
        if body:
            try:
                req_json = json.loads(body)
                is_stream = bool(req_json.get("stream", False))
            except Exception:
                pass

        # Build upstream request
        headers = {
            "Content-Type": self.headers.get("Content-Type", "application/json"),
            "Authorization": f"Bearer {key}",
            "User-Agent": "Newton-iOS/2.0",
        }

        req = urllib.request.Request(target_url, data=body or None, headers=headers, method=self.command)

        ctx = _ssl_ctx()
        t_start = int(time.time())

        if is_stream:
            self._proxy_stream(req, user, path, ctx, t_start)
        else:
            self._proxy_json(req, user, path, ctx, t_start)

    def _proxy_json(self, req, user, endpoint, ctx, t_start):
        """Forward non-streaming request, log usage."""
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
                raw = resp.read()
                status = resp.status
                credits_left = resp.headers.get("X-Credits-Left", "")
                try:
                    data = json.loads(raw)
                except Exception:
                    data = {"raw": raw.decode(errors="replace")}

                # Extract token usage
                used_tok = data.get("used_tokens", {})
                req_tok  = used_tok.get("input", 0)
                resp_tok = used_tok.get("output", 0)
                tot_tok  = used_tok.get("total", 0)
                cr_used  = data.get("credits_used", 0) or tot_tok

                log_usage(user["id"], endpoint, req_tok, resp_tok, tot_tok, cr_used, status,
                          self.client_address[0])

                extra = {"X-Credits-Left": credits_left} if credits_left else {}
                self._send_json(status, data, extra)

        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                err_data = json.loads(raw)
            except Exception:
                err_data = {"error": {"code": "http_error", "message": raw.decode(errors="replace")}}
            log_usage(user["id"], endpoint, 0, 0, 0, 0, e.code, self.client_address[0])
            self._send_json(e.code, err_data)
        except Exception as e:
            log_usage(user["id"], endpoint, 0, 0, 0, 0, 502, self.client_address[0])
            self._send_json(502, {"error": {"code": "proxy_error", "message": str(e)}})

    def _proxy_stream(self, req, user, endpoint, ctx, t_start):
        """Forward SSE streaming response, log usage from final done event."""
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=300) as resp:
                credits_left = resp.headers.get("X-Credits-Left", "")
                # Send SSE headers
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream; charset=utf-8")
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Transfer-Encoding", "chunked")
                self._cors()
                if credits_left:
                    self.send_header("X-Credits-Left", credits_left)
                self.end_headers()

                req_tok = resp_tok = tot_tok = cr_used = 0
                status = 200

                # Read line by line, forward to client
                buf = b""
                while True:
                    chunk = resp.read(1)
                    if not chunk:
                        break
                    buf += chunk
                    if chunk == b"\n":
                        line = buf.decode(errors="replace").rstrip("\n")
                        buf = b""
                        if line.startswith("data: "):
                            payload = line[6:]
                            if payload == "[DONE]":
                                self.wfile.write(b"data: [DONE]\n\n")
                                self.wfile.flush()
                                break
                            try:
                                evt = json.loads(payload)
                                if evt.get("done"):
                                    used = evt.get("used_tokens", {})
                                    req_tok  = used.get("input", 0)
                                    resp_tok = used.get("output", 0)
                                    tot_tok  = used.get("total", 0)
                                    cr_used  = evt.get("credits_left", 0)
                            except Exception:
                                pass
                            out = f"data: {payload}\n\n".encode()
                            self.wfile.write(out)
                            self.wfile.flush()
                        elif line:
                            self.wfile.write((line + "\n").encode())
                            self.wfile.flush()

                log_usage(user["id"], endpoint, req_tok, resp_tok, tot_tok, cr_used, status,
                          self.client_address[0])

        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                err_data = json.loads(raw)
            except Exception:
                err_data = {"error": {"code": "http_error", "message": raw.decode(errors="replace")}}
            log_usage(user["id"], endpoint, 0, 0, 0, 0, e.code, self.client_address[0])
            # Can't SSE error after headers sent in happy path, but here we haven't sent headers yet
            self._send_json(e.code, err_data)
        except Exception as e:
            log_usage(user["id"], endpoint, 0, 0, 0, 0, 502, self.client_address[0])
            self._send_json(502, {"error": {"code": "stream_error", "message": str(e)}})

    def log_message(self, fmt, *args):
        if getattr(self.server, "verbose", False):
            print(f"[{self.address_string()}] {fmt % args}")


# ──────────────────────────────────────────────
# Server Runner
# ──────────────────────────────────────────────
def run_server(port: int = BACKEND_PORT, verbose: bool = False):
    print("🗄  Initializing database...")
    ensure_schema()

    server = HTTPServer(("0.0.0.0", port), NWTNHandler)
    server.verbose = verbose

    print(f"\n⚡ Newton Proxy running on http://localhost:{port}")
    print(f"   NWTN upstream: {NWTN_UPSTREAM}")
    print(f"   DB: {DB_PATH}")
    print(f"")
    print(f"   POST /auth/register  — Create user account")
    print(f"   POST /auth/login     — Login → nwtn key")
    print(f"   GET  /nwtn/models    — List models")
    print(f"   POST /nwtn/chat      — Chat (streaming supported)")
    print(f"   POST /nwtn/images    — Generate images")
    print(f"   *    /nwtn/*         — All NWTN endpoints proxied")
    print(f"   GET  /health         — Health check")
    print(f"")
    print(f"   Press Ctrl+C to stop.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
        server.server_close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Newton Proxy Server")
    parser.add_argument("--port", type=int, default=BACKEND_PORT)
    parser.add_argument("--verbose", "-v", action="store_true")
    a = parser.parse_args()
    run_server(port=a.port, verbose=a.verbose)

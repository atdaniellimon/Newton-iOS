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
from urllib.parse import urlparse, quote
import urllib.request
import urllib.error
import ssl
from pathlib import Path
from dotenv import load_dotenv
import certifi
import requests

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

# Email verification (Resend)
RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
RESEND_FROM    = os.getenv("RESEND_FROM", "Newton <onboarding@newton.daniellimon.uk>")
VERIFY_BASE_URL= os.getenv("VERIFY_BASE_URL", "https://auth.newton.daniellimon.uk").rstrip("/")
VERIFY_TOKEN_TTL = 24 * 3600            # verification link expiry (seconds)
VERIFY_RESEND_COOLDOWN = 60             # min seconds between resends

# Auth brute-force protection
AUTH_IP_LIMIT      = 10   # max auth requests (register+login) per IP per window
AUTH_IP_WINDOW     = 60   # seconds
MAX_FAILED_ATTEMPTS = 5   # lock account after this many failed logins
AUTH_LOCKOUT_SECS  = 15 * 60   # lock duration

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

        # Idempotent migrations for columns added after the initial schema.
        existing = {r[1] for r in conn.execute("PRAGMA table_info(users)")}
        _cols = [
            ("email",               "TEXT"),
            ("email_verified",      "INTEGER DEFAULT 0"),
            ("verification_token",  "TEXT"),
            ("verification_sent_at","INTEGER"),
            ("failed_attempts",     "INTEGER DEFAULT 0"),
            ("locked_until",        "INTEGER"),
            ("credits_left",        "INTEGER"),
        ]
        for col, ddl in _cols:
            if col not in existing:
                conn.execute(f"ALTER TABLE users ADD COLUMN {col} {ddl}")

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

def increment_credits(user_id, amount):
    """Accumulate consumed credits on the user row so /auth/me can report real usage."""
    if not amount or amount <= 0:
        return
    with _db_lock:
        with get_db() as conn:
            conn.execute("UPDATE users SET credits_used = credits_used + ? WHERE id=?",
                         (int(amount), user_id))

def set_credits_left(user_id, amount):
    """Record the upstream's remaining-credit snapshot so billing reconciles on the next request."""
    with _db_lock:
        with get_db() as conn:
            conn.execute("UPDATE users SET credits_left=? WHERE id=?", (int(amount), user_id))

def apply_billing(user_id: int, cr_used: int, credits_left_header: str = None):
    """
    Reconcile consumed credits from the latest DB snapshot and upstream signals.
    """
    with _db_lock:
        with get_db() as conn:
            current = conn.execute("SELECT credits_left, credits_total, credits_used FROM users WHERE id=?", (user_id,)).fetchone()
            if not current:
                return

            new_left = None
            if credits_left_header:
                try:
                    new_left = int(credits_left_header)
                except (TypeError, ValueError):
                    new_left = None

            if new_left is not None:
                prev = current["credits_left"]
                if prev is None:
                    prev = max(0, (current["credits_total"] or 0) - (current["credits_used"] or 0))
                spent = prev - new_left
                if spent > 0:
                    conn.execute("UPDATE users SET credits_used = credits_used + ?, credits_left = ? WHERE id = ?",
                                 (spent, new_left, user_id))
                else:
                    conn.execute("UPDATE users SET credits_left = ? WHERE id = ?", (new_left, user_id))
                return

            if cr_used and cr_used > 0:
                conn.execute("""
                    UPDATE users 
                    SET credits_used = credits_used + ?,
                        credits_left = CASE 
                            WHEN credits_left IS NOT NULL THEN MAX(0, credits_left - ?)
                            ELSE credits_left 
                        END
                    WHERE id = ?
                """, (int(cr_used), int(cr_used), user_id))

def call_nwtn_admin_revoke(key_prefix: str) -> bool:
    """Revoke a key on the NWTN admin API. Returns True on success (False on any error)."""
    if not NWTN_ADMIN_TOKEN or not key_prefix:
        return False
    base = NWTN_UPSTREAM.rstrip("/").replace("/nwtn", "")
    url = f"{base}/admin/keys/revoke"
    payload = json.dumps({"key_prefix": key_prefix}).encode()
    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {NWTN_ADMIN_TOKEN}",
        "User-Agent": "Newton-iOS/2.0",
    }, method="POST")
    try:
        with urllib.request.urlopen(req, context=_ssl_ctx(), timeout=30) as resp:
            data = json.loads(resp.read())
            return bool(data.get("success") or data.get("ok"))
    except Exception as e:
        print(f"[revoke] Admin API revoke failed for '{key_prefix}': {e}")
        return False

# ──────────────────────────────────────────────
# Email verification (Resend)
# ──────────────────────────────────────────────
def send_verification_email(to_email: str, username: str, token: str) -> bool:
    """Send a verification email via Resend. Returns True on success, False on error."""
    if not RESEND_API_KEY or not to_email:
        print("[email] RESEND_API_KEY not set — skipping verification email.")
        return False
    link = f"{VERIFY_BASE_URL}/verify?token={quote(token)}&user={quote(username)}"
    html = (
        "<div style='font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:480px;margin:auto;"
        "padding:32px;color:#e8e6e3;background:#0f1115;border-radius:12px'>"
        "<h2 style='color:#f4d59c'>Verify your email</h2>"
        f"<p>Hi <strong>{username}</strong>, confirm your address to start using Newton.</p>"
        f"<p><a href='{link}' style='display:inline-block;padding:12px 22px;background:#f4d59c;"
        "color:#111;text-decoration:none;border-radius:8px;font-weight:600'>Verify email</a></p>"
        f"<p style='color:#9aa0a6;font-size:12px'>Or open this link:<br>{link}</p>"
        f"<p style='color:#9aa0a6;font-size:12px'>This link expires in 24 hours.</p>"
        "</div>"
    )
    payload = json.dumps({
        "from": RESEND_FROM,
        "to": [to_email],
        "subject": "Verify your Newton email",
        "html": html,
    }).encode()
    req = urllib.request.Request("https://api.resend.com/emails", data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "User-Agent": "Newton-iOS/2.0",
    }, method="POST")
    try:
        with urllib.request.urlopen(req, context=_ssl_ctx(), timeout=30) as resp:
            return resp.status < 300
    except Exception as e:
        print(f"[email] Resend send failed for {to_email}: {e}")
        return False

def new_verification_token() -> str:
    return secrets.token_urlsafe(32)

# ──────────────────────────────────────────────
# Auth brute-force protection (per-IP rate limit)
# ──────────────────────────────────────────────
_auth_lock = threading.Lock()
_auth_buckets: dict = {}   # ip -> list of monotonic request timestamps

def _rate_limit_ip(ip: str) -> bool:
    """Return True if allowed, False if this IP is over the auth rate limit."""
    now = time.time()
    with _auth_lock:
        cutoff = now - AUTH_IP_WINDOW
        bucket = [t for t in _auth_buckets.get(ip, []) if t > cutoff]
        if len(bucket) >= AUTH_IP_LIMIT:
            return False
        bucket.append(now)
        _auth_buckets[ip] = bucket
        return True

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
        elif p == "/verify":
            self._handle_verify()
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

        # Legacy accounts predate email; treat a missing email as verified-exempt.
        email = user["email"] or ""
        email_verified = bool(user["email_verified"]) or not email

        # Prefer the upstream's remaining-credit snapshot when we have one.
        credits_left = user["credits_left"]
        if credits_left is None:
            credits_left = max(0, (user["credits_total"] or 0) - (user["credits_used"] or 0))

        self._send_json(200, {
            "ok": True,
            "username": user["username"],
            "email": email,
            "email_verified": email_verified,
            "credits_total": user["credits_total"],
            "credits_used": user["credits_used"],
            "credits_left": credits_left,
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
        elif p == "/auth/resend-verification":
            self._handle_resend_verification()
        elif p == "/auth/logout":
            self._handle_logout()
        elif p == "/auth/rotate-key":
            self._handle_rotate_key()
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
        if not _rate_limit_ip(self.client_address[0]):
            return self._send_json(429, {"error": {"code": "rate_limited", "message": "Too many attempts. Slow down."}})

        try:
            body = json.loads(self._read_body())
        except Exception:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Invalid JSON"}})

        username = (body.get("username") or "").strip()
        password = (body.get("password") or "")
        email    = (body.get("email") or "").strip().lower()
        credits  = int(body.get("credits", 100000))
        rpm      = int(body.get("rpm", 60))
        trial_days = int(body.get("trial_days", 30))

        if not email or "@" not in email or "." not in email.split("@")[-1]:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "A valid email is required"}})
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
                                         active,created_at,email,email_verified)
                        VALUES (?,?,?,?,?,0,?,?,1,?,?,0)
                    """, (username, pw_hash, nwtn_key, nwtn_key_prefix, credits, rpm,
                          trial_ends_at, int(time.time()), email))
                except sqlite3.IntegrityError:
                    return self._send_json(409, {"error": {"code": "conflict", "message": "Username already taken"}})

        # Email verification is best-effort: account is usable after verify,
        # and the user can re-request the email via /auth/resend-verification.
        verif_token = new_verification_token()
        with _db_lock:
            with get_db() as conn:
                conn.execute("UPDATE users SET verification_token=?, verification_sent_at=? WHERE username=?",
                             (verif_token, int(time.time()), username))
        sent = send_verification_email(email, username, verif_token)

        self._send_json(201, {
            "ok": True,
            "nwtn_key": nwtn_key,
            "username": username,
            "email": email,
            "email_verified": False,
            "email_sent": sent,
            "credits": credits,
            "trial_ends_at": trial_ends_at
        })

    def _handle_login(self):
        if not _rate_limit_ip(self.client_address[0]):
            return self._send_json(429, {"error": {"code": "rate_limited", "message": "Too many attempts. Slow down."}})

        try:
            body = json.loads(self._read_body())
        except Exception:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "Invalid JSON"}})

        username = (body.get("username") or "").strip()
        password = (body.get("password") or "")

        user = get_user_by_username(username)
        if not user:
            # Same response as a bad password so we don't leak which usernames exist.
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Invalid credentials"}})
        if not user["active"]:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Account revoked"}})

        # Lockout check
        locked_until = user["locked_until"]
        if locked_until and int(time.time()) < locked_until:
            wait = locked_until - int(time.time())
            return self._send_json(429, {"error": {"code": "account_locked", "message": f"Account temporarily locked. Try again in {wait // 60 + 1} min."}})

        if not _verify_password(password, user["password_hash"]):
            with _db_lock:
                with get_db() as conn:
                    failed = (user["failed_attempts"] or 0) + 1
                    if failed >= MAX_FAILED_ATTEMPTS:
                        conn.execute("UPDATE users SET failed_attempts=0, locked_until=? WHERE id=?",
                                     (int(time.time()) + AUTH_LOCKOUT_SECS, user["id"]))
                    else:
                        conn.execute("UPDATE users SET failed_attempts=? WHERE id=?", (failed, user["id"]))
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Invalid credentials"}})

        # Success — clear failed-attempt / lockout state
        with _db_lock:
            with get_db() as conn:
                conn.execute("UPDATE users SET failed_attempts=0, locked_until=NULL WHERE id=?", (user["id"],))

        email = user["email"] or ""
        email_verified = bool(user["email_verified"]) or not email

        self._send_json(200, {
            "ok": True,
            "nwtn_key": user["nwtn_key"],
            "username": user["username"],
            "email": email,
            "email_verified": email_verified,
            "credits_total": user["credits_total"],
            "credits_used": user["credits_used"],
            "trial_ends_at": user["trial_ends_at"]
        })

    # ── Email verification & key management ──

    def _handle_verify(self):
        """GET /verify?token=...&user=... — confirm email and return a small HTML page."""
        q = urlparse(self.path).query
        params = dict(kv.split("=", 1) for kv in q.split("&") if "=" in kv) if q else {}
        token = params.get("token", "")
        token = token.replace("%20", "+")  # urlopen re-encodes; tolerate quoting artifacts

        if not token:
            return self._send_html(400, "Missing token.")

        with get_db() as conn:
            row = conn.execute("SELECT id, username, email, verification_sent_at FROM users WHERE verification_token=? AND email_verified=0", (token,)).fetchone()
            if not row:
                return self._send_html(400, "Invalid or already-used verification link.")
            if row["verification_sent_at"] and (int(time.time()) - row["verification_sent_at"]) > VERIFY_TOKEN_TTL:
                return self._send_html(400, "This verification link has expired. Please request a new one.")

            conn.execute("UPDATE users SET email_verified=1, verification_token=NULL, verification_sent_at=NULL WHERE id=?", (row["id"],))

        self._send_html(200, f"Email verified ✓ — you can now sign in as <strong>{row['username']}</strong>.")

    def _handle_resend_verification(self):
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})
        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})

        email = user["email"] or ""
        if not email:
            return self._send_json(400, {"error": {"code": "bad_request", "message": "No email on this account"}})
        if user["email_verified"]:
            return self._send_json(200, {"ok": True, "email_verified": True})

        # Cooldown to avoid spamming the inbox
        last = user["verification_sent_at"] or 0
        if (int(time.time()) - last) < VERIFY_RESEND_COOLDOWN:
            wait = VERIFY_RESEND_COOLDOWN - (int(time.time()) - last)
            return self._send_json(429, {"error": {"code": "rate_limited", "message": f"Please wait {wait}s before resending."}})

        token = new_verification_token()
        with _db_lock:
            with get_db() as conn:
                conn.execute("UPDATE users SET verification_token=?, verification_sent_at=? WHERE id=?",
                             (token, int(time.time()), user["id"]))
        sent = send_verification_email(email, user["username"], token)

        if not sent and not RESEND_API_KEY:
            return self._send_json(503, {"error": {"code": "email_not_configured", "message": "Email service not configured."}})

        self._send_json(200, {"ok": True, "email_sent": sent})

    def _handle_logout(self):
        """
        Logout is client-side (drop the key from the Keychain). We only validate
        the key so the client can confirm server-side that it's a live credential;
        destructive revocation is available via /auth/rotate-key and the admin
        revoke_user.py script.
        """
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})
        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})
        self._send_json(200, {"ok": True})

    def _handle_rotate_key(self):
        """Rotate the caller's key: revoke the old one upstream and issue a new one."""
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})
        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})

        # Issue the new key first so we never strand a user without credentials.
        try:
            new_key = create_nwtn_key(user["username"], user["credits_total"], user["rpm_limit"])
        except Exception as e:
            return self._send_json(502, {"error": {"code": "upstream_error", "message": f"Could not rotate key: {e}"}})
        if not new_key or not new_key.startswith("ntwn-"):
            return self._send_json(502, {"error": {"code": "upstream_error", "message": "Invalid key returned from NWTN admin API"}})

        revoke_ok = call_nwtn_admin_revoke(user["nwtn_key_prefix"])

        new_prefix = new_key[5:17]
        with _db_lock:
            with get_db() as conn:
                conn.execute("UPDATE users SET nwtn_key=?, nwtn_key_prefix=? WHERE id=?",
                             (new_key, new_prefix, user["id"]))

        self._send_json(200, {
            "ok": True,
            "nwtn_key": new_key,
            "old_key_revoked": revoke_ok
        })

    def _send_html(self, code: int, message: str):
        html = (
            "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
            "<title>Newton — Email verification</title></head>"
            "<body style='font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0f1115;color:#e8e6e3;"
            "display:flex;align-items:center;justify-content:center;height:100vh;margin:0'>"
            f"<div style='max-width:420px;text-align:center;padding:32px'><h2 style='color:#f4d59c'>Newton</h2>"
            f"<p>{message}</p></div></body></html>"
        )
        body = html.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    # ── NWTN proxy ──

    def _handle_nwtn_proxy(self):
        # Extract and validate user key
        key = self._extract_bearer()
        if not key or not key.startswith("ntwn-"):
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Missing or invalid API key"}})

        user = get_user_by_key(key)
        if not user:
            return self._send_json(401, {"error": {"code": "unauthorized", "message": "Key not found or revoked"}})

        # Email verification gate — only for accounts that have an email (legacy exempt)
        email = user["email"] or ""
        if email and not user["email_verified"]:
            return self._send_json(403, {"error": {"code": "email_not_verified",
                                                  "message": "Please verify your email before using Newton."}})

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
                if status < 400:
                    apply_billing(user["id"], cr_used, credits_left)

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
                initial_credits_left = resp.headers.get("X-Credits-Left", "")
                final_credits_left = initial_credits_left

                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream; charset=utf-8")
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Transfer-Encoding", "chunked")
                self._cors()
                if initial_credits_left:
                    self.send_header("X-Credits-Left", initial_credits_left)
                self.end_headers()

                req_tok = resp_tok = tot_tok = cr_used = 0
                status = 200

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
                                # Capturar tokens si vienen en 'used_tokens' o en el formato estándar 'usage'
                                usage = evt.get("used_tokens") or evt.get("usage") or {}
                                if usage:
                                    req_tok = usage.get("input") or usage.get("prompt_tokens") or req_tok
                                    resp_tok = usage.get("output") or usage.get("completion_tokens") or resp_tok
                                    tot_tok = usage.get("total") or usage.get("total_tokens") or (req_tok + resp_tok)

                                if evt.get("credits_used") is not None:
                                    cr_used = evt.get("credits_used")
                                elif tot_tok and not cr_used:
                                    cr_used = tot_tok

                                # Capturar credits_left si el evento final lo envía
                                if evt.get("credits_left") is not None:
                                    final_credits_left = str(evt.get("credits_left"))
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
            
            if status < 400:
                apply_billing(user["id"], cr_used, final_credits_left)

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
            self._send_json(502, {"error": {"code": "stream_error", "message": str(e)}})

    def log_message(self, fmt, *args):
        if getattr(self.server, "verbose", False):
            print(f"[{self.address_string()}] {fmt % args}")


# ──────────────────────────────────────────────
# Server Runner
# ──────────────────────────────────────────────
def run_server(port: int = BACKEND_PORT, verbose: bool = False):
    ensure_schema()

    server = HTTPServer(("0.0.0.0", port), NWTNHandler)
    server.verbose = verbose

    print(f"\n Newton Proxy running on http://localhost:{port}")
    print(f"   NWTN upstream: {NWTN_UPSTREAM}")
    print(f"   DB: {DB_PATH}")
    print(f"")
    print(f"   POST /auth/register  — Create user account")
    print(f"   POST /auth/login     — Login → nwtn key")
    print(f"   GET  /auth/verify    — Confirm email (link from email)")
    print(f"   POST /auth/resend-verification — Resend verification email")
    print(f"   POST /auth/logout    — Validate key (client drops it)")
    print(f"   POST /auth/rotate-key — Revoke old key + issue new one")
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

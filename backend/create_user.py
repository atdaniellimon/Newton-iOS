#!/usr/bin/env python3
"""
Admin script — create a Newton user with a NWTN key.
Usage: python create_user.py <username> <password> [--credits N] [--rpm N] [--trial-days N]
"""

import argparse
import os
import sys
import sqlite3
import time
import json
import urllib.request
import urllib.error
import ssl
import hashlib
import secrets
import base64
import certifi
from datetime import datetime, timedelta
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


# Password hashing using PBKDF2 (stdlib, no external deps)
def _hash_password(password: str) -> str:
    """Hash password with PBKDF2-HMAC-SHA256. Returns 'pbkdf2$salt$hash'."""
    salt = secrets.token_hex(16)
    hash_bytes = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
    hash_b64 = base64.b64encode(hash_bytes).decode()
    return f"pbkdf2${salt}${hash_b64}"


# SSL context with certifi CA bundle (fixes macOS SSL verification)
def _ssl_ctx() -> ssl.SSLContext:
    ctx = ssl.create_default_context(cafile=certifi.where())
    return ctx


def get_env(name: str, default: str = None) -> str:
    v = os.getenv(name, default)
    if v is None:
        print(f"Error: {name} not set in environment", file=sys.stderr)
        sys.exit(1)
    return v


def create_nwtn_key(name: str, credits: int, rpm: int) -> str:
    admin_token = get_env("NWTN_ADMIN_TOKEN")
    upstream    = get_env("NWTN_UPSTREAM", "https://api.newton.daniellimon.uk/nwtn")
    base        = upstream.rstrip("/").replace("/nwtn", "")
    url         = f"{base}/admin/keys"
    payload     = json.dumps({"name": name, "credits": credits, "rpm_limit": rpm}).encode()

    req = urllib.request.Request(url, data=payload, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {admin_token}",
        "User-Agent": "Newton-iOS/2.0"
    }, method="POST")

    ctx = _ssl_ctx()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            data = json.loads(resp.read())
            key = data.get("key") or data.get("api_key") or data.get("nwtn_key", "")
            if not key:
                print(f"Error: No key in response: {data}", file=sys.stderr)
                sys.exit(1)
            return key
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"Error from NWTN admin API ({e.code}): {body}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error calling NWTN admin API: {e}", file=sys.stderr)
        sys.exit(1)


def ensure_schema(conn: sqlite3.Connection):
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
    CREATE INDEX IF NOT EXISTS idx_users_username  ON users(username);
    CREATE INDEX IF NOT EXISTS idx_users_nwtn_key  ON users(nwtn_key);
    CREATE INDEX IF NOT EXISTS idx_usage_user_time ON usage_log(user_id, timestamp);
    CREATE INDEX IF NOT EXISTS idx_usage_time      ON usage_log(timestamp);
    """)


def main():
    parser = argparse.ArgumentParser(description="Create a Newton user")
    parser.add_argument("username")
    parser.add_argument("password")
    parser.add_argument("--credits",    type=int, default=100000)
    parser.add_argument("--rpm",        type=int, default=60)
    parser.add_argument("--trial-days", type=int, default=30)
    args = parser.parse_args()

    if len(args.username) < 3:
        print("Error: username must be ≥ 3 chars", file=sys.stderr); sys.exit(1)
    if len(args.password) < 8:
        print("Error: password must be ≥ 8 chars", file=sys.stderr); sys.exit(1)

    db_path = get_env("DB_PATH", str(Path(__file__).parent / "users.db"))

    # Create NWTN key first
    print(f"Creating NWTN key for '{args.username}'…")
    nwtn_key = create_nwtn_key(args.username, args.credits, args.rpm)
    if not nwtn_key.startswith("ntwn-"):
        print(f"Error: unexpected key format: {nwtn_key}", file=sys.stderr); sys.exit(1)

    nwtn_key_prefix = nwtn_key[5:17]  # 12 chars after "ntwn-"

    pw_hash = _hash_password(args.password)
    trial_ends_at = int(time.time()) + args.trial_days * 86400 if args.trial_days > 0 else None
    now = int(time.time())

    conn = sqlite3.connect(db_path)
    try:
        ensure_schema(conn)
        conn.execute("""
            INSERT INTO users(username,password_hash,nwtn_key,nwtn_key_prefix,
                              credits_total,credits_used,rpm_limit,trial_ends_at,active,created_at)
            VALUES (?,?,?,?,?,0,?,?,1,?)
        """, (args.username, pw_hash, nwtn_key, nwtn_key_prefix,
              args.credits, args.rpm, trial_ends_at, now))
        conn.commit()
    except sqlite3.IntegrityError:
        print(f"Error: user '{args.username}' already exists", file=sys.stderr)
        conn.close()
        sys.exit(1)
    finally:
        conn.close()

    trial_str = ""
    if trial_ends_at:
        trial_str = f"\n   Trial ends:  {datetime.fromtimestamp(trial_ends_at).strftime('%Y-%m-%d')}"

    print(f"\n✅  User '{args.username}' created!")
    print(f"\n🔑  NWTN Key (save this — shown only once):\n   {nwtn_key}")
    print(f"\n   Credits: {args.credits:,}  |  RPM: {args.rpm}{trial_str}")


if __name__ == "__main__":
    main()

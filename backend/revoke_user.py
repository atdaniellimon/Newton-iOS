#!/usr/bin/env python3
"""
Admin script to revoke a user's NWTN key and deactivate their account.
Usage: python revoke_user.py <username>
"""

import argparse
import os
import sys
import sqlite3
import urllib.request
import urllib.error
import json
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def get_env_var(name: str, default: str = None) -> str:
    """Get environment variable with optional default."""
    value = os.getenv(name, default)
    if value is None:
        print(f"Error: Required environment variable {name} not set", file=sys.stderr)
        sys.exit(1)
    return value


def call_nwtn_admin_revoke(key_prefix: str) -> bool:
    """Call NWTN admin API to revoke an API key."""
    admin_token = get_env_var("NWTN_ADMIN_TOKEN")
    upstream = get_env_var("NWTN_UPSTREAM")

    url = f"{upstream.rstrip('/')}/admin/keys/revoke"
    payload = {
        "key_prefix": key_prefix
    }

    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {admin_token}'
        },
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            response_data = json.loads(response.read().decode('utf-8'))
            return response_data.get('success', False)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='replace')
        print(f"Error calling NWTN admin API ({e.code}): {error_body}", file=sys.stderr)
        return False
    except urllib.error.URLError as e:
        print(f"Error connecting to NWTN upstream: {e.reason}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Unexpected error calling NWTN admin API: {e}", file=sys.stderr)
        return False


def get_key_prefix(nwtn_key: str) -> str:
    """Extract the key prefix (first 12 chars after 'ntwn-') from the NWTN key."""
    if not nwtn_key.startswith('ntwn-'):
        print(f"Error: Invalid NWTN key format: {nwtn_key}", file=sys.stderr)
        sys.exit(1)
    return nwtn_key[5:17]  # Skip 'ntwn-' (5 chars), take next 12


def init_database(db_path: str) -> sqlite3.Connection:
    """Initialize the users database with schema, adding revocation columns if needed."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            nwtn_key TEXT UNIQUE NOT NULL,
            credits_total INTEGER NOT NULL DEFAULT 0,
            rpm_limit INTEGER NOT NULL DEFAULT 60,
            trial_ends_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            active INTEGER NOT NULL DEFAULT 1,
            revoked_at TIMESTAMP
        )
    """)

    # Add active and revoked_at columns if they don't exist (for older databases)
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN active INTEGER NOT NULL DEFAULT 1")
    except sqlite3.OperationalError:
        pass  # Column already exists

    try:
        cursor.execute("ALTER TABLE users ADD COLUMN revoked_at TIMESTAMP")
    except sqlite3.OperationalError:
        pass  # Column already exists

    conn.commit()
    return conn


def get_user(conn: sqlite3.Connection, username: str):
    """Get user by username."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, username, nwtn_key, active, revoked_at
        FROM users
        WHERE username = ?
    """, (username,))
    return cursor.fetchone()


def revoke_user(conn: sqlite3.Connection, username: str) -> bool:
    """Revoke user by setting active=0 and revoked_at=now."""
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    cursor.execute("""
        UPDATE users
        SET active = 0, revoked_at = ?
        WHERE username = ?
    """, (now, username))
    conn.commit()
    return cursor.rowcount > 0


def main():
    parser = argparse.ArgumentParser(
        description="Revoke a user's NWTN key and deactivate their account",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python revoke_user.py alice
        """
    )
    parser.add_argument("username", help="Username to revoke")

    args = parser.parse_args()

    # Validate inputs
    if not args.username or not args.username.strip():
        print("Error: Username cannot be empty", file=sys.stderr)
        sys.exit(1)

    # Get database path
    db_path = get_env_var("DB_PATH", str(Path(__file__).parent.parent / "users.db"))

    # Initialize database and get user
    conn = init_database(db_path)
    try:
        user = get_user(conn, args.username)
        if not user:
            print(f"Error: User '{args.username}' not found", file=sys.stderr)
            sys.exit(1)

        user_id, username, nwtn_key, active, revoked_at = user

        if not active:
            print(f"Error: User '{username}' is already revoked (revoked at: {revoked_at})", file=sys.stderr)
            sys.exit(1)

        # Get key prefix from nwtn_key
        key_prefix = get_key_prefix(nwtn_key)

        # Call NWTN admin API to revoke the key
        print(f"Revoking NWTN key for user '{username}' (prefix: {key_prefix})...")
        success = call_nwtn_admin_revoke(key_prefix)

        if not success:
            print("Error: Failed to revoke NWTN key via admin API", file=sys.stderr)
            sys.exit(1)

        # Update local database
        if not revoke_user(conn, username):
            print(f"Error: Failed to update user '{username}' in database", file=sys.stderr)
            sys.exit(1)

        print(f"\n✅ User '{username}' revoked successfully!")
        print(f"   Key prefix: {key_prefix}")
        print(f"   Revoked at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        sys.exit(0)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
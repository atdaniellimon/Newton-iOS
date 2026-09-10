#!/usr/bin/env python3
"""
Database initialization script for Newton API.
Creates users.db with users and usage_log tables, plus indexes.
"""

import sqlite3
import os
from pathlib import Path


def init_database(db_path: str = "users.db") -> None:
    """
    Initialize the database with required tables and indexes.

    Args:
        db_path: Path to the SQLite database file
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create users table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            nwtn_key TEXT UNIQUE NOT NULL,
            nwtn_key_prefix TEXT NOT NULL,
            credits_total INTEGER DEFAULT 100000,
            credits_used INTEGER DEFAULT 0,
            rpm_limit INTEGER DEFAULT 60,
            trial_ends_at INTEGER,
            active INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            revoked_at INTEGER
        )
    """)

    # Create usage_log table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usage_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id),
            endpoint TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            request_tokens INTEGER DEFAULT 0,
            response_tokens INTEGER DEFAULT 0,
            total_tokens INTEGER DEFAULT 0,
            credits_used INTEGER DEFAULT 0,
            status_code INTEGER NOT NULL,
            request_ip TEXT
        )
    """)

    # Create indexes
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_users_nwtn_key ON users(nwtn_key)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_usage_user_time ON usage_log(user_id, timestamp)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_usage_time ON usage_log(timestamp)
    """)

    conn.commit()
    conn.close()
    print(f"Database initialized at {db_path}")


if __name__ == "__main__":
    # Default to users.db in the same directory as this script
    script_dir = Path(__file__).parent
    db_path = script_dir / "users.db"
    init_database(str(db_path))
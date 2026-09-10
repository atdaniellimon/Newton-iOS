#!/usr/bin/env python3
"""
Weekly usage report generator for Newton API.
Usage: python report.py [--json] [--user username] [--days 7]
"""

import argparse
import os
import sys
import sqlite3
import json
from datetime import datetime, timedelta
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


def get_week_start() -> int:
    """Get Monday 00:00 of current week as epoch seconds."""
    now = datetime.now()
    # Monday = 0 in Python weekday
    days_since_monday = now.weekday()
    monday = now - timedelta(days=days_since_monday)
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    return int(monday.timestamp())


def get_user(conn: sqlite3.Connection, username: str):
    """Get user by username."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, username, nwtn_key, credits_total, credits_used, rpm_limit, trial_ends_at, active
        FROM users
        WHERE username = ?
    """, (username,))
    return cursor.fetchone()


def get_usage_stats(conn: sqlite3.Connection, user_id: int = None, days: int = 7):
    """Get usage statistics from usage_log."""
    cursor = conn.cursor()

    since = int((datetime.now() - timedelta(days=days)).timestamp())

    if user_id:
        cursor.execute("""
            SELECT endpoint, timestamp, request_tokens, response_tokens, total_tokens, credits_used, status_code
            FROM usage_log
            WHERE user_id = ? AND timestamp >= ?
            ORDER BY timestamp DESC
        """, (user_id, since))
    else:
        cursor.execute("""
            SELECT u.username, endpoint, timestamp, request_tokens, response_tokens, total_tokens, credits_used, status_code
            FROM usage_log l
            JOIN users u ON l.user_id = u.id
            WHERE l.timestamp >= ?
            ORDER BY l.timestamp DESC
        """, (since,))

    return cursor.fetchall()


def aggregate_by_user(rows, has_username=False):
    """Aggregate usage by user."""
    stats = {}
    for row in rows:
        if has_username:
            username, endpoint, timestamp, req_tokens, resp_tokens, total_tokens, credits, status = row
        else:
            username = "N/A"
            endpoint, timestamp, req_tokens, resp_tokens, total_tokens, credits, status = row

        if username not in stats:
            stats[username] = {
                'requests': 0,
                'total_tokens': 0,
                'total_credits': 0,
                'endpoints': {},
                'daily': {},
                'status_codes': {}
            }

        s = stats[username]
        s['requests'] += 1
        s['total_tokens'] += total_tokens or 0
        s['total_credits'] += credits or 0

        # Endpoint breakdown
        ep = endpoint or 'unknown'
        s['endpoints'][ep] = s['endpoints'].get(ep, 0) + 1

        # Daily breakdown
        day = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')
        s['daily'][day] = s['daily'].get(day, 0) + 1

        # Status codes
        s['status_codes'][status] = s['status_codes'].get(status, 0) + 1

    return stats


def print_report(stats, user_info=None):
    """Print human-readable report."""
    if user_info:
        print(f"\n{'='*60}")
        print(f"Usage Report for: {user_info[1]}")
        print(f"NWTN Key: {user_info[2][:20]}...")
        print(f"Credits: {user_info[4]}/{user_info[3]} used")
        print(f"RPM Limit: {user_info[5]}")
        trial = user_info[6]
        if trial:
            trial_dt = datetime.fromisoformat(trial)
            status = "ACTIVE" if trial_dt > datetime.now() else "EXPIRED"
            print(f"Trial: {trial_dt.strftime('%Y-%m-%d')} ({status})")
        print(f"Account: {'Active' if user_info[7] else 'Revoked'}")
        print(f"{'='*60}")

    for username, s in stats.items():
        print(f"\n📊 User: {username}")
        print(f"   Total Requests: {s['requests']}")
        print(f"   Total Tokens: {s['total_tokens']:,}")
        print(f"   Total Credits: {s['total_credits']:,}")

        print(f"\n   By Endpoint:")
        for ep, count in sorted(s['endpoints'].items(), key=lambda x: -x[1]):
            print(f"      {ep}: {count}")

        print(f"\n   By Day:")
        for day, count in sorted(s['daily'].items()):
            print(f"      {day}: {count}")

        print(f"\n   Status Codes:")
        for code, count in sorted(s['status_codes'].items()):
            print(f"      {code}: {count}")


def print_json_report(stats, user_info=None):
    """Print JSON report."""
    report = {
        'generated_at': datetime.now().isoformat(),
        'user': None,
        'stats': {}
    }

    if user_info:
        report['user'] = {
            'username': user_info[1],
            'nwtn_key_prefix': user_info[2][:20] + '...',
            'credits_total': user_info[3],
            'credits_used': user_info[4],
            'rpm_limit': user_info[5],
            'trial_ends_at': user_info[6],
            'active': bool(user_info[7])
        }

    for username, s in stats.items():
        report['stats'][username] = s

    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(
        description="Generate weekly usage report",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python report.py
  python report.py --json
  python report.py --user alice
  python report.py --days 30 --json
        """
    )
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--user", help="Filter by username")
    parser.add_argument("--days", type=int, default=7, help="Days to look back (default: 7)")

    args = parser.parse_args()

    # Get database path
    db_path = get_env_var("DB_PATH", str(Path(__file__).parent.parent / "users.db"))

    conn = sqlite3.connect(db_path)
    try:
        user_info = None
        user_id = None

        if args.user:
            user_info = get_user(conn, args.user)
            if not user_info:
                print(f"Error: User '{args.user}' not found", file=sys.stderr)
                sys.exit(1)
            user_id = user_info[0]

        rows = get_usage_stats(conn, user_id, args.days)

        if not rows:
            print("No usage data found for the specified period.")
            if args.json:
                print_json_report({})
            return

        has_username = not args.user
        stats = aggregate_by_user(rows, has_username)

        if args.json:
            print_json_report(stats, user_info)
        else:
            print_report(stats, user_info)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
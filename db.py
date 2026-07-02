"""
db.py
=====
SQLite connection utility for indb.sqlite.
"""

import os
import sqlite3

os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

DB_PATH = os.path.join(os.getcwd(), "indb.sqlite")


def get_db() -> sqlite3.Connection:
    """Return a sqlite3 connection with row_factory = sqlite3.Row."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

from __future__ import annotations
import sqlite3, os, time, yaml, csv, datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DBF  = REPO / "app" / "python" / "engine" / "savings.db"
RULES = REPO / "app" / "rules" / "default.yaml"

def ensure_db():
    DBF.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DBF)
    cur = conn.cursor()
    cur.execute("""
      CREATE TABLE IF NOT EXISTS exceptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT,
        rule TEXT,
        amount REAL,
        description TEXT,
        src_file TEXT,
        status TEXT DEFAULT 'New',
        owner TEXT DEFAULT '',
        created_at TEXT DEFAULT (datetime('now'))
      )
    """)
    conn.commit(); conn.close()

def load_rules():
    with open(RULES, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}

def insert_exception(domain:str, rule:str, amount:float, description:str, src_file:str):
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute("INSERT INTO exceptions(domain,rule,amount,description,src_file) VALUES (?,?,?,?,?)",
                (domain, rule, float(amount or 0), description, src_file))
    conn.commit(); conn.close()

def fetch_kpis():
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute("SELECT COALESCE(SUM(amount),0) FROM exceptions WHERE status IN ('New','Triage')")
    identified = cur.fetchone()[0] or 0
    cur.execute("SELECT COALESCE(SUM(amount),0) FROM exceptions WHERE status='Approved'")
    approved = cur.fetchone()[0] or 0
    cur.execute("SELECT COUNT(*) FROM exceptions WHERE status IN ('New','Triage')")
    open_cnt = cur.fetchone()[0] or 0
    conn.close()
    return identified, approved, open_cnt

def fetch_exceptions(domain:str|None=None, status:str|None=None):
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    q = "SELECT id,domain,rule,amount,description,src_file,status,owner,created_at FROM exceptions WHERE 1=1"
    args=[]
    if domain: q += " AND domain=?"; args.append(domain)
    if status: q += " AND status=?"; args.append(status)
    q += " ORDER BY datetime(created_at) DESC"
    cur.execute(q, args)
    rows = cur.fetchall()
    conn.close()
    return rows

def update_exception(id:int, *, status:str|None=None, owner:str|None=None):
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    if status is not None and owner is not None:
        cur.execute("UPDATE exceptions SET status=?, owner=? WHERE id=?", (status, owner, id))
    elif status is not None:
        cur.execute("UPDATE exceptions SET status=? WHERE id=?", (status, id))
    elif owner is not None:
        cur.execute("UPDATE exceptions SET owner=? WHERE id=?", (owner, id))
    conn.commit(); conn.close()

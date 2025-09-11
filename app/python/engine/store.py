import sqlite3, datetime, hashlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
APP  = REPO / "app"
LOGS = REPO / "_logs"
DBF  = Path(__file__).resolve().parent / "savings.db"
DBF.parent.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)

def _log(msg:str):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOGS / f"operion_{datetime.datetime.now():%Y%m%d}.log","a",encoding="utf-8") as f:
        f.write(f"{ts} ENGINE: {msg}\n")

EXPECTED = {
    "id"         : "INTEGER",
    "domain"     : "TEXT",
    "rule"       : "TEXT",
    "dollar"     : "REAL DEFAULT 0.0",
    "currency"   : "TEXT DEFAULT 'USD'",
    "vendor"     : "TEXT",
    "ref"        : "TEXT",
    "description": "TEXT",
    "file"       : "TEXT",
    "rownum"     : "INTEGER DEFAULT 0",
    "status"     : "TEXT DEFAULT 'New'",
    "owner"      : "TEXT DEFAULT ''",
    "created_at" : "TEXT",
    "updated_at" : "TEXT",
    "sla_due"    : "TEXT",
    "dedup_hash" : "TEXT"
}

SELECT_LIST = "id,domain,rule,dollar,currency,vendor,ref,description,status,owner,created_at,updated_at,sla_due"

def _migrate():
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute("""CREATE TABLE IF NOT EXISTS exceptions(
        id INTEGER PRIMARY KEY AUTOINCREMENT
    )""")
    cur.execute("PRAGMA table_info(exceptions)")
    have = {r[1] for r in cur.fetchall()}
    for col, decl in EXPECTED.items():
        if col not in have:
            cur.execute(f"ALTER TABLE exceptions ADD COLUMN {col} {decl}")
    conn.commit(); conn.close()

def init():
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute("""CREATE TABLE IF NOT EXISTS exceptions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT, rule TEXT, dollar REAL DEFAULT 0.0, currency TEXT DEFAULT 'USD',
        vendor TEXT, ref TEXT, description TEXT,
        file TEXT, rownum INTEGER DEFAULT 0,
        status TEXT DEFAULT 'New', owner TEXT DEFAULT '',
        created_at TEXT, updated_at TEXT, sla_due TEXT,
        dedup_hash TEXT
    )""")
    conn.commit(); conn.close()
    _migrate()

def _hash(*parts):
    return hashlib.sha256(("|".join([str(x) for x in parts])).encode("utf-8")).hexdigest()

def upsert_exc(domain, rule, dollar, currency, vendor, ref, description, file, rownum, sla_days=7):
    init()
    now = datetime.datetime.now()
    sla_due = (now + datetime.timedelta(days=sla_days)).strftime("%Y-%m-%d")
    dh = _hash(domain, rule, vendor, ref, file, rownum, round(float(dollar or 0.0),2))
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    try:
        cur.execute(f"""INSERT OR IGNORE INTO exceptions
        (domain,rule,dollar,currency,vendor,ref,description,file,rownum,created_at,updated_at,sla_due,dedup_hash)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (domain,rule,float(dollar or 0.0),currency or "USD",vendor or "",ref or "",description or "",file or "",int(rownum or 0),
         now.strftime("%Y-%m-%d %H:%M:%S"), now.strftime("%Y-%m-%d %H:%M:%S"), sla_due, dh))
        conn.commit()
    finally:
        conn.close()

def list_exceptions(filters=None):
    init()
    q = f"SELECT {SELECT_LIST} FROM exceptions"
    params = []
    if filters:
        parts=[]
        if "status" in filters: parts.append("status=?"); params.append(filters["status"])
        if "domain" in filters: parts.append("domain=?"); params.append(filters["domain"])
        if parts: q += " WHERE " + " AND ".join(parts)
    q += " ORDER BY datetime(created_at) DESC"
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute(q, params or [])
    rows = cur.fetchall(); conn.close()
    return rows

def kpis():
    init()
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.execute("SELECT COALESCE(SUM(dollar),0) FROM exceptions")
    total = cur.fetchone()[0] or 0
    cur.execute("SELECT COALESCE(SUM(dollar),0) FROM exceptions WHERE status IN ('Approved','Realized')")
    approved = cur.fetchone()[0] or 0
    cur.execute("SELECT COUNT(*) FROM exceptions WHERE status IN ('New','Triage')")
    open_cnt = cur.fetchone()[0] or 0
    conn.close()
    return dict(identified=round(total,2), approved=round(approved,2), open=open_cnt)

def update_status(ids, status):
    init()
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.executemany("UPDATE exceptions SET status=?, updated_at=? WHERE id=?", [(status, now, i) for i in ids])
    conn.commit(); conn.close()

def update_owner(ids, owner):
    init()
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn = sqlite3.connect(DBF); cur = conn.cursor()
    cur.executemany("UPDATE exceptions SET owner=?, updated_at=? WHERE id=?", [(owner, now, i) for i in ids])
    conn.commit(); conn.close()

def export_csv(path):
    init()
    rows = list_exceptions()
    hdr = ["id","domain","rule","dollar","currency","vendor","ref","description","status","owner","created_at","updated_at","sla_due"]
    import csv
    with open(path,"w",newline="",encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(hdr)
        for r in rows: w.writerow(list(r))

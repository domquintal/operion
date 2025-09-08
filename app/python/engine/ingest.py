from __future__ import annotations
from pathlib import Path
from .store import ensure_db, load_rules
from .detectors import detect_legal, detect_hr, detect_transport, detect_accounting

REPO = Path(__file__).resolve().parents[3]
DATA = REPO / "app" / "data"

def run_all():
    ensure_db()
    rules = load_rules()
    # run domain scanners
    for p in (DATA/"invoices"/"in").glob("*.csv"):
        detect_legal(p, rules)
        p.replace(DATA/"invoices"/"processed"/p.name)
    for p in (DATA/"hr"/"in").glob("*.csv"):
        detect_hr(p, rules)
        p.replace(DATA/"hr"/"processed"/p.name)
    for p in (DATA/"transport"/"in").glob("*.csv"):
        detect_transport(p, rules)
        p.replace(DATA/"transport"/"processed"/p.name)
    for p in (DATA/"accounting"/"in").glob("*.csv"):
        detect_accounting(p, rules)
        p.replace(DATA/"accounting"/"processed"/p.name)

if __name__ == "__main__":
    run_all()

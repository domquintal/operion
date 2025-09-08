from __future__ import annotations
import csv, datetime, math
from pathlib import Path
from .store import insert_exception, load_rules

def _read_csv(p:Path):
    with open(p,"r",encoding="utf-8") as f:
        r = csv.DictReader(f)
        return list(r)

def detect_legal(p:Path, rules:dict):
    cfg = rules.get("legal",{})
    cap = float(cfg.get("rate_cap_per_hour", 0))
    kwords = set([k.lower() for k in cfg.get("flag_keywords",[])])
    rows = _read_csv(p)
    seen = {}
    for row in rows:
        inv = row.get("invoice_id","").strip()
        vend = row.get("vendor","").strip()
        date = row.get("invoice_date","")
        amt  = float(row.get("amount",0) or 0)
        rate = float(row.get("rate_per_hour",0) or 0)
        desc = (row.get("line_description","") or "")
        # duplicate check by vendor+inv within window (light)
        key = f"{vend}|{inv}"
        if key in seen:
            insert_exception("legal","duplicate_invoice", amt, f"Duplicate invoice {inv} for {vend}", str(p))
        else:
            seen[key]=date
        # rate cap
        if cap and rate > cap:
            over = (rate - cap) * float(row.get("hours",0) or 0)
            insert_exception("legal","rate_over_cap", max(over,0), f"Rate {rate:.2f} exceeds cap {cap:.2f} on {inv}", str(p))
        # keyword flags
        low = desc.lower()
        if any(k in low for k in kwords):
            insert_exception("legal","flag_keyword", amt*0.15, f"Flag term in desc: '{desc[:48]}'", str(p))

def detect_hr(p:Path, rules:dict):
    cfg = rules.get("hr",{})
    max_daily = float(cfg.get("max_daily_hours", 12))
    wknd_approval = bool(cfg.get("weekend_overtime_requires_approval", True))
    rows = _read_csv(p)
    for row in rows:
        hrs = float(row.get("hours",0) or 0)
        date = row.get("date","")
        emp = row.get("employee_id","")
        approved = (str(row.get("approved","")).lower() in ("true","1","yes","y"))
        # max daily hours
        if hrs > max_daily:
            insert_exception("hr","overtime_over_cap", (hrs - max_daily)*25, f"{emp} logged {hrs}h (> {max_daily}) on {date}", str(p))
        # weekend approval check
        if wknd_approval and date:
            dt = datetime.datetime.fromisoformat(date)
            if dt.weekday() >= 5 and hrs>0 and not approved:
                insert_exception("hr","weekend_unapproved", hrs*20, f"{emp} weekend hours without approval on {date}", str(p))

def detect_transport(p:Path, rules:dict):
    cfg = rules.get("transport",{})
    caps = cfg.get("accessorial_caps",{}) or {}
    fs_max = float(cfg.get("fuel_surcharge_pct_max", 0.35))
    rows = _read_csv(p)
    for row in rows:
        base = float(row.get("base_rate",0) or 0)
        fs   = float(row.get("fuel_surcharge",0) or 0)
        at   = (row.get("accessorial_type","") or "").lower()
        fee  = float(row.get("accessorial_fee",0) or 0)
        # accessorial caps
        if at and at in caps:
            cap = float(caps[at])
            if fee > cap:
                insert_exception("transport","accessorial_over_cap", fee-cap, f"{at} fee {fee:.2f} > cap {cap:.2f}", str(p))
        # fuel surcharge sanity
        if base>0 and fs > fs_max:
            insert_exception("transport","fuel_surcharge_high", (fs - fs_max)*base, f"Fuel surcharge {fs:.2f} exceeds {fs_max:.2f}", str(p))

def detect_accounting(p:Path, rules:dict):
    cfg = rules.get("accounting",{})
    tol = float(cfg.get("duplicate_invoice_amount_tolerance", 1.0))
    rows = _read_csv(p)
    seen = {}
    for row in rows:
        inv = row.get("invoice_id","").strip()
        vend= row.get("vendor","").strip()
        amt = float(row.get("amount",0) or 0)
        key = f"{vend}|{inv}"
        if key in seen:
            if abs(seen[key]-amt) <= tol:
                insert_exception("accounting","duplicate_invoice", amt, f"Duplicate AP {inv} for {vend}", str(p))
        else:
            seen[key]=amt

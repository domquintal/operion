import csv, os, datetime, yaml
from pathlib import Path
from . import store

REPO = Path(__file__).resolve().parents[2]
DATA = REPO / "app" / "data"
RULES= REPO / "app" / "rules" / "default.yaml"

def load_rules():
    try:
        return yaml.safe_load(Path(RULES).read_text(encoding="utf-8"))
    except:
        return {"domains":{}}

def read_csv(p):
    with open(p,"r",encoding="utf-8",newline="") as f:
        for i,row in enumerate(csv.DictReader(f), start=2): # header is row 1
            yield i,row

def ingest_legal(rules):
    dom = rules.get("domains",{}).get("legal",{})
    caps = dom.get("rate_caps_per_role",{})
    dup_tol = float(dom.get("duplicate_tolerance",1.0))
    kw = [k.lower() for k in dom.get("narrative_keywords",[])]
    folder = DATA / "invoices" / "in"
    for fp in folder.glob("*.csv"):
        seen = set()
        for rownum,row in read_csv(fp):
            vendor = row.get("vendor","")
            inv    = row.get("invoice_id","")
            role   = row.get("timekeeper_role","")
            rate   = float(row.get("rate_per_hour") or 0)
            hours  = float(row.get("hours") or 0)
            amt    = float(row.get("amount") or rate*hours)
            desc   = row.get("description","") or ""
            date   = row.get("date","")
            # Rate over cap
            cap = float(caps.get(role, 1e9))
            if rate > cap and hours>0:
                delta = (rate - cap) * hours
                store.upsert_exc("legal","rate_over_cap", delta,"USD",vendor, inv, f"Role={role} rate {rate} > cap {cap} · {hours}h", str(fp), rownum)
            # Duplicates (vendor+invoice_id+date ~ amount±tol)
            key = (vendor.strip().lower(), inv.strip().lower(), date)
            approx = round(amt,2)
            if key in seen:
                store.upsert_exc("legal","duplicate_invoice", approx,"USD",vendor, inv, f"Duplicate candidate (±{dup_tol})", str(fp), rownum)
            seen.add(key)
            # Narrative flags
            low = desc.lower()
            if any(k in low for k in kw):
                store.upsert_exc("legal","narrative_flag", 0,"USD",vendor, inv, f"Keyword hit: {desc[:120]}", str(fp), rownum)
        (DATA / "invoices" / "_processed").mkdir(exist_ok=True)
        fp.rename(DATA / "invoices" / "_processed" / fp.name)

def ingest_hr(rules):
    dom = rules.get("domains",{}).get("hr",{})
    max_daily = float(dom.get("max_daily_hours",8.0))
    wknd_req  = bool(dom.get("weekend_requires_approval",True))
    folder = DATA / "hr" / "in"
    for fp in folder.glob("*.csv"):
        for rownum,row in read_csv(fp):
            emp = row.get("emp_id","")
            date = row.get("date","")
            hrs = float(row.get("hours") or 0)
            approved = (row.get("approved","").strip().lower() in ("y","yes","true","1"))
            # Overtime over cap
            if hrs > max_daily:
                store.upsert_exc("hr","overtime_over_cap", (hrs - max_daily)*1.0, "USD", emp, date, f"{hrs}h > {max_daily}h", str(fp), rownum)
            # Weekend needs approval
            try:
                dt = datetime.datetime.fromisoformat(date)
                if dt.weekday() >= 5 and wknd_req and not approved:
                    store.upsert_exc("hr","weekend_without_approval", 0,"USD", emp, date, "Weekend no approval", str(fp), rownum)
            except:
                pass
        (DATA / "hr" / "_processed").mkdir(exist_ok=True)
        fp.rename(DATA / "hr" / "_processed" / fp.name)

def ingest_transport(rules):
    dom = rules.get("domains",{}).get("transport",{})
    caps = {k.lower(): float(v) for k,v in (dom.get("accessorial_caps",{}) or {}).items()}
    max_fuel = float(dom.get("max_fuel_surcharge_percent", 30))
    folder = DATA / "transport" / "in"
    for fp in folder.glob("*.csv"):
        for rownum,row in read_csv(fp):
            carrier = row.get("carrier","")
            acc_ty  = (row.get("accessorial_type","") or "").lower()
            acc_amt = float(row.get("accessorial_amount") or 0)
            fuelpct = float(row.get("fuel_surcharge_percent") or 0)
            if acc_ty in caps and acc_amt > caps[acc_ty]:
                store.upsert_exc("transport","accessorial_over_cap", acc_amt - caps[acc_ty], "USD", carrier, acc_ty, f"{acc_ty} {acc_amt} > cap {caps[acc_ty]}", str(fp), rownum)
            if fuelpct > max_fuel:
                store.upsert_exc("transport","fuel_surcharge_over_max", 0,"USD", carrier, str(fuelpct), f"Fuel {fuelpct}% > {max_fuel}%", str(fp), rownum)
        (DATA / "transport" / "_processed").mkdir(exist_ok=True)
        fp.rename(DATA / "transport" / "_processed" / fp.name)

def ingest_accounting(rules):
    dom = rules.get("domains",{}).get("accounting",{})
    tol = float(dom.get("duplicate_amount_tolerance",1.0))
    folder = DATA / "accounting" / "in"
    seen = {}
    for fp in folder.glob("*.csv"):
        for rownum,row in read_csv(fp):
            vendor = row.get("vendor","")
            inv    = row.get("invoice_number","")
            date   = row.get("invoice_date","")
            amt    = float(row.get("amount") or 0)
            key = (vendor.strip().lower(), inv.strip().lower(), date)
            if key in seen and abs(seen[key]-amt) <= tol:
                store.upsert_exc("accounting","duplicate_ap_invoice", amt,"USD", vendor, inv, f"Duplicate within ±{tol}", str(fp), rownum)
            else:
                seen[key] = amt
        (DATA / "accounting" / "_processed").mkdir(exist_ok=True)
        fp.rename(DATA / "accounting" / "_processed" / fp.name)

def ingest_all():
    rules = load_rules()
    store.init()
    ingest_legal(rules)
    ingest_hr(rules)
    ingest_transport(rules)
    ingest_accounting(rules)

import csv, os, time, glob, shutil
from pathlib import Path
from decimal import Decimal
from .. import policy

def _dec(x):
    try: return Decimal(str(x).replace(",", "").strip())
    except Exception: return None

def _normrow(row):
    low = { (k or "").strip().lower(): (v or "").strip() for k,v in row.items() }
    def pick(*keys):
        for k in keys:
            if k in low and low[k] != "": return low[k]
        return None
    return pick("invoice_id","invoice","id","number","no"), pick("vendor","supplier","payee","vendor_name"), pick("amount","total","value","subtotal"), pick("method","payment_method","type","paytype"), low

def run(input_dir: str, processed_dir: str, policy_path: str):
    base = Path(input_dir); processed = Path(processed_dir); processed.mkdir(parents=True, exist_ok=True)
    archive = base.parent / "_processed"; archive.mkdir(parents=True, exist_ok=True)
    rules = policy.load_accounting_rules(policy_path, os.environ)

    accepted, flagged, rejected = [], [], []; skipped = 0
    files = sorted(glob.glob(str(base / "*.csv"))); ts = int(time.time())
    for f in files:
        with open(f, "r", encoding="utf-8") as fh:
            r = csv.DictReader(fh)
            for row in r:
                inv_id, vendor, amount_s, method, raw = _normrow(row)
                if vendor is None or amount_s is None or method is None: skipped += 1; continue
                amount = _dec(amount_s) or _dec(0)

                if vendor in (rules.get("vendor_blocklist") or set()):
                    x=dict(raw); x["_decision"]="rejected"; x["_reason"]="vendor.blocklist"; rejected.append(x); continue
                allowed = rules.get("allowed_methods")
                if allowed and method not in allowed:
                    x=dict(raw); x["_decision"]="rejected"; x["_reason"]="payment.method.not_allowed"; rejected.append(x); continue
                limit = rules.get("amount_limit")
                if limit is not None and amount > limit:
                    x=dict(raw); x["_decision"]="flagged"; x["_reason"]=f"amount>{limit}"; flagged.append(x); continue
                x=dict(raw); x["_decision"]="accepted"; x["_reason"]=""; accepted.append(x)
        try: shutil.move(f, archive / (Path(f).stem + f".archived_{ts}.csv"))
        except Exception: pass

    def write_csv(path, rows):
        if not rows: return
        keys = sorted(set().union(*[r.keys() for r in rows]))
        with open(path, "w", encoding="utf-8", newline="") as w:
            wr = csv.DictWriter(w, fieldnames=keys); wr.writeheader(); wr.writerows(rows)

    write_csv(processed / f"accepted_{ts}.csv", accepted)
    write_csv(processed / f"flagged_{ts}.csv",  flagged)
    write_csv(processed / f"rejected_{ts}.csv", rejected)
    total = len(accepted)+len(flagged)+len(rejected)+skipped
    return {"total": total, "accepted": len(accepted), "flagged": len(flagged), "rejected": len(rejected), "skipped": skipped,
            "outputs": {"accepted": str(processed / f"accepted_{ts}.csv"), "flagged": str(processed / f"flagged_{ts}.csv"), "rejected": str(processed / f"rejected_{ts}.csv")}}

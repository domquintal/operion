import csv, time, glob, shutil
from pathlib import Path
from ..policy import load_hr_rules

def run(input_dir: str, processed_dir: str, policy_path: str):
    base = Path(input_dir); processed = Path(processed_dir); processed.mkdir(parents=True, exist_ok=True)
    archive = base.parent / "_processed"; archive.mkdir(parents=True, exist_ok=True)
    rules = load_hr_rules(policy_path)
    tasks = []; ts = int(time.time())
    for f in sorted(glob.glob(str(base / "*.csv"))):
        with open(f, "r", encoding="utf-8") as fh:
            r = csv.DictReader(fh)
            for row in r:
                email = (row.get("email") or row.get("Email") or "").strip()
                role  = (row.get("role")  or row.get("Role")  or "").strip()
                name  = (row.get("name")  or row.get("Name")  or "").strip()
                p = []
                if rules.get("default_slack"): p.append("slack:join")
                if role in rules.get("roles_requiring_hw_approval", set()): p.append("hardware:laptop:approval")
                tasks.append({"newhire": name or email, "email": email, "role": role, "provisions": ";".join(p)})
        try: shutil.move(f, archive / (Path(f).stem + f".archived_{ts}.csv"))
        except Exception: pass
    out = processed / f"onboarding_tasks_{ts}.csv"
    with open(out, "w", encoding="utf-8", newline="") as w:
        wr = csv.DictWriter(w, fieldnames=["newhire","email","role","provisions"]); wr.writeheader(); wr.writerows(tasks)
    return {"total": len(tasks), "accepted": len(tasks), "flagged": 0, "rejected": 0, "outputs": {"tasks": str(out)}}

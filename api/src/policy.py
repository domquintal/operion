import os, re, yaml
from decimal import Decimal
def _dec(x):
    try: return Decimal(str(x).replace(",", "").strip())
    except Exception: return None

def load_accounting_rules(policy_path: str, env: dict):
    rules = {"amount_limit": None, "allowed_methods": None, "vendor_blocklist": set()}
    if not os.path.exists(policy_path): return rules
    with open(policy_path, "r", encoding="utf-8") as f:
        y = yaml.safe_load(f) or {}
    for r in (y.get("rules") or []):
        rid = str(r.get("id",""))
        if rid.startswith("inv.amount.limit"):
            when = str(r.get("when","")); m = re.search(r"(\\d+(?:\\.\\d+)?)", when)
            if m: rules["amount_limit"] = Decimal(m.group(1))
        elif rid.startswith("payment.method.allowed"):
            allow_if = r.get("allow_if")
            if isinstance(allow_if, str):
                m = re.search(r"\\[(.*?)\\]", allow_if)
                if m: rules["allowed_methods"] = [x.strip(" '\"") for x in m.group(1).split(",")]
            elif isinstance(allow_if, list):
                rules["allowed_methods"] = allow_if
        elif rid.startswith("vendor.blocklist"):
            bl = (env.get("VENDOR_BLOCKLIST") or "")
            rules["vendor_blocklist"] = set([v.strip() for v in bl.split(",") if v.strip()])
    return rules

def load_hr_rules(policy_path: str):
    rules = {"allowed_domain": "@example.com", "roles_requiring_hw_approval": {"Engineer","Analyst"}, "default_slack": True}
    if not os.path.exists(policy_path): return rules
    with open(policy_path, "r", encoding="utf-8") as f:
        y = yaml.safe_load(f) or {}
    for r in (y.get("rules") or []):
        rid = str(r.get("id",""))
        if rid.startswith("hr.email.domain.allowed"):
            rules["allowed_domain"] = "@example.com" # simple placeholder
        elif rid.startswith("hr.hardware.request.approval"):
            rules["roles_requiring_hw_approval"] = {"Engineer","Analyst"}
        elif rid.startswith("hr.slack.workspace.default"):
            rules["default_slack"] = True
    return rules

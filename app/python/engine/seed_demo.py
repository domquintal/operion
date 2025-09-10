from engine import store
def seed():
    store.init()
    k = store.kpis()
    # only seed if nothing there
    if (k.get("identified",0) or 0) > 0 or (k.get("open",0) or 0) > 0:
        return 0
    rows = [
        ("legal","rate_over_cap",  850.00,"USD","Firm A","INV-1001","Partner billed 2h @ $875 cap $450", "seed",1),
        ("legal","duplicate_invoice",300.00,"USD","Firm A","INV-1001","Potential duplicate detected",      "seed",2),
        ("hr","overtime_over_cap",  120.00,"USD","E123","2025-09-08","10h logged vs cap 8h",              "seed",3),
        ("transport","fuel_surcharge_over_max", 0,"USD","CarrierX","33.5","Fuel surcharge 33.5% > 28%",  "seed",4),
        ("accounting","duplicate_ap_invoice", 995.99,"USD","VendorZ","AP-9009","Duplicate within ±1.00", "seed",5),
    ]
    for r in rows:
        store.upsert_exc(*r)
    return len(rows)
if __name__ == "__main__":
    print("seeded", seed())

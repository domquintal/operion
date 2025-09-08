from __future__ import annotations
import os, json, time, hashlib, datetime, glob
from pathlib import Path
import tkinter as tk
import psutil
import ttkbootstrap as tb
from ttkbootstrap.constants import *
from ttkbootstrap.widgets import Meter
# engine imports
from engine.store import ensure_db, fetch_kpis, fetch_exceptions, update_exception

REPO = Path(__file__).resolve().parents[2]
APP  = REPO / "app"
PY   = APP / "python"
LOGS = REPO / "_logs"
OUTS = PY   / "outputs"
OUTS.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)

def load_json(p, fallback):
    try: return json.loads(Path(p).read_text(encoding="utf-8"))
    except: return fallback
VERSION = load_json(APP/"version.json", {"version":"0.0.0","build":"NA"})
APPSET  = load_json(APP/"appsettings.json", {"log_retention_days": 30})
SETTINGS_F = PY/"settings.json"
SETTINGS   = load_json(SETTINGS_F, {"last_tab":"Automation","window_size":[1200,740],"pin_enabled":False,"pin_hash":"","last_folder":str(Path.home())})
def save_settings(): SETTINGS_F.write_text(json.dumps(SETTINGS, indent=2), encoding="utf-8")

def tail_logs(n=200):
    files = sorted(LOGS.glob("*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files: return ["No logs yet."]
    last = files[0]
    try:
        with open(last, "r", encoding="utf-8") as f: lines = f.readlines()[-n:]
    except: lines = ["(cannot read log)"]
    return [l.rstrip("\n") for l in lines]

def cleanup_old_logs(days:int):
    cutoff = datetime.datetime.now() - datetime.timedelta(days=days)
    for f in LOGS.glob("*.log"):
        try:
            dt = datetime.datetime.strptime(f.stem.split("_")[-1], "%Y%m%d")
            if dt < cutoff: f.unlink()
        except: pass
cleanup_old_logs(int(APPSET.get("log_retention_days",30)))

class App(tb.Window):
    def __init__(self):
        super().__init__(title=f"Operion — v{VERSION.get('version')} • build {VERSION.get('build')}",
                         themename="darkly",
                         size=SETTINGS.get("window_size", [1200,740]))
        self.place_window_center()
        self._style = tb.Style()
        ensure_db()

        self.columnconfigure(0, minsize=220)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        self._build_nav()
        self._build_pages()
        self._switch(SETTINGS.get("last_tab","Savings"))

        self._build_status()
        self.after(800, self._tick_status)

    # =========== NAV ===========
    def _build_nav(self):
        nav = tb.Frame(self, padding=10); nav.grid(row=0, column=0, sticky="nswe")
        tb.Label(nav, text="OPERION", font=("Segoe UI", 20, "bold")).pack(anchor="w", pady=(0,6))
        tb.Label(nav, text="Automation • Intelligence • Security", bootstyle="secondary").pack(anchor="w", pady=(0,12))
        def btn(txt, page): return tb.Button(nav, text=txt, bootstyle="info-outline", width=22, command=lambda: self._switch(page))
        self.btn_sav = btn("💸 Savings", "Savings"); self.btn_sav.pack(pady=4, anchor="w")
        self.btn_auto= btn("⚙  Automation", "Automation"); self.btn_auto.pack(pady=4, anchor="w")
        self.btn_ana = btn("📊 Analytics",  "Analytics");  self.btn_ana.pack(pady=4, anchor="w")
        self.btn_sec = btn("🔐 Security",   "Security");   self.btn_sec.pack(pady=4, anchor="w")
        self.btn_abt = btn("ℹ  About",      "About");      self.btn_abt.pack(pady=4, anchor="w")
        tb.Separator(nav).pack(fill="x", pady=10)
        tb.Button(nav, text="📥 Ingest Now", bootstyle="secondary", command=self._ingest_now).pack(anchor="w", pady=2)
        tb.Button(nav, text="📂 Open Outputs", bootstyle="secondary", command=lambda: os.startfile(str(OUTS))).pack(anchor="w", pady=2)
        tb.Button(nav, text="📜 Open Logs",    bootstyle="secondary", command=lambda: os.startfile(str(LOGS))).pack(anchor="w", pady=2)

    # =========== PAGES STACK ===========
    def _build_pages(self):
        self.stack = tb.Frame(self, padding=10); self.stack.grid(row=0, column=1, sticky="nsew")
        self.stack.rowconfigure(0, weight=1); self.stack.columnconfigure(0, weight=1)
        self.pages = {}
        self.pages["Savings"]    = self._page_savings(self.stack)
        self.pages["Automation"] = self._page_automation(self.stack)
        self.pages["Analytics"]  = self._page_analytics(self.stack)
        self.pages["Security"]   = self._page_security(self.stack)
        self.pages["About"]      = self._page_about(self.stack)

    def _switch(self, name):
        for p in self.pages.values(): p.grid_remove()
        self.pages[name].grid(row=0, column=0, sticky="nsew")
        SETTINGS["last_tab"] = name

    # ---------- Savings page ----------
    def _page_savings(self, parent):
        page = tb.Frame(parent)
        # KPI cards
        row = tb.Frame(page); row.pack(fill="x", pady=(0,8))
        def card(title):
            f = tb.Labelframe(row, text=title, bootstyle="primary"); f.pack(side="left", expand=True, fill="x", padx=5)
            lbl = tb.Label(f, text="—", font=("Segoe UI", 18, "bold")); lbl.pack(anchor="w", padx=8, pady=8)
            return lbl
        self.kpi_ident = card("Identified (New+Triage)")
        self.kpi_appr  = card("Approved")
        self.kpi_open  = card("Open Exceptions")

        # Filters
        filt = tb.Frame(page); filt.pack(fill="x", pady=(6,4))
        tb.Label(filt, text="Domain").pack(side="left")
        self.cmb_domain = tb.Combobox(filt, values=["","legal","hr","transport","accounting"], width=14); self.cmb_domain.pack(side="left", padx=6)
        tb.Label(filt, text="Status").pack(side="left")
        self.cmb_status = tb.Combobox(filt, values=["","New","Triage","Approved","Realized","Dismissed"], width=14); self.cmb_status.pack(side="left", padx=6)
        tb.Button(filt, text="Refresh", command=self._refresh_savings).pack(side="left", padx=6)
        tb.Button(filt, text="Export CSV", command=self._export_savings).pack(side="left")

        # Table
        cols = ("id","domain","rule","amount","description","src_file","status","owner","created_at")
        self.tree = tb.Treeview(page, columns=cols, show="headings", height=16)
        for c in cols:
            self.tree.heading(c, text=c)
            self.tree.column(c, width=120 if c!="description" else 360, anchor="w")
        self.tree.pack(fill="both", expand=True, pady=(6,4))

        # Actions
        act = tb.Frame(page); act.pack(fill="x")
        tb.Button(act, text="Set → Triage",   command=lambda: self._set_status("Triage")).pack(side="left", padx=3)
        tb.Button(act, text="Set → Approved", command=lambda: self._set_status("Approved")).pack(side="left", padx=3)
        tb.Button(act, text="Set → Realized", command=lambda: self._set_status("Realized")).pack(side="left", padx=3)
        tb.Button(act, text="Set → Dismissed",command=lambda: self._set_status("Dismissed")).pack(side="left", padx=3)
        tb.Label(act, text="Owner:").pack(side="left", padx=(12,3))
        self.ent_owner = tb.Entry(act, width=18); self.ent_owner.pack(side="left")
        tb.Button(act, text="Assign Owner", command=self._assign_owner).pack(side="left", padx=3)

        self._refresh_kpis(); self._refresh_savings()
        return page

    def _refresh_kpis(self):
        ident, appr, open_cnt = fetch_kpis()
        self.kpi_ident.config(text=f"${ident:,.2f}")
        self.kpi_appr.config(text=f"${appr:,.2f}")
        self.kpi_open.config(text=str(open_cnt))

    def _refresh_savings(self):
        for i in self.tree.get_children(): self.tree.delete(i)
        domain = (self.cmb_domain.get() or "").strip() or None
        status = (self.cmb_status.get() or "").strip() or None
        rows = fetch_exceptions(domain, status)
        for r in rows: self.tree.insert("", "end", values=r)
        self._refresh_kpis()

    def _set_status(self, status):
        sel = self.tree.selection()
        for iid in sel:
            rid = int(self.tree.item(iid)["values"][0])
            update_exception(rid, status=status)
        self._refresh_savings()

    def _assign_owner(self):
        owner = self.ent_owner.get().strip()
        if not owner: return
        sel = self.tree.selection()
        for iid in sel:
            rid = int(self.tree.item(iid)["values"][0])
            update_exception(rid, owner=owner)
        self._refresh_savings()

    def _export_savings(self):
        out = PY / f"savings_{datetime.datetime.now():%Y%m%d_%H%M%S}.csv"
        import csv
        rows = [self.tree.item(i)["values"] for i in self.tree.get_children()]
        with open(out,"w",encoding="utf-8",newline="") as f:
            w = csv.writer(f); w.writerow(("id","domain","rule","amount","description","src_file","status","owner","created_at"))
            for r in rows: w.writerow(r)
        tb.dialogs.Messagebox.show_info(f"Exported:\n{out}")

    def _ingest_now(self):
        # run detectors batch
        import subprocess, sys
        here = Path(__file__).parent
        p = subprocess.Popen([sys.executable, str(here/"engine"/"ingest.py")], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate(timeout=120)
        self._refresh_savings()
        if p.returncode==0:
            tb.dialogs.Messagebox.show_info("Ingestion completed.")
        else:
            tb.dialogs.Messagebox.show_error(f"Ingestion error:\n{stderr.decode('utf-8','ignore')}")

    # ---------- Automation / Analytics / Security / About (kept minimal from previous build) ----------
    def _page_automation(self, parent):
        page = tb.Frame(parent)
        self.txt_auto = tb.Text(page, height=18, wrap="word"); self.txt_auto.pack(fill="both", expand=True)
        self._append_auto("\n".join(tail_logs()))
        return page

    def _page_analytics(self, parent):
        page = tb.Frame(parent)
        meters = tb.Frame(page); meters.pack(fill="x", pady=6)
        self.m_cpu = Meter(meters, metersize=160, padding=10, amountused=0, stepsize=1, subtext="CPU", bootstyle="warning")
        self.m_mem = Meter(meters, metersize=160, padding=10, amountused=0, stepsize=1, subtext="MEM", bootstyle="info")
        self.m_cpu.pack(side="left", padx=6); self.m_mem.pack(side="left", padx=6)
        self.txt_ana = tb.Text(page, height=16, wrap="word"); self.txt_ana.pack(fill="both", expand=True)
        self._append_ana("Analytics live. Use Savings to review cost exceptions.")
        return page

    def _page_security(self, parent):
        page = tb.Frame(parent)
        self._append_stub(page, "Security module unchanged (lockout simulation lives in PSG app).")
        return page

    def _page_about(self, parent):
        page = tb.Frame(parent)
        tb.Label(page, text="OPERION", font=("Segoe UI", 24, "bold")).pack(anchor="w", pady=(0,6))
        tb.Label(page, text=f"Version v{VERSION.get('version')} • build {VERSION.get('build')}", bootstyle="secondary").pack(anchor="w", pady=(4,10))
        tb.Label(page, text="Savings engine identifies cost exceptions across Legal, HR, Transport, and Accounting.\nDrop CSVs into app/data/*/in and press 'Ingest Now'.").pack(anchor="w")
        return page

    # ---------- Status ----------
    def _build_status(self):
        sep = tb.Separator(self, orient="horizontal"); sep.grid(row=1, column=0, columnspan=2, sticky="we")
        bar = tb.Frame(self, padding=(10,6)); bar.grid(row=2, column=0, columnspan=2, sticky="we")
        self.lbl_status = tb.Label(bar, text="Ready."); self.lbl_status.pack(side="left")
        self.lbl_sys    = tb.Label(bar, text="", bootstyle="secondary"); self.lbl_sys.pack(side="right")

    def _tick_status(self):
        cpu = psutil.cpu_percent(interval=None)
        mem = psutil.virtual_memory().percent
        self.lbl_sys.config(text=f"CPU {cpu:.0f}%  •  MEM {mem:.0f}%")
        if "Analytics" in self.pages and self.pages["Analytics"].winfo_ismapped():
            self.m_cpu.configure(amountused=int(cpu)); self.m_mem.configure(amountused=int(mem))
        self.after(1200, self._tick_status)

    # ---------- Helpers ----------
    def _append_auto(self, text): self._append(self.txt_auto, text)
    def _append_ana(self,  text): self._append(self.txt_ana,  text)
    def _append_stub(self, parent, text):
        box = tb.Text(parent, height=18, wrap="word"); box.pack(fill="both", expand=True); self._append(box, text)
    def _append(self, widget, text):
        widget.configure(state="normal"); widget.insert("end", (text+"\n") if not text.endswith("\n") else text)
        widget.see("end"); widget.configure(state="disabled")

    def on_close(self):
        try:
            SETTINGS["last_tab"] = SETTINGS.get("last_tab","Savings")
            SETTINGS["window_size"] = [self.winfo_width(), self.winfo_height()]
            save_settings()
        except: pass
        self.destroy()

if __name__ == "__main__":
    app = App()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()

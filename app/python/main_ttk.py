"""
Operion Next-Gen UI (Tk/ttkbootstrap)
- Side navigation (Automation / Analytics / Security / About)
- Stat cards
- Radial meters (CPU / Memory) + live status line
- Dark theme, rounded widgets
Keeps the same behavior: workflow, logs, retention, lockout rule, report export, persistence.
"""

import os, json, time, hashlib, datetime, glob, threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox

import psutil
import ttkbootstrap as tb
from ttkbootstrap.constants import *
from ttkbootstrap.widgets import Meter

# ------------ Paths / settings ------------
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
SETTINGS   = load_json(SETTINGS_F, {
    "last_tab":"Automation","window_size":[1200,740],
    "pin_enabled":False,"pin_hash":"","last_folder":str(Path.home())
})
def save_settings(): SETTINGS_F.write_text(json.dumps(SETTINGS, indent=2), encoding="utf-8")

# ------------ Logs / analytics helpers ------------
def log_line(tag, msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    fname = LOGS / f"operion_{datetime.datetime.now():%Y%m%d}.log"
    with open(fname, "a", encoding="utf-8") as f:
        f.write(f"{ts} {tag}: {msg}\n")

def cleanup_old_logs(days:int):
    cutoff = datetime.datetime.now() - datetime.timedelta(days=days)
    for f in LOGS.glob("*.log"):
        try:
            dt = datetime.datetime.strptime(f.stem.split("_")[-1], "%Y%m%d")
            if dt < cutoff: f.unlink()
        except: pass
cleanup_old_logs(int(APPSET.get("log_retention_days",30)))

def tail_logs(n=200):
    files = sorted(LOGS.glob("*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files: return ["No logs yet."]
    last = files[0]
    try:
        with open(last, "r", encoding="utf-8") as f: lines = f.readlines()[-n:]
    except: lines = ["(cannot read log)"]
    return [l.rstrip("\n") for l in lines]

def errors_last_24h():
    now = datetime.datetime.now(); count = 0
    for f in LOGS.glob("operion_*.log"):
        try:
            for line in open(f, "r", encoding="utf-8"):
                if len(line) >= 19 and line[:4].isdigit():
                    try: ts = datetime.datetime.strptime(line[:19], "%Y-%m-%d %H:%M:%S")
                    except: continue
                    if now - ts <= datetime.timedelta(hours=24) and "ERROR" in line:
                        count += 1
        except: pass
    return count

def processed_today():
    today = datetime.datetime.now().strftime("%Y%m%d")
    f = LOGS / f"operion_{today}.log"
    c = 0
    if f.exists():
        for line in open(f, "r", encoding="utf-8"):
            if "PROCESSED" in line: c += 1
    return c

def latest_event():
    lines = tail_logs(1)
    return lines[0] if lines else "No logs yet."

def counts_by_day():
    counts = {}
    for f in LOGS.glob("operion_*.log"):
        day = f.stem.split("_")[-1]
        try:
            c = 0
            for line in open(f, "r", encoding="utf-8"):
                if "PROCESSED" in line: c += 1
            counts[day] = counts.get(day, 0) + c
        except: pass
    return dict(sorted(counts.items()))

def sparkline(nums):
    if not nums: return ""
    blocks = "▁▂▃▄▅▆▇█"
    lo, hi = min(nums), max(nums)
    if hi == lo: return blocks[0] * len(nums)
    out = []
    for x in nums:
        idx = int((x - lo) / (hi - lo) * (len(blocks)-1) + 1e-6)
        out.append(blocks[idx])
    return "".join(out)

# ------------ Security ------------
FAIL_WINDOW = datetime.timedelta(minutes=15)
FAIL_LIMIT  = 10
fail_attempts = []
locked_until = None

def record_login(success:bool):
    global fail_attempts, locked_until
    now = datetime.datetime.now()
    if success:
        log_line("SECURITY","login ok"); return "Login success."
    fail_attempts.append(now)
    fail_attempts[:] = [t for t in fail_attempts if now - t <= FAIL_WINDOW]
    log_line("SECURITY","login fail")
    if len(fail_attempts) >= FAIL_LIMIT:
        locked_until = now + FAIL_WINDOW
        log_line("SECURITY","LOCKOUT triggered")
        return f"LOCKOUT: too many failures. Locked until {locked_until.strftime('%H:%M:%S')}"
    return f"Failures last 15m: {len(fail_attempts)}/{FAIL_LIMIT}"

def security_status():
    now = datetime.datetime.now()
    if locked_until and now < locked_until: return f"LOCKED until {locked_until.strftime('%H:%M:%S')}"
    return "OK"

# ------------ UI ------------
class App(tb.Window):
    def __init__(self):
        super().__init__(title=f"Operion — v{VERSION.get('version')} • build {VERSION.get('build')}",
                         themename="darkly",  # try "cyborg", "superhero", "vapor"
                         size=SETTINGS.get("window_size", [1200,740]))
        self.place_window_center()
        self.style = tb.Style()

        # Root layout: left nav + right content
        self.columnconfigure(0, minsize=220)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        self._build_nav()
        self._build_pages()
        self._switch(SETTINGS.get("last_tab","Automation"))

        # Status / meters
        self._build_status()
        self.after(800, self._tick_status)

        log_line("INFO","Dashboard started")

    # ---------- left navigation ----------
    def _build_nav(self):
        nav = tb.Frame(self, padding=10)
        nav.grid(row=0, column=0, sticky="nswe")
        tb.Label(nav, text="OPERION", font=("Segoe UI", 20, "bold")).pack(anchor="w", pady=(0,6))
        tb.Label(nav, text="Automation • Intelligence • Security", bootstyle="secondary").pack(anchor="w", pady=(0,12))

        def btn(txt, page):
            return tb.Button(nav, text=txt, bootstyle="info-outline", width=22,
                             command=lambda: self._switch(page))

        self.btn_auto = btn("⚙  Automation", "Automation"); self.btn_auto.pack(pady=4, anchor="w")
        self.btn_ana  = btn("📊 Analytics",  "Analytics");  self.btn_ana.pack(pady=4, anchor="w")
        self.btn_sec  = btn("🔐 Security",   "Security");   self.btn_sec.pack(pady=4, anchor="w")
        self.btn_abt  = btn("ℹ  About",      "About");      self.btn_abt.pack(pady=4, anchor="w")

        tb.Separator(nav).pack(fill="x", pady=10)
        tb.Button(nav, text="⚙ Settings", bootstyle="secondary", command=self._open_settings).pack(anchor="w", pady=2)
        tb.Button(nav, text="📂 Open Outputs", bootstyle="secondary", command=lambda: os.startfile(str(OUTS))).pack(anchor="w", pady=2)
        tb.Button(nav, text="📜 Open Logs", bootstyle="secondary", command=lambda: os.startfile(str(LOGS))).pack(anchor="w", pady=2)

    # ---------- right content (stacked pages) ----------
    def _build_pages(self):
        self.stack = tb.Frame(self, padding=10)
        self.stack.grid(row=0, column=1, sticky="nsew")
        for i in range(3): self.stack.rowconfigure(i, weight=0)
        self.stack.rowconfigure(3, weight=1)
        self.stack.columnconfigure(0, weight=1)

        self.pages = {}
        self.pages["Automation"] = self._page_automation(self.stack)
        self.pages["Analytics"]  = self._page_analytics(self.stack)
        self.pages["Security"]   = self._page_security(self.stack)
        self.pages["About"]      = self._page_about(self.stack)

    def _switch(self, name):
        for p in self.pages.values(): p.grid_remove()
        self.pages[name].grid(row=0, column=0, sticky="nsew")
        SETTINGS["last_tab"] = name

    # ---------- page: Automation ----------
    def _card_row(self, parent):
        row = tb.Frame(parent); row.pack(fill="x", pady=(0,10))
        def card(title, key):
            f = tb.Labelframe(row, text=title, bootstyle="primary")
            f.pack(side="left", expand=True, fill="x", padx=5)
            lbl = tb.Label(f, text="—", font=("Segoe UI", 18, "bold"))
            lbl.pack(anchor="w", padx=8, pady=8)
            return lbl
        self.lbl_proc = card("Processed today", "proc")
        self.lbl_err  = card("Errors (24h)", "err")
        self.lbl_last = card("Latest event", "last")

    def _page_automation(self, parent):
        page = tb.Frame(parent)

        self._card_row(page)

        frm = tb.Frame(page); frm.pack(fill="x", pady=6)
        tb.Label(frm, text="Input folder").grid(row=0, column=0, sticky="w")
        self.inp_folder = tb.Entry(frm, width=60)
        self.inp_folder.insert(0, SETTINGS.get("last_folder",""))
        self.inp_folder.grid(row=0, column=1, padx=6, sticky="we")
        tb.Button(frm, text="Browse", command=self._browse_folder).grid(row=0, column=2, padx=2)

        tb.Label(frm, text="File types (glob)").grid(row=1, column=0, sticky="w", pady=(6,0))
        self.inp_glob = tb.Entry(frm, width=30); self.inp_glob.insert(0, "*.txt;*.csv")
        self.inp_glob.grid(row=1, column=1, padx=6, sticky="w", pady=(6,0))
        tb.Button(frm, text="▶ Run Workflow", bootstyle="success", command=self._run_workflow).grid(row=1, column=2, padx=2, pady=(6,0))

        self.pb = tb.Progressbar(page, mode="determinate", maximum=100)
        self.pb.pack(fill="x", pady=(6,6))

        self.txt_auto = tb.Text(page, height=14, wrap="word")
        self.txt_auto.pack(fill="both", expand=True)

        self._refresh_stats()
        self._append_auto("\n".join(tail_logs()))
        return page

    # ---------- page: Analytics ----------
    def _page_analytics(self, parent):
        page = tb.Frame(parent)

        meters = tb.Frame(page); meters.pack(fill="x", pady=6)
        self.m_cpu = Meter(meters, metersize=160, padding=10, amountused=0, stepsize=1,
                           subtext="CPU", bootstyle="warning", interactive=False)
        self.m_mem = Meter(meters, metersize=160, padding=10, amountused=0, stepsize=1,
                           subtext="MEM", bootstyle="info", interactive=False)
        self.m_cpu.pack(side="left", padx=6); self.m_mem.pack(side="left", padx=6)

        tb.Button(page, text="📈 Refresh Analytics", command=self._refresh_analytics).pack(anchor="w", pady=6)
        self.txt_ana = tb.Text(page, height=18, wrap="word"); self.txt_ana.pack(fill="both", expand=True)

        self._refresh_analytics()
        return page

    # ---------- page: Security ----------
    def _page_security(self, parent):
        page = tb.Frame(parent)
        row = tb.Frame(page); row.pack(fill="x", pady=6)
        tb.Label(row, text="Status:").pack(side="left")
        self.lbl_sec = tb.Label(row, text=security_status(), bootstyle="warning")
        self.lbl_sec.pack(side="left", padx=6)

        btns = tb.Frame(page); btns.pack(fill="x", pady=4)
        tb.Button(btns, text="✅ Login success", command=self._sec_ok).pack(side="left", padx=3)
        tb.Button(btns, text="⛔ Login failure", command=self._sec_fail).pack(side="left", padx=3)

        pinf = tb.Labelframe(page, text="PIN gate (planned)", bootstyle="secondary")
        pinf.pack(fill="x", pady=6)
        self.chk_pin = tb.Checkbutton(pinf, text="Enable PIN", bootstyle="round-toggle",
                                      variable=tk.BooleanVar(value=SETTINGS.get("pin_enabled", False)))
        self.chk_pin.pack(side="left", padx=6, pady=6)
        self.ent_pin = tb.Entry(pinf, show="*", width=12); self.ent_pin.pack(side="left", padx=6)
        tb.Button(pinf, text="Set PIN", command=self._set_pin).pack(side="left", padx=3)

        self.txt_sec = tb.Text(page, height=16, wrap="word"); self.txt_sec.pack(fill="both", expand=True)
        self._append_sec("\n".join(tail_logs()))
        return page

    # ---------- page: About ----------
    def _page_about(self, parent):
        page = tb.Frame(parent)
        tb.Label(page, text="OPERION", font=("Segoe UI", 24, "bold")).pack(anchor="w", pady=(0,6))
        tb.Label(page, text="Automation • Corporate Intelligence • Solutions", bootstyle="secondary").pack(anchor="w")
        tb.Label(page, text=f"Version v{VERSION.get('version')} • build {VERSION.get('build')}", bootstyle="secondary").pack(anchor="w", pady=(4,10))
        tb.Label(page, text="This desktop app centralizes Automation, Analytics and Security.\nUse Automation to process files; Analytics for throughput insights; Security to simulate and test lockout rules.").pack(anchor="w")
        return page

    # ---------- footer / status ----------
    def _build_status(self):
        sep = tb.Separator(self, orient="horizontal"); sep.grid(row=1, column=0, columnspan=2, sticky="we")
        bar = tb.Frame(self, padding=(10,6)); bar.grid(row=2, column=0, columnspan=2, sticky="we")
        self.lbl_status = tb.Label(bar, text="Ready."); self.lbl_status.pack(side="left")
        self.lbl_sys    = tb.Label(bar, text="", bootstyle="secondary"); self.lbl_sys.pack(side="right")

    # ---------- utilities ----------
    def _append_auto(self, text): self._append(self.txt_auto, text)
    def _append_sec(self,  text): self._append(self.txt_sec,  text)
    def _append(self, widget, text):
        widget.configure(state="normal")
        widget.insert("end", (text + "\n") if not text.endswith("\n") else text)
        widget.see("end"); widget.configure(state="disabled")

    def _browse_folder(self):
        folder = filedialog.askdirectory(initialdir=SETTINGS.get("last_folder",""))
        if folder:
            self.inp_folder.delete(0,"end"); self.inp_folder.insert(0, folder)
            SETTINGS["last_folder"] = folder; save_settings()

    def _run_workflow(self):
        folder = self.inp_folder.get().strip()
        pattern = self.inp_glob.get().strip() or "*.txt"
        if not folder or not os.path.isdir(folder):
            messagebox.showerror("Operion","Pick a valid input folder."); return
        files = []
        for mask in pattern.split(";"):
            files.extend(glob.glob(str(Path(folder)/mask.strip())))
        if not files:
            messagebox.showinfo("Operion","No files found for pattern."); return

        self.txt_auto.configure(state="normal"); self.txt_auto.delete("1.0","end"); self.txt_auto.configure(state="disabled")
        self.pb["value"] = 0; self.lbl_status.config(text="Running workflow…")
        total = len(files); step = max(1, int(100/max(1,total)))
        processed_rows = []

        for i,fp in enumerate(files, start=1):
            try:
                name = os.path.basename(fp)
                outp = OUTS / f"processed_{name}"
                if name.lower().endswith(".txt"):
                    txt = Path(fp).read_text(encoding="utf-8", errors="ignore")
                    Path(outp).write_text(txt.upper(), encoding="utf-8")
                else:
                    Path(outp).write_bytes(Path(fp).read_bytes())
                ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self._append_auto(f"PROCESSED: {name}")
                processed_rows.append((ts,"PROCESSED",name))
                log_line("PROCESSED", name)
            except Exception as ex:
                self._append_auto(f"ERROR: {name} :: {ex}")
                log_line("ERROR", f"{name} :: {ex}")
            self.pb["value"] = min(100, int(i*step)); self.update_idletasks()

        # quick export button after run
        def export_report():
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            out = OUTS / f"report_{ts}.csv"
            with open(out,"w",encoding="utf-8") as f:
                f.write("timestamp,action,detail\n")
                for r in processed_rows:
                    f.write(",".join(r) + "\n")
            messagebox.showinfo("Operion", f"Report written:\n{out}")

        tb.Button(self.pages["Automation"], text="🧾 Export Last Report (.csv)", bootstyle="secondary", command=export_report)\
          .pack(anchor="w", pady=(6,2))

        self.lbl_status.config(text="Workflow complete.")
        self._refresh_stats()
        self._refresh_analytics()

    def _refresh_stats(self):
        self.lbl_proc.config(text=str(processed_today()))
        self.lbl_err.config(text=str(errors_last_24h()))
        self.lbl_last.config(text=latest_event())

    def _refresh_analytics(self):
        c = counts_by_day()
        if not c:
            text = "No processed events yet."
        else:
            xs = list(c.keys()); ys = [c[k] for k in xs]
            total = sum(ys); best = max(ys) if ys else 0
            best_day = xs[ys.index(best)] if ys else "-"
            text = "Processed files per day:\n" + "\n".join(f"{x}: {c[x]}" for x in xs)
            text += f"\n\nSparkline: {sparkline(ys)}"
            text += f"\n\nTotal: {total}  •  Best day: {best_day} ({best})"
        self.txt_ana.configure(state="normal"); self.txt_ana.delete("1.0","end"); self.txt_ana.insert("end", text); self.txt_ana.configure(state="disabled")

    def _sec_ok(self):
        messagebox.showinfo("Operion", record_login(True))
        self.lbl_sec.config(text=security_status()); self._append_sec("\n".join(tail_logs())); self._refresh_stats()

    def _sec_fail(self):
        messagebox.showwarning("Operion", record_login(False))
        self.lbl_sec.config(text=security_status()); self._append_sec("\n".join(tail_logs())); self._refresh_stats()

    def _set_pin(self):
        pin_en = bool(self.chk_pin.instate(["selected"]))
        SETTINGS["pin_enabled"] = pin_en
        pin = self.ent_pin.get().strip()
        if pin:
            SETTINGS["pin_hash"] = hashlib.sha256(pin.encode("utf-8")).hexdigest()
        save_settings(); messagebox.showinfo("Operion","PIN settings saved.")

    def _open_settings(self):
        top = tb.Toplevel(self, title="Settings", transient=self, padding=12)
        tb.Label(top, text="Log retention (days)").grid(row=0, column=0, sticky="w")
        ent_ret = tb.Entry(top, width=6); ent_ret.insert(0, str(APPSET.get("log_retention_days",30))); ent_ret.grid(row=0, column=1, sticky="w", padx=6)

        tb.Label(top, text="Default input folder").grid(row=1, column=0, sticky="w", pady=(6,0))
        ent_dir = tb.Entry(top, width=48); ent_dir.insert(0, SETTINGS.get("last_folder","")); ent_dir.grid(row=1, column=1, sticky="we", padx=6, pady=(6,0))
        tb.Button(top, text="Browse", command=lambda: ent_dir.insert(0, filedialog.askdirectory() or "")).grid(row=1, column=2, padx=2, pady=(6,0))

        btns = tb.Frame(top); btns.grid(row=2, column=0, columnspan=3, sticky="e", pady=10)
        tb.Button(btns, text="Cancel", command=top.destroy).pack(side="right", padx=4)
        def save_and_close():
            try:
                days = int(ent_ret.get()); APPSET["log_retention_days"] = max(1, days)
                (APP/"appsettings.json").write_text(json.dumps(APPSET, indent=2), encoding="utf-8")
                cleanup_old_logs(APPSET["log_retention_days"])
            except Exception as ex:
                messagebox.showerror("Operion", f"Invalid days: {ex}"); return
            SETTINGS["last_folder"] = ent_dir.get().strip() or SETTINGS.get("last_folder","")
            save_settings(); messagebox.showinfo("Operion", "Settings saved."); top.destroy()
        tb.Button(btns, text="Save", bootstyle="success", command=save_and_close).pack(side="right", padx=4)

        top.grab_set(); top.wait_window()

    def _tick_status(self):
        cpu = psutil.cpu_percent(interval=None)
        mem = psutil.virtual_memory().percent
        self.lbl_sys.config(text=f"CPU {cpu:.0f}%  •  MEM {mem:.0f}%")
        # update meters if visible
        if "Analytics" in self.pages and self.pages["Analytics"].winfo_ismapped():
            self.m_cpu.configure(amountused=int(cpu))
            self.m_mem.configure(amountused=int(mem))
        self.after(1200, self._tick_status)

    # persist size on close
    def on_close(self):
        try:
            SETTINGS["window_size"] = [self.winfo_width(), self.winfo_height()]
            save_settings()
        except: pass
        self.destroy()

if __name__ == "__main__":
    app = App()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()

"""
Operion Desktop Dashboard — polished UI v1 (PSG5-safe)
Adds: brand header, stat cards, settings dialog, clearer labels, better analytics summary.
"""

import os, json, time, hashlib, datetime, glob
from pathlib import Path

import PySimpleGUI as sg
import psutil

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
    "last_tab":"Automation","window_size":[1080,720],
    "pin_enabled":False,"pin_hash":"","last_folder":str(Path.home())
})

def save_settings():
    SETTINGS_F.write_text(json.dumps(SETTINGS, indent=2), encoding="utf-8")

# ---------- Logs & retention ----------
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
            if dt < cutoff:
                f.unlink()
        except: pass
cleanup_old_logs(int(APPSET.get("log_retention_days",30)))

def tail_logs(n=200):
    files = sorted(LOGS.glob("*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files: return ["No logs yet."]
    last = files[0]
    try:
        with open(last, "r", encoding="utf-8") as f:
            lines = f.readlines()[-n:]
    except:
        lines = ["(cannot read log)"]
    return [l.rstrip("\n") for l in lines]

def errors_last_24h():
    now = datetime.datetime.now()
    count = 0
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

def sys_summary():
    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory().percent
    net = psutil.net_io_counters()
    return f"CPU {cpu:.0f}% | MEM {mem:.0f}% | NET sent {net.bytes_sent//1024//1024}MB recv {net.bytes_recv//1024//1024}MB"

# ---------- Security ----------
FAIL_WINDOW = datetime.timedelta(minutes=15)
FAIL_LIMIT  = 10
fail_attempts = []
locked_until = None

def record_login(success:bool):
    global fail_attempts, locked_until
    now = datetime.datetime.now()
    if success:
        log_line("SECURITY","login ok")
        return "Login success."
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
    if locked_until and now < locked_until:
        return f"LOCKED until {locked_until.strftime('%H:%M:%S')}"
    return "OK"

# PIN (planned)
def verify_pin(pin:str)->bool:
    ph = SETTINGS.get("pin_hash","")
    if not SETTINGS.get("pin_enabled", False): return True
    if not ph: return True
    return hashlib.sha256(pin.encode("utf-8")).hexdigest() == ph

# ---------- UI: Header & Tabs ----------
# Header bar
header = [
    [ sg.Text("OPERION", font=("Segoe UI", 24), text_color="#111827"),
      sg.Text("  —  Automation. Corporate Intelligence. Solutions.", font=("Segoe UI", 11), text_color="#334155"),
      sg.Push(),
      sg.Text(f"v{VERSION.get('version')}  •  build {VERSION.get('build')}", text_color="#475569") ],
    [ sg.HorizontalSeparator() ]
]

# Stat cards (Automation tab)
def stat_cards():
    return [
        [ sg.Frame("", [[sg.Text("Processed today", text_color="#64748B"),
                         sg.Text(str(processed_today()), key="-S-PROC-", font=("Segoe UI", 18), text_color="#111827")]],
                   expand_x=True),
          sg.Frame("", [[sg.Text("Errors (24h)", text_color="#64748B"),
                         sg.Text(str(errors_last_24h()), key="-S-ERR-", font=("Segoe UI", 18), text_color="#111827")]],
                   expand_x=True),
          sg.Frame("", [[sg.Text("Latest event", text_color="#64748B"),
                         sg.Text(latest_event(), key="-S-LATEST-", size=(48,2), text_color="#111827")]],
                   expand_x=True), ],
    ]

auto_layout = [
    *stat_cards(),
    [sg.Text("Automation — run workflows, process files, auto-generate outputs")],
    [sg.Text("Input folder:"), sg.Input(SETTINGS.get("last_folder",""), key="-IN-FOLDER-", enable_events=True), sg.FolderBrowse("Browse")],
    [sg.Text("File types:"),   sg.Input("*.txt;*.csv", key="-GLOB-"), sg.Button("▶ Run Workflow", key="-RUN-")],
    [sg.Button("📂 Open Outputs"), sg.Button("🧾 Export Report (.csv)"), sg.Button("⚙ Settings", key="-SETTINGS-"),
     sg.ProgressBar(100, orientation="h", size=(40,20), key="-P-")],
    [sg.Multiline(size=(110,12), key="-AUTO-LOG-", autoscroll=True, disabled=True)]
]

ana_layout = [
    [sg.Text("Analytics — throughput & performance")],
    [sg.Button("📈 Refresh Analytics", key="-REFRESH-"), sg.Button("📜 Open Logs", key="-OPEN-LOGS-")],
    [sg.Multiline(size=(110,14), key="-ANA-", autoscroll=True, disabled=True)],
    [sg.Text("System:"), sg.Text("", key="-SYS-")]
]

sec_layout = [
    [sg.Text("Security — login attempts, policy events, lockout rule (10 fails / 15 min)")],
    [sg.Text("Status:"), sg.Text(security_status(), key="-SEC-STATE-", text_color="darkorange")],
    [sg.Button("✅ Simulate Login Success"), sg.Button("⛔ Simulate Login Failure")],
    [sg.Checkbox("Enable PIN gate (planned)", key="-PIN-EN-", default=SETTINGS.get("pin_enabled", False)),
     sg.Input(password_char="*", key="-PIN-VAL-", size=(12,1)), sg.Button("Set PIN")],
    [sg.Multiline(size=(110,12), key="-SEC-LOG-", autoscroll=True, disabled=True)]
]

abt_layout = [
    [sg.Text("This desktop app provides Automation / Analytics / Security in one place.")],
    [sg.Text("Use Run Workflow to process files; Security to simulate lockout; Analytics to view throughput trends.")],
]

tabs = [
    [sg.TabGroup([[ sg.Tab("⚙ Automation", auto_layout, key="-TAB-AUTO-"),
                    sg.Tab("📊 Analytics",  ana_layout,  key="-TAB-ANA-"),
                    sg.Tab("🔐 Security",   sec_layout,  key="-TAB-SEC-"),
                    sg.Tab("ℹ About/Help", abt_layout,  key="-TAB-ABT-") ]],
                 key="-TABS-", tab_location="top")],
]

layout = [*header, *tabs, [sg.StatusBar("Operion ready.", key="-STATUS-")]]

# ---------- Window ----------
size = tuple(SETTINGS.get("window_size", [1080,720]))
window = sg.Window("Operion — Dashboard", layout, size=size, finalize=True)

# Restore last tab
tab_map = ["⚙ Automation","📊 Analytics","🔐 Security","ℹ About/Help"]
try:
    idx = tab_map.index(SETTINGS.get("last_tab","⚙ Automation"))
    window["-TABS-"].SelectTab(idx)
except: 
    try: window["-TABS-"].SelectTab(0)
    except: pass

# ---------- Initial population ----------
log_line("INFO","Dashboard started")
window["-AUTO-LOG-"].update("\n".join(tail_logs()))
window["-SEC-LOG-"].update("\n".join(tail_logs()))
window["-SYS-"].update(sys_summary())
window["-STATUS-"].update("Operion running.  Press ▶ Run Workflow to start.")

def refresh_analytics():
    c = counts_by_day()
    if not c:
        text = "No processed events yet."
    else:
        xs = list(c.keys())
        ys = [c[k] for k in xs]
        total = sum(ys)
        best = max(ys) if ys else 0
        best_day = xs[ys.index(best)] if ys else "-"
        text =  "Processed files per day:\n" + "\n".join(f"{x}: {c[x]}" for x in xs)
        text += f"\n\nSparkline: {sparkline(ys)}"
        text += f"\n\nTotal: {total}  •  Best day: {best_day} ({best})"
    window["-ANA-"].update(text)

def refresh_stats_row():
    window["-S-PROC-"].update(str(processed_today()))
    window["-S-ERR-"].update(str(errors_last_24h()))
    window["-S-LATEST-"].update(latest_event())

refresh_analytics()
refresh_stats_row()

processed_rows = []  # (ts, "PROCESSED", filename)
last_sys = time.time()

# ---------- Settings modal ----------
def open_settings_modal():
    layout = [
        [sg.Text("Log retention (days)"), sg.Input(str(APPSET.get("log_retention_days",30)), key="-SET-RET-", size=(6,1))],
        [sg.Text("Default input folder"), sg.Input(SETTINGS.get("last_folder",""), key="-SET-FOLDER-"), sg.FolderBrowse("Browse")],
        [sg.Text("PIN (optional)"), sg.Input(password_char="*", key="-SET-PIN-", size=(12,1)),
         sg.Checkbox("Enable PIN gate", key="-SET-PIN-EN-", default=SETTINGS.get("pin_enabled", False))],
        [sg.Push(), sg.Button("Save"), sg.Button("Cancel")]
    ]
    win = sg.Window("Settings", layout, modal=True, finalize=True)
    while True:
        ev, vals = win.read()
        if ev in (sg.WIN_CLOSED, "Cancel"): break
        if ev == "Save":
            # retention
            try:
                days = int(vals["-SET-RET-"])
                APPSET["log_retention_days"] = max(1, days)
                (APP/"appsettings.json").write_text(json.dumps(APPSET, indent=2), encoding="utf-8")
                cleanup_old_logs(APPSET["log_retention_days"])
            except Exception as ex:
                sg.popup_error(f"Invalid retention days: {ex}"); continue
            # folder
            SETTINGS["last_folder"] = vals["-SET-FOLDER-"].strip() or SETTINGS.get("last_folder","")
            # pin
            pin = vals.get("-SET-PIN-","")
            SETTINGS["pin_enabled"] = bool(vals.get("-SET-PIN-EN-", False))
            SETTINGS["pin_hash"] = hashlib.sha256(pin.encode("utf-8")).hexdigest() if pin else SETTINGS.get("pin_hash","")
            save_settings()
            sg.popup_ok("Settings saved.")
            break
    win.close()

# ---------- Event loop ----------
while True:
    ev, vals = window.read(timeout=750)
    if ev in (sg.WIN_CLOSED, "Exit"): break

    if time.time() - last_sys > 1.5:
        window["-SYS-"].update(sys_summary()); last_sys = time.time()

    # Track active tab for persistence (by title text)
    try:
        idx = window["-TABS-"].TabGroupSelectedTabIndex(window["-TABS-"])
        SETTINGS["last_tab"] = tab_map[idx]
    except: pass

    if ev == "-IN-FOLDER-":
        SETTINGS["last_folder"] = vals["-IN-FOLDER-"]

    if ev == "📂 Open Outputs":
        os.startfile(str(OUTS))

    if ev == "📜 Open Logs":
        os.startfile(str(LOGS))

    if ev == "🧾 Export Report (.csv)":
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        out = OUTS / f"report_{ts}.csv"
        rows = processed_rows.copy()
        if not rows:
            today = LOGS / f"operion_{datetime.datetime.now():%Y%m%d}.log"
            if today.exists():
                for line in open(today, "r", encoding="utf-8"):
                    if "PROCESSED" in line:
                        parts = line.strip().split(" ", 2)
                        if len(parts)>=2:
                            rows.append((parts[0]+" "+parts[1],"PROCESSED", line.strip().split("PROCESSED:",1)[-1].strip()))
        with open(out, "w", encoding="utf-8") as f:
            f.write("timestamp,action,detail\n")
            for ts, action, detail in rows:
                f.write(f"{ts},{action},{detail}\n")
        sg.popup_ok(f"Report written:\n{out}")

    if ev == "-SETTINGS-":
        open_settings_modal()
        refresh_stats_row()
        refresh_analytics()

    if ev == "📈 Refresh Analytics":
        refresh_analytics()
        refresh_stats_row()

    if ev == "-RUN-":
        folder = vals["-IN-FOLDER-"].strip()
        pattern = vals["-GLOB-"].strip() or "*.txt"
        if not folder or not os.path.isdir(folder):
            sg.popup_error("Pick a valid input folder."); continue
        files = []
        for mask in pattern.split(";"):
            files.extend(glob.glob(str(Path(folder)/mask.strip())))
        if not files:
            sg.popup("No files found for pattern."); continue
        total = len(files); step = max(1, int(100/max(1,total)))
        window["-AUTO-LOG-"].update(""); processed_rows.clear()
        window["-STATUS-"].update("Running workflow…")
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
                window["-AUTO-LOG-"].print(f"PROCESSED: {name}")
                processed_rows.append((ts,"PROCESSED",name))
                log_line("PROCESSED", name)
            except Exception as ex:
                window["-AUTO-LOG-"].print(f"ERROR: {name} :: {ex}")
                log_line("ERROR", f"{name} :: {ex}")
            window["-P-"].update(min(100, int(i*step))); window.refresh()
        log_line("INFO","Workflow complete")
        sg.popup_ok("Workflow complete.")
        window["-STATUS-"].update("Workflow complete.")
        refresh_analytics()
        refresh_stats_row()
        # Persist last folder right away
        SETTINGS["last_folder"] = folder
        save_settings()

    if ev == "✅ Simulate Login Success":
        sg.popup_ok(record_login(True))
        window["-SEC-STATE-"].update(security_status())
        window["-SEC-LOG-"].update("\n".join(tail_logs()))
        refresh_stats_row()
    if ev == "⛔ Simulate Login Failure":
        msg = record_login(False)
        sg.popup(msg)
        window["-SEC-STATE-"].update(security_status())
        window["-SEC-LOG-"].update("\n".join(tail_logs()))
        refresh_stats_row()

# persist window size + settings
try:
    w,h = window.size
    SETTINGS["window_size"] = [w,h]
    save_settings()
except: pass
window.close()

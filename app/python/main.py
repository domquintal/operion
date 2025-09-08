"""
Operion Desktop Dashboard (software-only, PSG5-safe)
Tabs: Automation | Analytics | Security | About/Help
No Matplotlib (analytics shown as text + sparkline). 30-day log retention, state persistence, lockout rule.
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
SETTINGS   = load_json(SETTINGS_F, {"last_tab":"Automation","window_size":[1024,720],"pin_enabled":False,"pin_hash":"","last_folder":str(Path.home())})

def save_settings():
    SETTINGS_F.write_text(json.dumps(SETTINGS, indent=2), encoding="utf-8")

# Logging + retention
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

# Security: lockout rule (10 fails / 15 minutes)
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
    if not SETTINGS.get("pin_enabled", False):
        return True
    if not ph:
        return True
    import hashlib
    return hashlib.sha256(pin.encode("utf-8")).hexdigest() == ph

# Try to set a theme (PSG 5 sometimes ships differently). If missing, ignore.
try:
    sg.theme("Dark Blue 3")
except Exception:
    pass

# --- UI layouts (PSG-5 safe set) ---
auto_layout = [
    [sg.Text("Automation — run workflows, process files, auto-generate outputs")],
    [sg.Text("Input folder:"), sg.Input(SETTINGS.get("last_folder",""), key="-IN-FOLDER-", enable_events=True), sg.FolderBrowse()],
    [sg.Text("File types:"),   sg.Input("*.txt;*.csv", key="-GLOB-"), sg.Button("Run Workflow", key="-RUN-")],
    [sg.Button("Open Outputs"), sg.Button("Export Report (.csv)"), sg.ProgressBar(100, orientation="h", size=(40,20), key="-P-")],
    [sg.Multiline(size=(100,12), key="-AUTO-LOG-", autoscroll=True, disabled=True)]
]

ana_layout = [
    [sg.Text("Analytics — throughput & performance")],
    [sg.Button("Refresh Analytics", key="-REFRESH-")],
    [sg.Multiline(size=(100,12), key="-ANA-", autoscroll=True, disabled=True)],
    [sg.Text("System:"), sg.Text("", key="-SYS-")]
]

sec_layout = [
    [sg.Text("Security — login attempts, policy events, lockout rule (10 fails / 15 min)")],
    [sg.Text("Status:"), sg.Text(security_status(), key="-SEC-STATE-", text_color="yellow")],
    [sg.Button("Simulate Login Success"), sg.Button("Simulate Login Failure"), sg.Button("Open Logs Folder")],
    [sg.Checkbox("Enable PIN gate (planned)", key="-PIN-EN-", default=SETTINGS.get("pin_enabled", False)),
     sg.Input(password_char="*", key="-PIN-VAL-", size=(12,1)), sg.Button("Set PIN")],
    [sg.Multiline(size=(100,12), key="-SEC-LOG-", autoscroll=True, disabled=True)]
]

abt_layout = [
    [sg.Text("OPERION", font=("Segoe UI", 24))],
    [sg.Text("Automation. Corporate Intelligence. Solutions.", font=("Segoe UI", 12))],
    [sg.Text(f"Version: v{VERSION.get('version')} · build {VERSION.get('build')}")],
    [sg.Text("This desktop app provides Automation / Analytics / Security in one place.")],
    [sg.HorizontalSeparator()],
    [sg.Text("Tips: Run Workflow to process files; use Security to simulate lockout; Analytics to view throughput trends.")]
]

layout = [
    [sg.TabGroup([[ sg.Tab("Automation", auto_layout, key="-TAB-AUTO-"),
                    sg.Tab("Analytics",  ana_layout,  key="-TAB-ANA-"),
                    sg.Tab("Security",   sec_layout,  key="-TAB-SEC-"),
                    sg.Tab("About/Help", abt_layout,  key="-TAB-ABT-") ]],
                 key="-TABS-", tab_location="top")],
    [sg.StatusBar(f"Operion · v{VERSION.get('version')} · build {VERSION.get('build')}  |  Logs: {APPSET.get('log_retention_days',30)}-day retention")]
]

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

def counts_by_day():
    counts = {}
    for f in LOGS.glob("operion_*.log"):
        day = f.stem.split("_")[-1]
        try:
            c = 0
            for line in open(f, "r", encoding="utf-8"):
                if "PROCESSED" in line:
                    c += 1
            counts[day] = counts.get(day, 0) + c
        except: pass
    return counts

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

def write_csv_report(rows, path):
    with open(path, "w", encoding="utf-8") as f:
        f.write("timestamp,action,detail\n")
        for ts, action, detail in rows:
            f.write(f"{ts},{action},{detail}\n")

size = tuple(SETTINGS.get("window_size", [1024,720]))
window = sg.Window("Operion — Dashboard", layout, size=size, finalize=True)
tabs: sg.TabGroup = window["-TABS-"]

tab_map = ["Automation","Analytics","Security","About/Help"]
try:
    idx = tab_map.index(SETTINGS.get("last_tab","Automation"))
    tabs.SelectTab(idx)
except: 
    try: tabs.SelectTab(0)
    except: pass

log_line("INFO","Dashboard started")
window["-AUTO-LOG-"].update("\n".join(tail_logs()))
window["-SEC-LOG-"].update("\n".join(tail_logs()))
window["-SYS-"].update(sys_summary())

def refresh_analytics():
    c = counts_by_day()
    if not c:
        text = "No processed events yet."
    else:
        xs = sorted(c.keys())
        ys = [c[k] for k in xs]
        text = "Processed files per day:\n" + "\n".join(f"{x}: {c[x]}" for x in xs)
        text += f"\n\nSparkline: {sparkline(ys)}"
    window["-ANA-"].update(text)

refresh_analytics()

processed_rows = []  # (ts, "PROCESSED", filename)
last_sys = time.time()

while True:
    ev, vals = window.read(timeout=750)
    if ev in (sg.WIN_CLOSED, "Exit"):
        break

    if time.time() - last_sys > 1.5:
        window["-SYS-"].update(sys_summary()); last_sys = time.time()

    try:
        idx = tabs.TabGroupSelectedTabIndex(tabs)
        SETTINGS["last_tab"] = tab_map[idx]
    except: pass

    if ev == "-IN-FOLDER-":
        SETTINGS["last_folder"] = vals["-IN-FOLDER-"]

    if ev == "Open Outputs":
        os.startfile(str(OUTS))

    if ev == "Export Report (.csv)":
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
        write_csv_report(rows, out)
        sg.popup_ok(f"Report written:\n{out}")

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
        total = len(files); step = max(1, int(100/total))
        window["-AUTO-LOG-"].update("")
        processed_rows.clear()
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
            window["-P-"].update(min(100, i*step))
            window.refresh()
        sg.popup_ok("Workflow complete.")
        refresh_analytics()

    if ev == "Simulate Login Success":
        sg.popup_ok(record_login(True))
        window["-SEC-STATE-"].update(security_status())
        window["-SEC-LOG-"].update("\n".join(tail_logs()))
    if ev == "Simulate Login Failure":
        msg = record_login(False)
        sg.popup(msg)
        window["-SEC-STATE-"].update(security_status())
        window["-SEC-LOG-"].update("\n".join(tail_logs()))
    if ev == "Open Logs Folder":
        os.startfile(str(LOGS))
    if ev == "-PIN-EN-":
        SETTINGS["pin_enabled"] = bool(vals["-PIN-EN-"])
    if ev == "Set PIN":
        pin = vals.get("-PIN-VAL-","")
        if not pin:
            SETTINGS["pin_hash"] = ""
            SETTINGS["pin_enabled"] = False
            sg.popup_ok("PIN cleared (gate off).")
        else:
            SETTINGS["pin_hash"] = hashlib.sha256(pin.encode("utf-8")).hexdigest()
            SETTINGS["pin_enabled"] = True
            sg.popup_ok("PIN set (gate planned).")

# persist window size + settings
try:
    w,h = window.size
    SETTINGS["window_size"] = [w,h]
    save_settings()
except: pass
window.close()

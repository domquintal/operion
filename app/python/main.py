"""
Operion Desktop Dashboard (software-only)
Tabs: Automation | Analytics | Security | About/Help
Deps: PySimpleGUI 5.x, psutil
Charts: PySimpleGUI Graph (no matplotlib)
"""
import os, sys, json, time, hashlib, datetime, glob
from pathlib import Path
import PySimpleGUI as sg
import psutil

REPO = Path(__file__).resolve().parents[2]
APP  = REPO / "app"
PY   = APP / "python"
LOGS = REPO / "_logs"
OUTS = PY / "outputs"
OUTS.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)

def load_json(p, fallback):
    try: return json.loads(Path(p).read_text(encoding="utf-8"))
    except: return fallback

VERSION = load_json(APP/"version.json", {"version":"0.0.0","build":"NA"})
APPSET  = load_json(APP/"appsettings.json", {"log_retention_days": 30})
SETTINGS_F = PY/"settings.json"
SETTINGS = load_json(SETTINGS_F, {"last_tab":"Automation","window_size":[1024,720],"pin_enabled":False,"pin_hash":"","last_folder":str(Path.home())})

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

def verify_pin(pin:str)->bool:
    ph = SETTINGS.get("pin_hash","")
    if not SETTINGS.get("pin_enabled", False): return True
    if not ph: return True
    import hashlib
    return hashlib.sha256(pin.encode("utf-8")).hexdigest() == ph

# ---------- Analytics helpers (Graph chart) ----------
def processed_counts_by_day():
    counts = {}
    for f in LOGS.glob("operion_*.log"):
        day = f.stem.split("_")[-1]
        try:
            c = 0
            for line in open(f, "r", encoding="utf-8"):
                if "PROCESSED" in line: c += 1
            counts[day] = counts.get(day, 0) + c
        except: pass
    if not counts:
        counts[datetime.datetime.now().strftime("%Y%m%d")] = 0
    xs = sorted(counts.keys())
    ys = [counts[x] for x in xs]
    return xs, ys

CHART_W, CHART_H = 680, 240
PAD_L, PAD_R, PAD_T, PAD_B = 40, 12, 16, 28

def draw_chart(graph: sg.Graph):
    xs, ys = processed_counts_by_day()
    graph.erase()
    # Axes
    graph.draw_line((PAD_L, PAD_B), (CHART_W-PAD_R, PAD_B))       # X axis
    graph.draw_line((PAD_L, PAD_B), (PAD_L, CHART_H-PAD_T))       # Y axis
    if not xs: return
    max_y = max(1, max(ys))
    n = max(1, len(xs)-1)
    plot_w = (CHART_W - PAD_L - PAD_R)
    plot_h = (CHART_H - PAD_T - PAD_B)
    pts = []
    for i,y in enumerate(ys):
        xpix = PAD_L + plot_w * (i / max(1,len(xs)-1))
        ypix = PAD_B + (0 if max_y==0 else (y / max_y) * plot_h)
        pts.append((xpix, ypix))
    # gridlines (quartiles)
    for frac in (0.25,0.5,0.75,1.0):
        y = PAD_B + frac * plot_h
        graph.draw_line((PAD_L, y), (CHART_W-PAD_R, y), color="#334155")
        graph.draw_text(str(round(max_y*frac)), (PAD_L-8, y), color="#9CA3AF", text_location=sg.TEXT_LOCATION_MIDDLE_RIGHT, font=("Segoe UI",8))
    # polyline
    for i in range(1, len(pts)):
        graph.draw_line(pts[i-1], pts[i], color="#60A5FA", width=2)
    for p in pts:
        graph.draw_circle(p, 2, fill_color="#93C5FD", line_color="#93C5FD")
    # first/last x labels
    if xs:
        graph.draw_text(xs[0], (PAD_L, PAD_B-12), color="#9CA3AF", text_location=sg.TEXT_LOCATION_TOP_LEFT, font=("Segoe UI",8))
        graph.draw_text(xs[-1], (CHART_W-PAD_R, PAD_B-12), color="#9CA3AF", text_location=sg.TEXT_LOCATION_TOP_RIGHT, font=("Segoe UI",8))
    graph.draw_text("Processed files per day", (PAD_L, CHART_H-4), color="#E5E7EB", text_location=sg.TEXT_LOCATION_TOP_LEFT, font=("Segoe UI",9,"bold"))

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

# ---------- UI ----------
sg.theme("DarkBlue14")

auto_layout = [
    [sg.Text("Automation — run workflows, process files, auto-generate outputs")],
    [sg.Text("Input folder:"), sg.Input(SETTINGS.get("last_folder",""), key="-IN-FOLDER-", enable_events=True), sg.FolderBrowse()],
    [sg.Text("File types:"), sg.Input("*.txt;*.csv", key="-GLOB-"), sg.Button("Run Workflow", key="-RUN-")],
    [sg.Button("Open Outputs"), sg.Button("Export Report (.csv)"), sg.ProgressBar(100, orientation="h", size=(40,20), key="-P-")],
    [sg.Multiline(size=(100,12), key="-AUTO-LOG-", autoscroll=True, disabled=True)]
]

ana_layout = [
    [sg.Text("Analytics — throughput & performance")],
    [sg.Button("Refresh Analytics", key="-REFRESH-")],
    [sg.Graph(canvas_size=(CHART_W,CHART_H), graph_bottom_left=(0,0), graph_top_right=(CHART_W,CHART_H),
              key="-GRAPH-", background_color="#0B1220")],
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
    [sg.Text("Tips: Run Workflow on a folder of .txt/.csv; Analytics shows processed/day; Security demonstrates lockout.")]
]

layout = [
    [sg.TabGroup([[ sg.Tab("Automation", auto_layout, key="-TAB-AUTO-"),
                    sg.Tab("Analytics",  ana_layout,  key="-TAB-ANA-"),
                    sg.Tab("Security",   sec_layout,  key="-TAB-SEC-"),
                    sg.Tab("About/Help", abt_layout,  key="-TAB-ABT-"), ]],
                 key="-TABS-", selected_title_color="white", tab_location="top")],
    [sg.StatusBar(f"Operion · v{VERSION.get('version')} · build {VERSION.get('build')}  |  Logs: {APPSET.get('log_retention_days',30)}-day retention")]
]

size = tuple(SETTINGS.get("window_size", [1024,720]))
window = sg.Window("Operion — Dashboard", layout, size=size, finalize=True)
tabs: sg.TabGroup = window["-TABS-"]

# restore tab
tab_map = ["Automation","Analytics","Security","About/Help"]
try:
    idx = tab_map.index(SETTINGS.get("last_tab","Automation")); tabs.SelectTab(idx)
except: tabs.SelectTab(0)

# initial population
log_line("INFO","Dashboard started")
window["-AUTO-LOG-"].update("\n".join(tail_logs()))
draw_chart(window["-GRAPH-"])
window["-SYS-"].update(sys_summary())
window["-SEC-LOG-"].update("\n".join(tail_logs()))

processed_rows = []  # (ts, action, detail)
last_sys = time.time()

while True:
    ev, vals = window.read(timeout=750)
    if ev in (sg.WIN_CLOSED, "Exit"): break

    if time.time() - last_sys > 1.5:
        window["-SYS-"].update(sys_summary()); last_sys = time.time()

    # track active tab
    try:
        idx = tabs.TabGroupSelectedTabIndex(tabs)
        SETTINGS["last_tab"] = tab_map[idx]
    except: pass

    if ev == "-IN-FOLDER-": SETTINGS["last_folder"] = vals["-IN-FOLDER-"]

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
        folder = (vals["-IN-FOLDER-"] or "").strip()
        pattern = (vals["-GLOB-"] or "*.txt").strip()
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
        draw_chart(window["-GRAPH-"])

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
            import hashlib
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

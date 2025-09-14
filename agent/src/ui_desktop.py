import sys, time, threading, json, os
from pathlib import Path

# ---------------- Settings ----------------
def load_settings(base):
    d = {"apiUrl":"http://localhost:8000","autoStartWatcher":True,"watch":{"invoices":"agent/data/invoices/in","hr":"agent/data/hr/in"}}
    try:
        p = base / "agent" / "config" / "settings.json"
        if p.exists():
            d.update(json.loads(p.read_text(encoding="utf-8")))
    except Exception:
        pass
    return d

# ---------------- API helpers ----------------
def api_post(api, path, payload):
    try:
        import requests
        r = requests.post(api + path, json=payload, timeout=5)
        r.raise_for_status()
        return True, r.json()
    except Exception as e:
        return False, str(e)

def api_get(api, path):
    try:
        import requests
        r = requests.get(api + path, timeout=3)
        r.raise_for_status()
        return True, r.json()
    except Exception as e:
        return False, str(e)

# ---------------- Watcher ----------------
class CsvWatcher:
    def __init__(self, base_dir: Path, api: str, folders: dict):
        self.base = base_dir
        self.api = api
        self.folders = folders or {}
        self._running = False
        self._observer = None
        self._pending = {}
        self._lock = threading.Lock()

    def _schedule_run(self, flow):
        # debounce frequent events
        now = time.time()
        with self._lock:
            self._pending[flow] = now

    def _pump(self):
        while self._running:
            time.sleep(1.0)
            to_fire = []
            now = time.time()
            with self._lock:
                for flow, ts in list(self._pending.items()):
                    if now - ts >= 1.0:
                        to_fire.append(flow)
                        del self._pending[flow]
            for flow in to_fire:
                ok, _ = api_post(self.api, "/run", {"flow": flow})
                # ignore errors; tray menu shows manual triggers.

    def _handler_factory(self, flow):
        class H:
            def __init__(self, outer): self.outer = outer
            def on_created(self, event): 
                if not event.is_directory and event.src_path.lower().endswith(".csv"): self.outer._schedule_run(flow)
            def on_modified(self, event): 
                if not event.is_directory and event.src_path.lower().endswith(".csv"): self.outer._schedule_run(flow)
        return H(self)

    def start(self):
        try:
            from watchdog.observers import Observer
            from watchdog.events import FileSystemEventHandler
        except Exception:
            return False, "watchdog not installed"
        self._running = True
        self._observer = Observer()
        inv = self.base / self.folders.get("invoices","agent/data/invoices/in")
        hr  = self.base / self.folders.get("hr","agent/data/hr/in")
        inv.mkdir(parents=True, exist_ok=True)
        hr.mkdir(parents=True, exist_ok=True)
        self._observer.schedule(self._handler_factory("finance.reconcile"), str(inv), recursive=False)
        self._observer.schedule(self._handler_factory("hr.onboarding"), str(hr), recursive=False)
        self._observer.start()
        threading.Thread(target=self._pump, daemon=True).start()
        return True, "ok"

    def stop(self):
        self._running = False
        try:
            if self._observer:
                self._observer.stop()
                self._observer.join(timeout=3)
        except Exception:
            pass

# ---------------- Tray ----------------
def build_icon():
    try:
        from PIL import Image, ImageDraw
        img = Image.new("RGBA",(16,16),(0,0,0,0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((1,1,15,15), radius=4, outline=(46,196,182,255), width=2, fill=(46,196,182,40))
        return img
    except Exception:
        return None

def start_tray(ctx):
    try:
        import pystray
    except Exception:
        return None
    icon_img = build_icon()
    def do_health(icon, item):
        api, _ = ctx["api"], None
        ok, _ = api_get(api,"/health")
        ctx["balloon"]("API: ok" if ok else "API: down")
    def do_run_fin(icon,item): api_post(ctx["api"],"/run",{"flow":"finance.reconcile"})
    def do_run_hr(icon,item):  api_post(ctx["api"],"/run",{"flow":"hr.onboarding"})
    def do_toggle_watch(icon,item):
        if ctx["watching"]:
            ctx["watch"].stop(); ctx["watching"]=False; icon.title="Operion (Watcher: Off)"
        else:
            ok,_=ctx["watch"].start(); ctx["watching"]=ok; icon.title="Operion (Watcher: On)" if ok else "Operion (Watcher: Err)"
    def do_quit(icon,item):
        try:
            ctx["watch"].stop()
        except Exception: pass
        icon.stop()
        try:
            import webview
            webview.destroy_window()
        except Exception:
            os._exit(0)
    menu = pystray.Menu(
        pystray.MenuItem("API Health", do_health),
        pystray.MenuItem("Run Invoice Reconcile", do_run_fin),
        pystray.MenuItem("Run HR Onboarding",  do_run_hr),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem(lambda item: "Watcher: On" if ctx["watching"] else "Watcher: Off", do_toggle_watch),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Quit", do_quit)
    )
    icon = pystray.Icon("operion", icon_img, title="Operion", menu=menu)
    threading.Thread(target=icon.run, daemon=True).start()
    return icon

# ---------------- App ----------------
def _bg_ping(api_url: str):
    try:
        import requests
        while True:
            try: requests.get(f"{api_url}/health", timeout=2)
            except Exception: pass
            time.sleep(15)
    except Exception:
        pass

def main():
    try:
        import webview
    except ImportError:
        print("pywebview not installed."); sys.exit(1)

    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parents[2]))
    settings = load_settings(base)
    api = settings.get("apiUrl","http://localhost:8000")

    # Prepare window content (local console)
    index = base / "console" / "index.html"
    if index.exists(): url = index.as_uri()
    else:
        url = "data:text/html,<h3 style=\"font-family:Segoe UI;color:#e8eef9;background:#0b1220;padding:20px\">Operion</h3>"

    # Start background API pinger
    threading.Thread(target=_bg_ping, args=(api,), daemon=True).start()

    # Watcher
    watch = CsvWatcher(base, api, settings.get("watch") or {})
    watching = False
    if settings.get("autoStartWatcher", True):
        ok,_ = watch.start()
        watching = ok

    # Tray
    def balloon(msg):
        try:
            # no native balloon in pystray; for now, print to stdout
            print("[tray]", msg)
        except Exception:
            pass
    ctx = {"api": api, "watch": watch, "watching": watching, "balloon": balloon}
    start_tray(ctx)

    # Desktop window
    window = webview.create_window("Operion", url=url, width=1150, height=740, easy_drag=True, confirm_close=True)
    webview.start(debug=False)

if __name__ == "__main__":
    main()

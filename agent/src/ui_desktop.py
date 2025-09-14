import os
import sys
import threading
import time
from pathlib import Path

# Optional: try to ping API in background (non-blocking)
def _bg_health_check(api_url: str):
    try:
        import requests
        while True:
            try:
                requests.get(f"{api_url}/health", timeout=2)
            except Exception:
                pass
            time.sleep(15)
    except Exception:
        # requests not installed? ignore silently
        pass

def main():
    try:
        import webview
    except ImportError:
        print("pywebview not installed. Install with: pip install pywebview")
        sys.exit(1)

    repo = Path(__file__).resolve().parents[2]  # .../operion
    console_index = repo / "console" / "index.html"
    # If console/index.html exists, render it; otherwise render a minimal inline page
    if console_index.exists():
        url = console_index.as_uri()
    else:
        # Minimal inline UI if console isn't present
        url = "data:text/html," + """
<!doctype html>
<html><head><meta charset='utf-8'><title>Operion</title>
<style>body{background:#0b1220;color:#e8eef9;font-family:Segoe UI,system-ui,sans-serif;margin:0}
.header{padding:16px 20px;border-bottom:1px solid #1e2745;font-weight:600}
.main{padding:20px}
.card{background:#0f172a;border:1px solid #1e2745;border-radius:12px;padding:16px;max-width:640px}
.btn{background:#141c31;border:1px solid #2a355a;color:#e8eef9;padding:8px 12px;border-radius:10px;cursor:pointer}
.btn:hover{background:#1a2440}
.kv{opacity:.85}
</style></head>
<body>
  <div class='header'>Operion — Desktop</div>
  <div class='main'>
    <div class='card'>
      <div>Status: <span id='status' class='kv'>Checking…</span></div>
      <div style='margin-top:12px'><button class='btn' onclick='check()'>Check API</button></div>
    </div>
  </div>
<script>
async function check(){
  const el=document.getElementById('status');
  try{
    const r=await fetch('http://localhost:8000/health',{cache:'no-store'});
    const j=await r.json(); el.textContent=j.status||'ok';
  }catch(e){ el.textContent='down'; }
}
check();
</script>
</body></html>
""".replace("\n","")

    # Optional background health pinger
    threading.Thread(target=_bg_health_check, args=("http://localhost:8000",), daemon=True).start()

    # Create native window
    window = webview.create_window("Operion", url=url, width=1100, height=720, easy_drag=True, confirm_close=True)
    # Secure-ish defaults (no inspector by default)
    webview.start(debug=False)

if __name__ == "__main__":
    main()

# Operion — Desktop Dashboard (Software Only)

**Automation. Corporate Intelligence. Solutions.**

## What it is
A one-screen **Desktop Dashboard** with tabs for **Automation**, **Analytics**, **Security**, and **About/Help** — built with PySimpleGUI.

### Key Features
- **Automation**: run simple workflows; demo file processing → `app/python/outputs`
- **Analytics**: chart of processed files/day (from logs) + system summary (CPU/MEM/NET totals)
- **Security**: login simulation + **lockout rule** (10 fails in 15 minutes) with event logging
- **About/Help**: branding text and version/build

### Logging & Retention
- Daily logs in **`_logs`**, with **`app/appsettings.json`** controlling **log_retention_days** (default 30).

### Persistence
- Remembers last-used tab, window size, last input folder in **`app/python/settings.json`**.
- PIN gate **planned** (toggle + hash persisted; not enforced yet).

### Run it
```powershell
pwsh -NoProfile -File .\app\python\run.ps1
```
The script creates a **venv** and installs `requirements.txt`.

### Extras
- **Export Report (.csv)** summarizing processed items.
- **Open Outputs** quick access.

---

### End-to-end smoke (R0c)

1) API:
\\\powershell
.\api\scripts\run_api.ps1
# open http://localhost:8000/health
# optional: http://localhost:8000/heartbeats  http://localhost:8000/runs
\\\

2) Agent (starts heartbeat job):
\\\powershell
.\agent\scripts\run_agent.ps1
\\\

3) Console:
- Open \console/index.html\
- Press **Check API**; 'Today’s Status' should turn green.
- Recent Runs should list 2–3 sample items. Heartbeats appear at /heartbeats.

### Desktop App (no browser)

- Double-click the **Operion** shortcut on your Desktop.
- This launches a native window (pywebview). No browser required.
- If the API is running (.\api\scripts\run_api.ps1), the app can talk to it at http://localhost:8000.


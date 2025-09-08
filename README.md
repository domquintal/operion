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

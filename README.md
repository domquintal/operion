# Operion

Local control + ops scripts.

## Quick start
- Open **app/ui/Control.ps1** (double-click or run via PowerShell 7/5.1).
- Use **Start App**, **Sanity**, **Update → Push**, **Make Release ZIP**, **Open Logs**.

## Scripts
- `ops/sanity.ps1` — repo health checks (writes to `_logs/`).
- `ops/update.ps1` — pull → bump `VERSION.txt` → sanity → commit/push (on PASS).
- `ops/package.ps1` — builds release zip under `dist/`.
- `ops/tail-log.ps1` — tails newest log.

## Paths
- Logs: `_logs\`
- Releases: `dist\`
- Settings: `app\settings.json`

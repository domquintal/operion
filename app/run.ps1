param()
$ErrorActionPreference="Stop"

function Show-FallbackWindow {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form               = New-Object System.Windows.Forms.Form
    $form.Text          = "Operion (Fallback UI)"
    $form.StartPosition = "CenterScreen"
    $form.Size          = New-Object System.Drawing.Size(640, 360)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline   = $true
    $tb.ScrollBars  = "Vertical"
    $tb.ReadOnly    = $true
    $tb.Font        = New-Object System.Drawing.Font("Consolas", 10)
    $tb.Location    = New-Object System.Drawing.Point(12, 12)
    $tb.Size        = New-Object System.Drawing.Size(600, 260)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Close"
    $btn.Location = New-Object System.Drawing.Point(12, 280)
    $btn.Add_Click({ $form.Close() })
    $form.Controls.AddRange(@($tb,$btn))
    $tb.AppendText("Operion fallback UI is running.`r`nIf you expected the Python GUI, see log for details.`r`n")
    [void]$form.ShowDialog()
  } catch {
    Write-Host "[FALLBACK-ERR] $($_.Exception.Message)"
  }
}

$here = Split-Path -Parent $PSCommandPath
$venv = Join-Path $here ".venv"
$py   = Join-Path $venv "Scripts\python.exe"
$pip  = Join-Path $venv "Scripts\pip.exe"
$req  = Join-Path $here "python\requirements.txt"
$main = Join-Path $here "python\main.py"

Write-Host "[RUN] Operion launcher starting..."
Write-Host "[RUN] here=$here"
Write-Host "[RUN] venv=$venv"

# Ensure venv
if (!(Test-Path $py)) {
  Write-Host "[SETUP] Creating venv..."
  if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 -m venv $venv
  } else {
    Write-Host "[WARN] Python launcher 'py' not found. Skipping Python path and using fallback UI."
    Show-FallbackWindow
    exit 10
  }
}

# Install deps
Write-Host "[SETUP] Installing requirements..."
& $pip install -r $req
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] pip failed with exit $LASTEXITCODE — showing fallback UI."
  Show-FallbackWindow
  exit 11
}

# Quick sanity check: run a tiny Python snippet
& $py - <<'PYCODE'
print("sanity: python alive")
PYCODE
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] Python sanity check failed ($LASTEXITCODE) — showing fallback UI."
  Show-FallbackWindow
  exit 12
}

# Launch the Python GUI
Write-Host "[RUN] Starting Python GUI..."
& $py $main
$code = $LASTEXITCODE
Write-Host "[RUN] App exit code: $code"

# If GUI didn't open or failed, still ensure the user sees a window
if ($code -ne 0) {
  Write-Host "[WARN] Python app returned $code — showing fallback UI."
  Show-FallbackWindow
}

exit $code

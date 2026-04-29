# run_dev.ps1 - Reliable dev launcher
Set-Location -Path $PSScriptRoot

Write-Host "Activating virtual environment..." -ForegroundColor Green
.\venv\Scripts\Activate.ps1

# Fix Unicode/emoji printing on Windows
$env:PYTHONIOENCODING = "utf-8"

Write-Host "Starting BLUPOS Backend..." -ForegroundColor Cyan
python backend.py

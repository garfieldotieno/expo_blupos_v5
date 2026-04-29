# build_exe.ps1 - Full updated robust build script for BLUPOS backend_server.exe
# Run this in PowerShell from the project root

Set-Location -Path $PSScriptRoot

Write-Host "=== BLUPOS Backend Build - Full Debug Mode ===" -ForegroundColor Cyan

$venvPython = ".\venv\Scripts\python.exe"

# Step 1: Create venv if it doesn't exist
if (!(Test-Path "venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    py -m venv venv
} else {
    Write-Host "Virtual environment already exists." -ForegroundColor Green
}

# Step 2: Upgrade pip and install dependencies
Write-Host "Upgrading pip and installing requirements..." -ForegroundColor Yellow
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r requirements.txt --upgrade
& $venvPython -m pip install --upgrade pyinstaller

# Step 3: Clean previous builds
Write-Host "Cleaning old build folders..." -ForegroundColor Yellow
Remove-Item -Recurse -Force build, dist, *.spec -ErrorAction SilentlyContinue

# Step 4: Ensure instance directory exists
Write-Host "Ensuring instance directory exists..." -ForegroundColor Yellow
if (!(Test-Path "instance")) {
    New-Item -ItemType Directory -Path "instance" | Out-Null
    Write-Host "Created instance directory" -ForegroundColor Green
} else {
    Write-Host "Instance directory already exists" -ForegroundColor Green
}

# Step 5: Ensure database file exists
$dbPath = "instance/pos_test.db"
if (!(Test-Path $dbPath)) {
    Write-Host "Creating empty database file..." -ForegroundColor Yellow
    New-Item -ItemType File -Path $dbPath | Out-Null
    Write-Host "Created empty database file" -ForegroundColor Green
} else {
    Write-Host "Database file already exists" -ForegroundColor Green
}

# Step 6: Build with PyInstaller
Write-Host "Building backend_server.exe with strong debugging..." -ForegroundColor Cyan

$pyInstallerArgs = @(
    "--onefile",
    "--name", "backend_server",
    "--console",                    # Keeps console window visible
    "--add-data", "templates;templates",
    "--add-data", "static;static",
    "--add-data", "utils;utils",
    "--add-data", "instance;instance",
    "--add-data", "*.json;.",
    "--add-data", ".pos_keys.yml;.",
    "--hidden-import=backend_sms_service",
    "--hidden-import=backend_broadcast_service",
    "--hidden-import=standalone_microserver",
    "--hidden-import=sqlalchemy.dialects.sqlite",
    "--collect-all", "flask",
    "--collect-all", "sqlalchemy",
    "--collect-all", "reportlab",
    "--collect-all", "xhtml2pdf",
    "--hidden-import=rlPyCairo",
    "--hidden-import=pyhanko",
    "backend_debug_wrapper.py"      # Use the robust wrapper as entry point
)

& $venvPython -m PyInstaller @pyInstallerArgs --clean

Write-Host ""
Write-Host "=== Build Completed Successfully ===" -ForegroundColor Green
Write-Host "Executable location: .\dist\backend_server.exe" -ForegroundColor Yellow
Write-Host "To test: cd dist ; .\backend_server.exe" -ForegroundColor Yellow
Write-Host ""
Write-Host "The console window should now stay open and show the exact error." -ForegroundColor Magenta
Pause
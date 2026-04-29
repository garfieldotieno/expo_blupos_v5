# BLU POS System - Windows Setup Script
# This script downloads, installs, and configures the optimal Python environment
# for the BLU POS system, including generating context_timestamped_start.bat

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Please right-click on this script and select 'Run as administrator'." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Get current timestamp for context file naming
$datepart = Get-Date -Format "yyyyMMdd"
$timepart = Get-Date -Format "HHmmss"
$timestamp = "$datepart`_$timepart"

# Set project directory (script location)
$PROJECT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PROJECT_DIR

Write-Host "Project directory: $PROJECT_DIR" -ForegroundColor Green
Write-Host ""

# Function to check if Python is installed
function Check-Python {
    Write-Host "Checking Python installation..." -ForegroundColor Cyan
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python is already installed." -ForegroundColor Green
        Write-Host $pythonVersion -ForegroundColor Yellow
        Check-PythonVersion
    } else {
        Write-Host "Python not found. Proceeding with installation..." -ForegroundColor Yellow
        Install-Python
    }
}

# Function to check Python version compatibility
function Check-PythonVersion {
    $pythonVersion = python --version 2>&1
    $versionMatch = [regex]::Match($pythonVersion, 'Python (\d+)\.(\d+)\.(\d+)')
    if ($versionMatch.Success) {
        $major = [int]$versionMatch.Groups[1].Value
        $minor = [int]$versionMatch.Groups[2].Value
        
        if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 8)) {
            Write-Host "Python $pythonVersion is compatible." -ForegroundColor Green
            Check-VirtualEnv
        } else {
            Write-Host "ERROR: Python version $pythonVersion is not compatible." -ForegroundColor Red
            Write-Host "This project requires Python 3.8 or higher." -ForegroundColor Red
            Write-Host "Proceeding with Python installation..." -ForegroundColor Yellow
            Install-Python
        }
    } else {
        Write-Host "ERROR: Could not determine Python version." -ForegroundColor Red
        Write-Host "Proceeding with Python installation..." -ForegroundColor Yellow
        Install-Python
    }
}

# Function to install Python
function Install-Python {
    Write-Host "" -ForegroundColor White
    Write-Host "Downloading Python installer..." -ForegroundColor Cyan
    $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    $pythonInstaller = "python-installer.exe"
    
    if (Test-Path $pythonInstaller) {
        Write-Host "Python installer already downloaded." -ForegroundColor Yellow
    } else {
        Write-Host "Downloading Python 3.11.9..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        } catch {
            Write-Host "ERROR: Failed to download Python installer." -ForegroundColor Red
            Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    
    Write-Host "Installing Python..." -ForegroundColor Cyan
    Write-Host "Note: This may take a few minutes..." -ForegroundColor Yellow
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Python installation failed." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "Python installation completed." -ForegroundColor Green
    Remove-Item $pythonInstaller
    
    # Refresh environment variables
    refreshenv
    Write-Host "Environment variables refreshed." -ForegroundColor Green
    
    Check-Python
}

# Function to check and create virtual environment
function Check-VirtualEnv {
    Write-Host "" -ForegroundColor White
    Write-Host "Checking virtual environment..." -ForegroundColor Cyan
    if (Test-Path "venv") {
        Write-Host "Virtual environment already exists." -ForegroundColor Green
        Install-Requirements
    } else {
        Write-Host "Creating virtual environment..." -ForegroundColor Cyan
        python -m venv venv
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to create virtual environment." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }
        Write-Host "Virtual environment created successfully." -ForegroundColor Green
        Install-Requirements
    }
}

# Function to install requirements
function Install-Requirements {
    Write-Host "" -ForegroundColor White
    Write-Host "Installing Python packages from requirements.txt..." -ForegroundColor Cyan
    Activate-VirtualEnv
    
    # Upgrade pip first
    Write-Host "Upgrading pip..." -ForegroundColor Cyan
    python -m pip install --upgrade pip
    
    # Install requirements
    if (Test-Path "requirements.txt") {
        Write-Host "Installing requirements..." -ForegroundColor Cyan
        pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: Some packages may have failed to install." -ForegroundColor Yellow
            Write-Host "This could be due to missing system dependencies." -ForegroundColor Yellow
            Write-Host "Please check the error messages above." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Attempting to continue with available packages..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "WARNING: requirements.txt not found in project directory." -ForegroundColor Yellow
        Write-Host "Proceeding without package installation." -ForegroundColor Yellow
    }
    
    # Deactivate virtual environment
    Deactivate-VirtualEnv
    
    Generate-StartScript
}

# Function to activate virtual environment
function Activate-VirtualEnv {
    Write-Host "Activating virtual environment..." -ForegroundColor Cyan
    & "venv\Scripts\Activate.ps1"
}

# Function to deactivate virtual environment
function Deactivate-VirtualEnv {
    Write-Host "Deactivating virtual environment..." -ForegroundColor Cyan
    deactivate
}

# Function to generate context_timestamped_start.bat
function Generate-StartScript {
    Write-Host "" -ForegroundColor White
    Write-Host "Generating context_timestamped_start.bat..." -ForegroundColor Cyan
    
    $startScript = "context_timestamped_start_$timestamp.bat"
    
    $scriptContent = @"
@echo off

===============================================
 BLU POS System - Start Script
 Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
 Context: $timestamp
===============================================

Activating virtual environment...
call venv\Scripts\activate

Starting BLU POS backend...
echo.

python backend.py

echo.

echo If the application starts successfully, you can access it at:
echo http://localhost:5000 (or the configured port)
echo

echo To stop the application, press Ctrl+C in this window.
echo

pause
"@
    
    Set-Content -Path $startScript -Value $scriptContent
    
    if (Test-Path $startScript) {
        Write-Host "Generated: $startScript" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host " Setup Complete!" -ForegroundColor Green
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Run ""$startScript"" to start the application" -ForegroundColor Yellow
        Write-Host "2. Or run ""utils\start.bat"" for a quick start" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        Write-Host "The application should be accessible at http://localhost:5000" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
        Write-Host "If you encounter any issues:" -ForegroundColor Yellow
        Write-Host "- Check that Python 3.8+ is properly installed" -ForegroundColor Yellow
        Write-Host "- Ensure all requirements were installed successfully" -ForegroundColor Yellow
        Write-Host "- Verify that port 5000 is not in use by another application" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
    } else {
        Write-Host "ERROR: Failed to generate start script." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Start the setup process
Write-Host "===============================================" -ForegroundColor Green
Write-Host " BLU POS System - Windows Setup" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White

Check-Python

Read-Host "Press Enter to exit"
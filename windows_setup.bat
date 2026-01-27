@echo off
REM BLU POS System - Windows Setup Script
REM This script downloads, installs, and configures the optimal Python environment
REM for the BLU POS system, including generating context_timestamped_start.bat

setlocal enabledelayedexpansion

echo.
echo ===============================================
echo  BLU POS System - Windows Setup
echo ===============================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator.
    echo Please right-click on this script and select "Run as administrator".
    pause
    exit /b 1
)

REM Get current timestamp for context file naming
for /f "tokens=1-4 delims=/- " %%a in ('date /t') do (
    set datepart=%%a%%b%%c
)
for /f "tokens=1-2 delims=/: " %%a in ('time /t') do (
    set timepart=%%a%%b
)
set timestamp=%datepart%_%timepart%

REM Set project directory (script location)
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

echo Project directory: %PROJECT_DIR%
echo.

REM Function to check if Python is installed
:check_python
echo Checking Python installation...
python --version >nul 2>&1
if %errorlevel% EQU 0 (
    echo Python is already installed.
    python --version
    goto check_python_version
) else (
    echo Python not found. Proceeding with installation...
    goto install_python
)

REM Function to check Python version compatibility
:check_python_version
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
for /f "tokens=1-2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
)

if %MAJOR% gtr 3 (
    goto python_compatible
)
if %MAJOR% equ 3 (
    if %MINOR% geq 8 (
        goto python_compatible
    )
)

echo ERROR: Python version %PYTHON_VERSION% is not compatible.
echo This project requires Python 3.8 or higher.
echo Proceeding with Python installation...
goto install_python

:python_compatible
echo Python %PYTHON_VERSION% is compatible.
goto check_virtual_env

REM Function to install Python
:install_python
echo.
echo Downloading Python installer...
set "PYTHON_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
set "PYTHON_INSTALLER=python-installer.exe"

if exist "%PYTHON_INSTALLER%" (
    echo Python installer already downloaded.
) else (
    echo Downloading Python 3.11.9...
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%' -UseBasicParsing" || (
        echo ERROR: Failed to download Python installer.
        echo Please check your internet connection and try again.
        pause
        exit /b 1
    )
)

echo Installing Python...
echo Note: This may take a few minutes...
start "" /wait "%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0

if %errorlevel% NEQ 0 (
    echo ERROR: Python installation failed.
    pause
    exit /b 1
)

echo Python installation completed.
del "%PYTHON_INSTALLER%"

REM Refresh environment variables
call refreshenv 2>nul
if %errorlevel% NEQ 0 (
    echo Warning: Could not refresh environment variables automatically.
    echo You may need to restart this script or open a new command prompt.
)

goto check_python

REM Function to check and create virtual environment
:check_virtual_env
echo.
echo Checking virtual environment...
if exist "venv" (
    echo Virtual environment already exists.
    goto check_requirements
) else (
    echo Creating virtual environment...
    python -m venv venv
    if %errorlevel% NEQ 0 (
        echo ERROR: Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo Virtual environment created successfully.
    goto install_requirements
)

REM Function to install requirements
:install_requirements
echo.
echo Installing Python packages from requirements.txt...
call venv\Scripts\activate

REM Upgrade pip first
echo Upgrading pip...
python -m pip install --upgrade pip

REM Install requirements
if exist "requirements.txt" (
    echo Installing requirements...
    pip install -r requirements.txt
    if %errorlevel% NEQ 0 (
        echo WARNING: Some packages may have failed to install.
        echo This could be due to missing system dependencies.
        echo Please check the error messages above.
        echo.
        echo Attempting to continue with available packages...
    )
) else (
    echo WARNING: requirements.txt not found in project directory.
    echo Proceeding without package installation.
)

REM Deactivate virtual environment
deactivate

goto generate_start_script

REM Function to generate context_timestamped_start.bat
:generate_start_script
echo.
echo Generating context_timestamped_start.bat...

set "START_SCRIPT=context_timestamped_start_%timestamp%.bat"

(
    echo @echo off
    echo.
    echo ===============================================
    echo  BLU POS System - Start Script
    echo  Generated: %date% %time%
    echo  Context: %timestamp%
    echo ===============================================
    echo.
    echo Activating virtual environment...
    echo call venv\Scripts\activate
    echo.
    echo Starting BLU POS backend...
    echo echo.
    echo python backend.py
    echo.
    echo echo.
    echo echo If the application starts successfully, you can access it at:
    echo echo http://localhost:5000 (or the configured port)
    echo echo.
    echo echo To stop the application, press Ctrl+C in this window.
    echo echo.
    echo pause
) > "%START_SCRIPT%"

if exist "%START_SCRIPT%" (
    echo Generated: %START_SCRIPT%
    echo.
    echo ===============================================
    echo  Setup Complete!
    echo ===============================================
    echo.
    echo Next steps:
    echo 1. Run "%START_SCRIPT%" to start the application
    echo 2. Or run "utils\start.bat" for a quick start
    echo.
    echo The application should be accessible at http://localhost:5000
    echo.
    echo If you encounter any issues:
    echo - Check that Python 3.8+ is properly installed
    echo - Ensure all requirements were installed successfully
    echo - Verify that port 5000 is not in use by another application
    echo.
) else (
    echo ERROR: Failed to generate start script.
    pause
    exit /b 1
)

pause
endlocal
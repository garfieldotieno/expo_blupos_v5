@echo off
REM Test script for windows_setup.bat
REM This script validates the setup process without actually installing anything

echo.
echo ===============================================
echo  BLU POS System - Setup Test
echo ===============================================
echo.

echo Testing setup script components...
echo.

REM Test 1: Check if setup script exists
if exist "windows_setup.bat" (
    echo ✓ windows_setup.bat found
) else (
    echo ✗ windows_setup.bat not found
    goto test_failed
)

REM Test 2: Check if requirements.txt exists
if exist "requirements.txt" (
    echo ✓ requirements.txt found
) else (
    echo ✗ requirements.txt not found
    goto test_failed
)

REM Test 3: Check if backend.py exists
if exist "backend.py" (
    echo ✓ backend.py found
) else (
    echo ✗ backend.py not found
    goto test_failed
)

REM Test 4: Check if utils directory exists
if exist "utils" (
    echo ✓ utils directory found
) else (
    echo ✗ utils directory not found
    goto test_failed
)

REM Test 5: Check if utils\start.bat exists
if exist "utils\start.bat" (
    echo ✓ utils\start.bat found
) else (
    echo ✗ utils\start.bat not found
    goto test_failed
)

REM Test 6: Check if README exists
if exist "WINDOWS_SETUP_README.md" (
    echo ✓ WINDOWS_SETUP_README.md found
) else (
    echo ✗ WINDOWS_SETUP_README.md not found
    goto test_failed
)

echo.
echo ===============================================
echo  All tests passed! ✓
echo ===============================================
echo.
echo The setup is ready. To install:
echo 1. Right-click on windows_setup.bat
echo 2. Select "Run as administrator"
echo 3. Wait for completion
echo.
echo For more information, see WINDOWS_SETUP_README.md
echo.
pause
exit /b 0

:test_failed
echo.
echo ===============================================
echo  Test failed! ✗
echo ===============================================
echo.
echo Please check the missing components above.
echo Ensure all required files are present before running the setup.
echo.
pause
exit /b 1
@echo off

===============================================
 BLU POS System - Start Script
 Generated: 2026-04-11 15:07:03
 Context: 20260411_150632
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

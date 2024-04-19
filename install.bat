@echo off

REM Create a virtual environmnet named 'venv'
call python -m venv venv

REM Activate virtual environment
call venv\Scripts\activate

REM Install dependencies for reuirements.txt
call pip install -r requirements.txt

REM Deactivate virtual environment
call deactivate

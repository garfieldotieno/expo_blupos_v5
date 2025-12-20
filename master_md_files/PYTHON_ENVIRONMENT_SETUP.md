# Python Environment Setup for BLU POS System

## Problem Description

When attempting to run `python3 backend.py`, you encounter the following error:
```
ModuleNotFoundError: No module named 'flask'
```

Attempting to install Flask with `pip3 install flask` fails with:
```
error: externally-managed-environment
```

This occurs because modern Ubuntu/Debian systems follow PEP 668, which prevents direct pip installations to avoid conflicts with system packages.

## Solution: Use Virtual Environment

The recommended solution is to create a Python virtual environment for your project, which allows you to install packages locally without affecting the system Python installation.

## Step-by-Step Setup Instructions

### 1. Navigate to Project Directory
```bash
cd ~/work/Work2Backup/Work/expo_blupos_v5
```

### 2. Create Virtual Environment
```bash
python3 -m venv venv
```
This creates a `venv` directory containing the virtual environment.

### 3. Activate Virtual Environment
```bash
source venv/bin/activate
```

After activation, your terminal prompt will show `(venv)` at the beginning.

### 4. Install Project Dependencies
```bash
pip install -r requirements.txt
```

This will install all required packages including Flask, Flask-Cors, SQLAlchemy, etc.

### 5. Run the Backend
```bash
python3 backend.py
```

### 6. Deactivate Virtual Environment (When Done)
```bash
deactivate
```

## Automated Setup Script

Create a file named `setup_env.sh` in the project directory with the following content:

```bash
#!/bin/bash
# setup_env.sh - Automated environment setup for BLU POS

set -e  # Exit on any error

echo "Setting up Python virtual environment for BLU POS..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install requirements
pip install -r requirements.txt

echo "Environment setup complete!"
echo "To activate the environment, run: source venv/bin/activate"
echo "To run the backend, run: python3 backend.py"
```

Make it executable and run it:
```bash
chmod +x setup_env.sh
./setup_env.sh
```

## Important Notes

- **Always activate the virtual environment** before running the backend or any Python scripts in this project
- The virtual environment is local to this project directory
- If you open a new terminal, you'll need to activate the environment again
- To check if environment is active, look for `(venv)` in your terminal prompt

## Troubleshooting

### If you get "python3: command not found"
Ensure Python 3 is installed:
```bash
sudo apt update
sudo apt install python3 python3-venv python3-pip
```

### If virtual environment creation fails
Ensure python3-venv is installed:
```bash
sudo apt install python3-venv
```

### If pip install fails
- Ensure you're in the activated virtual environment
- Try upgrading pip first: `pip install --upgrade pip`

## Environment Management

### Checking Installed Packages
```bash
pip list
```

### Updating Requirements
If you add new dependencies, update requirements.txt:
```bash
pip freeze > requirements.txt
```

### Removing Virtual Environment
To start fresh:
```bash
deactivate
rm -rf venv
```

Then follow the setup steps again.

## Running the Application

After setup:
1. Activate environment: `source venv/bin/activate`
2. Run backend: `python3 backend.py`
3. Access the application at the configured URL (check backend.py for details)

The virtual environment approach ensures clean dependency management and avoids conflicts with system packages.

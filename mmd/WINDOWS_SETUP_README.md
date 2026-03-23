# Windows Setup for BLU POS System

This document explains how to use the `windows_setup.bat` script to automatically set up the Python environment for the BLU POS system on Windows.

## Overview

The `windows_setup.bat` script is a comprehensive setup tool that:

1. **Downloads and installs Python** (if not present or incompatible version)
2. **Creates a virtual environment** for isolated package management
3. **Installs all required dependencies** from `requirements.txt`
4. **Generates a timestamped start script** for easy application launching

## Prerequisites

- Windows 10 or later
- Administrator privileges (required for Python installation)
- Internet connection (for downloading Python and packages)

## Quick Start

### 1. Run the Setup Script

1. **Right-click** on `windows_setup.bat`
2. Select **"Run as administrator"**
3. Wait for the installation to complete (may take 5-10 minutes)

### 2. Start the Application

After setup completes, you'll have two options:

**Option A: Use the generated timestamped script**
```cmd
context_timestamped_start_YYYYMMDD_HHMM.bat
```

**Option B: Use the existing start script**
```cmd
utils\start.bat
```

### 3. Access the Application

Once started, the application should be accessible at:
- **Default URL**: `http://localhost:5000`
- **Alternative**: Check `backend.py` for the configured port

## What the Script Does

### Step 1: Python Installation Check
- Checks if Python is already installed
- Verifies Python version compatibility (requires 3.8+)
- Downloads and installs Python 3.11.9 if needed

### Step 2: Virtual Environment Setup
- Creates a `venv` directory in your project folder
- Isolates project dependencies from system Python

### Step 3: Package Installation
- Upgrades pip to the latest version
- Installs all packages listed in `requirements.txt`:
  - Flask and Flask-CORS for web framework
  - SQLAlchemy for database management
  - ReportLab for PDF generation
  - Various other dependencies

### Step 4: Start Script Generation
- Creates a timestamped start script: `context_timestamped_start_YYYYMMDD_HHMM.bat`
- Includes helpful information and troubleshooting tips
- Provides clear instructions for starting the application

## Generated Files

After running the setup script, you'll have:

```
expo_blupos_v5/
├── venv/                    # Virtual environment
├── windows_setup.bat       # This setup script
├── context_timestamped_start_YYYYMMDD_HHMM.bat  # Generated start script
└── utils/
    ├── start.bat           # Existing start script
    └── install.bat         # Existing install script
```

## Troubleshooting

### Common Issues

**"This script must be run as Administrator"**
- Right-click the script and select "Run as administrator"
- Ensure your user account has administrative privileges

**Python installation fails**
- Check internet connection
- Temporarily disable antivirus/firewall
- Try running the script again

**Package installation errors**
- Some packages may require system dependencies
- The script will continue with available packages
- Check specific error messages for missing system requirements

**Port 5000 already in use**
- Stop other applications using port 5000
- Or modify the port in `backend.py`

### Manual Python Installation

If the automatic installation fails, you can manually install Python:

1. Download Python 3.11.9 from [python.org](https://www.python.org/downloads/)
2. Run the installer with "Add Python to PATH" checked
3. Re-run `windows_setup.bat`

### Manual Virtual Environment Setup

If the script fails at the virtual environment step:

```cmd
# Create virtual environment manually
python -m venv venv

# Activate it
venv\Scripts\activate

# Install requirements
pip install -r requirements.txt

# Deactivate when done
deactivate
```

## Security Notes

- The script downloads Python from the official python.org website
- All downloads use HTTPS for security
- The script runs with administrator privileges only for Python installation
- Virtual environment isolates project dependencies

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review the error messages in the command prompt
3. Ensure you're running as administrator
4. Verify your internet connection
5. Check that your system meets the prerequisites

## Technical Details

### Python Version
- **Minimum**: Python 3.8
- **Recommended**: Python 3.11.9 (automatically installed)
- **Architecture**: 64-bit (amd64)

### Virtual Environment
- **Location**: `./venv/`
- **Activation**: `venv\Scripts\activate`
- **Deactivation**: `deactivate`

### Dependencies
All dependencies are listed in `requirements.txt` and include:
- Web framework: Flask, Flask-CORS
- Database: SQLAlchemy
- PDF generation: ReportLab, xhtml2pdf
- Utilities: requests, pyserial, qrcode, etc.

## Updates

To update the Python environment:

1. Delete the `venv` folder
2. Re-run `windows_setup.bat`
3. This will create a fresh environment with latest packages

## Uninstallation

To completely remove the Python environment:

1. Delete the `venv` folder
2. Delete any generated `context_timestamped_start_*.bat` files
3. The main application files remain intact

---

For additional support or questions, refer to the main project documentation or contact the development team.
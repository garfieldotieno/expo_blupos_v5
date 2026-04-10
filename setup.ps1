# Check if Python is installed
if (-Not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Python is not installed. Please install Python first."
    exit
}

# Set up the virtual environment name
$venvName = "env"

# Check if the virtual environment already exists
if (-Not (Test-Path $venvName)) {
    # Create a virtual environment
    python -m venv $venvName
    Write-Host "Virtual environment created: $venvName"
} else {
    Write-Host "Virtual environment already exists: $venvName"
}

# Activate the virtual environment
& "$venvName\Scripts\Activate.ps1"

# Install requirements
if (Test-Path "requirements.txt") {
    pip install -r requirements.txt
    Write-Host "Requirements installed from requirements.txt."
} else {
    Write-Host "requirements.txt not found."
}
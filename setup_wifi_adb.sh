#!/bin/bash

# WiFi ADB Setup Automation Script for BluPOS Flutter Development
# Automates the process of configuring Android device for wireless Flutter development

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo
    echo -e "${YELLOW}Press Enter when ready...${NC}"
    read REPLY
}

# Main setup function
setup_wifi_adb() {
    echo "========================================"
    echo "🔌 WiFi ADB Setup for Flutter Development"
    echo "========================================"
    echo

    # Check if ADB is installed
    if ! command_exists adb; then
        print_error "ADB is not installed or not in PATH."
        echo "Please install Android SDK platform tools:"
        echo "  Ubuntu/Debian: sudo apt install android-tools-adb"
        echo "  Or download from: https://developer.android.com/studio/releases/platform-tools"
        exit 1
    fi

    print_success "ADB found at: $(which adb)"

    # Step 1: Check for connected devices
    echo
    print_status "Step 1: Checking for connected Android devices..."
    echo "Please ensure:"
    echo "  1. Your Android device is connected via USB cable"
    echo "  2. USB debugging is enabled (Settings > Developer Options > USB Debugging)"
    echo "  3. You have authorized this computer for debugging"
    wait_for_user

    echo
    print_status "Checking connected devices..."
    DEVICES_OUTPUT=$(adb devices)
    echo "$DEVICES_OUTPUT"

    # Check if any devices are connected
    if ! echo "$DEVICES_OUTPUT" | grep -q "device$"; then
        print_error "No Android devices found!"
        echo
        echo "Troubleshooting steps:"
        echo "1. Make sure your device is connected via USB"
        echo "2. Enable Developer Options on your Android device:"
        echo "   - Go to Settings > About Phone"
        echo "   - Tap 'Build Number' 7 times until you see 'You are now a developer'"
        echo "3. Enable USB Debugging:"
        echo "   - Go to Settings > Developer Options"
        echo "   - Enable 'USB Debugging'"
        echo "4. Accept the debugging authorization on your device"
        echo "5. Try different USB ports or cables"
        echo
        echo "Run this script again after connecting your device."
        exit 1
    fi

    # Get device ID (first device found)
    DEVICE_ID=$(echo "$DEVICES_OUTPUT" | grep "device$" | head -1 | awk '{print $1}')
    print_success "Found device: $DEVICE_ID"

    # Step 2: Enable TCP/IP mode
    echo
    print_status "Step 2: Enabling WiFi ADB mode on device..."
    echo "This will restart ADB on your device in TCP mode (port 5555)"

    if adb -s "$DEVICE_ID" tcpip 5555; then
        print_success "TCP/IP mode enabled successfully"
    else
        print_error "Failed to enable TCP/IP mode"
        exit 1
    fi

    # Wait a moment for the device to restart in TCP mode
    print_status "Waiting for device to restart in TCP mode..."
    sleep 3

    # Step 3: Get device IP address
    echo
    print_status "Step 3: Getting device IP address..."

    # Try to get IP address using different methods
    IP_ADDRESS=""

    # Method 1: Using ip route command
    IP_OUTPUT=$(adb -s "$DEVICE_ID" shell ip route 2>/dev/null || echo "")
    if echo "$IP_OUTPUT" | grep -q "src"; then
        IP_ADDRESS=$(echo "$IP_OUTPUT" | grep "src" | awk '{print $9}' | head -1)
        print_success "Found IP address (method 1): $IP_ADDRESS"
    fi

    # Method 2: Alternative approach if method 1 fails
    if [ -z "$IP_ADDRESS" ]; then
        IP_OUTPUT=$(adb -s "$DEVICE_ID" shell ifconfig wlan0 2>/dev/null | grep "inet addr" || echo "")
        if [ -n "$IP_OUTPUT" ]; then
            IP_ADDRESS=$(echo "$IP_OUTPUT" | awk '{print $2}' | cut -d: -f2)
            print_success "Found IP address (method 2): $IP_ADDRESS"
        fi
    fi

    # Method 3: Manual input if automatic detection fails
    if [ -z "$IP_ADDRESS" ]; then
        echo
        print_warning "Automatic IP detection failed."
        echo "Please check your Android device's IP address manually:"
        echo "  Settings → WiFi → Tap your network name → IP address"
        echo
        echo -n "Enter your device's IP address: "
        read IP_ADDRESS

        if [ -z "$IP_ADDRESS" ]; then
            print_error "No IP address provided"
            exit 1
        fi
    fi

    # Validate IP address format
    if ! echo "$IP_ADDRESS" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null; then
        print_error "Invalid IP address format: $IP_ADDRESS"
        exit 1
    fi

    print_success "Using device IP: $IP_ADDRESS"

    # Step 4: Connect wirelessly
    echo
    print_status "Step 4: Connecting to device wirelessly..."

    # First, try to connect
    if adb connect "$IP_ADDRESS:5555"; then
        print_success "Wireless connection established!"
    else
        print_error "Failed to connect wirelessly"
        echo
        echo "Troubleshooting:"
        echo "1. Make sure both devices are on the same WiFi network"
        echo "2. Check if the IP address is correct"
        echo "3. Try disabling and re-enabling WiFi on your device"
        echo "4. Restart the device and try again"
        exit 1
    fi

    # Step 5: Verify wireless connection
    echo
    print_status "Step 5: Verifying wireless connection..."
    sleep 2

    WIRELESS_DEVICES=$(adb devices)
    echo "$WIRELESS_DEVICES"

    if echo "$WIRELESS_DEVICES" | grep -q "$IP_ADDRESS:5555"; then
        print_success "✅ Wireless ADB connection verified!"
    else
        print_error "Wireless device not found in device list"
        exit 1
    fi

    # Success message
    echo
    echo "========================================"
    print_success "🎉 WiFi ADB Setup Complete!"
    echo "========================================"
    echo
    echo "Device Information:"
    echo "  📱 Device ID: $DEVICE_ID"
    echo "  🌐 Wireless IP: $IP_ADDRESS:5555"
    echo
    echo "Next Steps:"
    echo "1. 🔌 You can now disconnect the USB cable"
    echo "2. 🚀 Run Flutter commands wirelessly:"
    echo "   cd apk_section/blupos_wallet"
    echo "   flutter devices                    # Should show wireless device"
    echo "   flutter run -d $IP_ADDRESS:5555   # Run app wirelessly"
    echo
    echo "For future connections, you can reconnect with:"
    echo "  adb connect $IP_ADDRESS:5555"
    echo
    print_success "Happy Flutter development! 🎉"
}

# Function to show usage
show_usage() {
    echo "WiFi ADB Setup Script for BluPOS Flutter Development"
    echo
    echo "Usage:"
    echo "  $0              # Run interactive setup"
    echo "  $0 --help       # Show this help"
    echo "  $0 --version    # Show version"
    echo
    echo "This script automates the process of setting up wireless ADB"
    echo "for Flutter development, ending with the ability to run:"
    echo "  flutter run -d <device_ip>:5555"
}

# Function to show version
show_version() {
    echo "WiFi ADB Setup Script v1.0.0"
    echo "For BluPOS Flutter Development"
}

# Main script logic
case "${1:-}" in
    --help|-h)
        show_usage
        exit 0
        ;;
    --version|-v)
        show_version
        exit 0
        ;;
    *)
        setup_wifi_adb
        ;;
esac

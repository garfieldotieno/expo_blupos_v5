#!/bin/bash

# Quick WiFi ADB Reconnect Script for BluPOS Flutter Development
# Reconnects to a previously configured Android device wirelessly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default device IP (can be overridden)
DEFAULT_IP="192.168.0.100"
DEVICE_IP="${1:-$DEFAULT_IP}"

print_status "Connecting to Android device at $DEVICE_IP:5555..."

if adb connect "$DEVICE_IP:5555"; then
    print_success "✅ Connected to $DEVICE_IP:5555"

    # Verify connection
    sleep 1
    if adb devices | grep -q "$DEVICE_IP:5555"; then
        print_success "🎉 Device ready for Flutter development!"
        echo
        echo "Run Flutter commands:"
        echo "  cd apk_section/blupos_wallet"
        echo "  flutter devices"
        echo "  flutter run -d $DEVICE_IP:5555"
    else
        print_error "Connection verification failed"
        exit 1
    fi
else
    print_error "❌ Failed to connect to $DEVICE_IP:5555"
    echo
    echo "Troubleshooting:"
    echo "1. Make sure device is on same WiFi network"
    echo "2. Run full setup: ./setup_wifi_adb.sh"
    echo "3. Check device IP address"
    exit 1
fi

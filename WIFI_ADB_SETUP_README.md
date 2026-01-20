# WiFi ADB Setup for BluPOS Flutter Development

This guide provides automated scripts to set up wireless ADB (Android Debug Bridge) for Flutter development, eliminating the need for USB cables during development.

## 🚀 Quick Start

### First-Time Setup
```bash
# Run the automated setup script
./setup_wifi_adb.sh
```

This script will:
1. ✅ Check for ADB installation
2. 🔍 Detect connected Android devices
3. 📡 Enable TCP/IP mode on your device
4. 🌐 Automatically detect device IP address
5. 🔗 Establish wireless connection
6. ✅ Verify connection works

### Daily Reconnection
```bash
# Quick reconnect (uses saved IP)
./connect_device.sh

# Or specify custom IP
./connect_device.sh 192.168.1.105
```

## 📋 Prerequisites

### Android Device Setup
1. **Enable Developer Options:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times until you see "You are now a developer"

2. **Enable USB Debugging:**
   - Go to Settings → Developer Options
   - Enable "USB Debugging"

3. **Connect via USB:**
   - Connect your Android device to computer via USB
   - Accept USB debugging authorization on device

### Computer Setup
- **ADB Installation:**
  ```bash
  # Ubuntu/Debian
  sudo apt install android-tools-adb

  # Or download from Android SDK
  # https://developer.android.com/studio/releases/platform-tools
  ```

## 🔧 Scripts Overview

### `setup_wifi_adb.sh`
**Purpose:** Complete WiFi ADB setup for first-time use

**Features:**
- Interactive setup with colored output
- Automatic IP detection (multiple methods)
- Comprehensive error handling
- Troubleshooting guidance
- Step-by-step progress indication

**Usage:**
```bash
# Interactive setup
./setup_wifi_adb.sh

# Show help
./setup_wifi_adb.sh --help

# Show version
./setup_wifi_adb.sh --version
```

### `connect_device.sh`
**Purpose:** Quick reconnection to previously configured device

**Features:**
- Fast reconnection (no full setup)
- Uses saved/default IP address
- Connection verification
- Error handling

**Usage:**
```bash
# Connect with default IP (192.168.0.100)
./connect_device.sh

# Connect with custom IP
./connect_device.sh 192.168.1.105
```

## 🎯 Flutter Development Workflow

### After Setup
```bash
# Navigate to Flutter project
cd apk_section/blupos_wallet

# Verify wireless device is detected
flutter devices

# Example output:
# Android (android-arm64) • 192.168.0.100:5555 • android-arm64 • Android 13 (API 33)

# Run Flutter app wirelessly
flutter run -d 192.168.0.100:5555

# Or use device ID
flutter run -d android-arm64
```

### Hot Reload Benefits
- ✅ **No USB cable required** - Work from anywhere on same network
- ✅ **Hot reload works seamlessly** - Instant UI updates
- ✅ **Multiple devices** - Connect multiple devices simultaneously
- ✅ **Better ergonomics** - No cable management during development

## 🔍 Troubleshooting

### Common Issues

#### "No Android devices found"
```bash
# Check USB connection
adb devices

# Enable developer options on device
# Settings → About Phone → Tap Build Number 7x

# Enable USB debugging
# Settings → Developer Options → USB Debugging
```

#### "Connection failed"
```bash
# Ensure same WiFi network
# Check device IP address manually:
# Settings → WiFi → Tap network name → IP address

# Try manual connection
adb connect YOUR_DEVICE_IP:5555
```

#### "Device not found after disconnecting USB"
```bash
# Reconnect wirelessly
./connect_device.sh YOUR_DEVICE_IP

# Or full setup
./setup_wifi_adb.sh
```

### IP Address Detection Methods

The setup script tries multiple methods to detect your device's IP:

1. **Method 1:** `adb shell ip route` (most reliable)
2. **Method 2:** `adb shell ifconfig wlan0` (fallback)
3. **Method 3:** Manual input (if automatic fails)

### Manual IP Check
On your Android device:
- Settings → WiFi → Tap your network name → IP address

## 📁 Project Structure

```
expo_blupos_v5/
├── setup_wifi_adb.sh          # Main setup script
├── connect_device.sh          # Quick reconnect script
├── WIFI_ADB_SETUP_README.md   # This documentation
└── apk_section/blupos_wallet/ # Flutter project
```

## 🔄 Connection Management

### Persistent Connections
- WiFi ADB connections persist until device restart
- Reconnect anytime with `./connect_device.sh`
- No need to repeat full setup process

### Multiple Devices
```bash
# Connect multiple devices
./connect_device.sh 192.168.0.100  # Phone
./connect_device.sh 192.168.0.101  # Tablet

# List all devices
flutter devices

# Run on specific device
flutter run -d 192.168.0.100:5555
```

## 🛠️ Advanced Usage

### Custom IP Storage
Edit `connect_device.sh` to change default IP:
```bash
# Change this line for your default device
DEFAULT_IP="192.168.1.100"
```

### Integration with Development Workflow
Add to your shell profile (`~/.bashrc` or `~/.zshrc`):
```bash
# Quick aliases
alias connect-phone='./connect_device.sh 192.168.0.100'
alias flutter-phone='flutter run -d 192.168.0.100:5555'
alias phone-dev='cd apk_section/blupos_wallet && flutter run -d 192.168.0.100:5555'
```

### CI/CD Integration
For automated testing:
```yaml
# .github/workflows/flutter_test.yml
- name: Setup WiFi ADB
  run: ./setup_wifi_adb.sh

- name: Run Flutter tests
  run: flutter test integration_test/
```

## 📞 Support

### Getting Help
1. **Check device IP:** Ensure devices are on same network
2. **Verify ADB:** `adb devices` should show wireless connection
3. **Restart devices:** Sometimes network changes require restart
4. **Firewall:** Ensure ADB port 5555 is not blocked

### Error Messages
- **"ADB not found"** → Install Android SDK platform tools
- **"No devices"** → Check USB connection and developer options
- **"Connection timeout"** → Check network and IP address
- **"Permission denied"** → Accept USB debugging authorization

## 🎉 Success Indicators

### Setup Complete
```
=======================================
🎉 WiFi ADB Setup Complete!
=======================================
📱 Device ID: DEF NW18A09002486
🌐 Wireless IP: 192.168.0.100:5555

🔌 You can now disconnect the USB cable
🚀 flutter run -d 192.168.0.100:5555
```

### Flutter Ready
```bash
$ flutter devices
Android (android-arm64) • 192.168.0.100:5555 • android-arm64 • Android 13 (API 33)

$ flutter run -d 192.168.0.100:5555
Launching lib/main.dart on Android SDK built for arm64 in debug mode...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...         3.2s
🎉 Hot reload available!
```

---

**Version:** 1.0.0
**Last Updated:** 2026-01-13
**For:** BluPOS Flutter Thermal Printer Integration

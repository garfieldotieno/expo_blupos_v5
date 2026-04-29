#!/bin/bash
# Setup script for Android emulator micro-server access
# This script sets up ADB port forwarding to access the micro-server from the host

set -e

MICROSERVER_PORT=8085
EMULATOR_DEVICE=${1:-"emulator-5554"}

echo "🚀 Setting up Android emulator micro-server access"
echo "📱 Emulator device: $EMULATOR_DEVICE"
echo "🔌 Port: $MICROSERVER_PORT"
echo

# Check if emulator is running
echo "🔍 Checking if emulator is running..."
if ! adb devices | grep -q "$EMULATOR_DEVICE"; then
    echo "❌ Emulator $EMULATOR_DEVICE is not running"
    echo "💡 Start the emulator first:"
    echo "   • Android Studio: Open AVD Manager → Start emulator"
    echo "   • Command line: emulator -avd <avd_name>"
    exit 1
fi

echo "✅ Emulator $EMULATOR_DEVICE is running"

# Check if Flutter app is running on emulator
echo "🔍 Checking if Flutter app is running..."
if ! adb -s "$EMULATOR_DEVICE" shell ps | grep -q "blupos_wallet"; then
    echo "⚠️ Flutter app may not be running on emulator"
    echo "💡 Make sure to run: flutter run --device-id=$EMULATOR_DEVICE"
    echo "   Continuing with port forwarding setup..."
fi

# Check if host port is already in use
echo "🔍 Checking if host port $MICROSERVER_PORT is available..."
if lsof -i :$MICROSERVER_PORT >/dev/null 2>&1; then
    echo "⚠️ Host port $MICROSERVER_PORT is already in use"
    PROCESS_INFO=$(lsof -i :$MICROSERVER_PORT | tail -n 1)
    echo "   Process using port: $PROCESS_INFO"

    # Check if ADB already has port forwarding set up
    ADB_FORWARDING=$(adb forward --list 2>/dev/null | grep "tcp:$MICROSERVER_PORT tcp:$MICROSERVER_PORT" || echo "")

    if [ -n "$ADB_FORWARDING" ]; then
        echo "✅ ADB port forwarding already active for port $MICROSERVER_PORT"
        echo "📡 $ADB_FORWARDING"
        echo "🎯 Ready to connect to Flutter app micro-server"
        # Skip the rest and go to testing
        SKIP_SETUP=true
    else
        # Get the actual command line of the process
        PROCESS_CMD=$(ps -p $(lsof -t -i :$MICROSERVER_PORT) -o cmd= 2>/dev/null || echo "")

        # Check if it's our standalone micro-server
        if echo "$PROCESS_CMD" | grep -q "standalone_microserver"; then
            echo "   💡 Detected standalone micro-server running"
            echo "   🔄 Stopping standalone server to connect to Flutter app micro-server..."
            echo "🛑 Stopping standalone micro-server..."
            kill $(lsof -t -i :$MICROSERVER_PORT)
            sleep 2
            echo "✅ Standalone server stopped - ready to connect to Flutter app"
        else
            echo "❌ Host port $MICROSERVER_PORT is in use by another process"
            echo "   Process: $PROCESS_INFO"
            echo "💡 Please free up port $MICROSERVER_PORT and try again"
            exit 1
        fi
    fi
fi

# Skip setup if ADB forwarding is already active
if [ "$SKIP_SETUP" != "true" ]; then
    # Remove any existing port forwarding for this port
    echo "🔄 Removing existing port forwarding..."
    adb -s "$EMULATOR_DEVICE" forward --remove tcp:$MICROSERVER_PORT 2>/dev/null || true

    # Set up port forwarding from host to emulator
    echo "🌐 Setting up port forwarding..."
    if adb -s "$EMULATOR_DEVICE" forward tcp:$MICROSERVER_PORT tcp:8085; then
        echo "✅ Port forwarding established successfully!"
        echo "📡 Host localhost:$MICROSERVER_PORT → Emulator 127.0.0.1:8085"
    else
        echo "❌ Failed to establish port forwarding"
        exit 1
    fi

    # Verify port forwarding is working
    echo "🔍 Verifying port forwarding..."
    if adb -s "$EMULATOR_DEVICE" forward --list | grep -q "tcp:$MICROSERVER_PORT"; then
        echo "✅ Port forwarding verified"
    else
        echo "❌ Port forwarding verification failed"
        exit 1
    fi
fi

# Test connection to micro-server
echo "🧪 Testing micro-server connectivity..."
sleep 2

if curl -s --max-time 5 http://localhost:$MICROSERVER_PORT/health > /dev/null 2>&1; then
    echo "✅ Micro-server is accessible!"
    echo "🎯 Connection test: PASSED"
    echo
    echo "🚀 Ready to use micro-server endpoints:"
    echo "   http://localhost:$MICROSERVER_PORT/health"
    echo "   http://localhost:$MICROSERVER_PORT/sms/shortcodes"
    echo "   http://localhost:$MICROSERVER_PORT/sms/not-read"
    echo
    echo "🛠️ Use the query tool:"
    echo "   python3 query_microserver.py"
else
    echo "⚠️ Micro-server not responding yet"
    echo "💡 This is normal if the Flutter app hasn't started the micro-server"
    echo "   Try again after the app loads, or restart the Flutter app"
    echo
    echo "🔄 Port forwarding remains active for when micro-server starts"
fi

echo
echo "📋 Port forwarding status:"
adb -s "$EMULATOR_DEVICE" forward --list | grep "tcp:$MICROSERVER_PORT" || echo "No active forwarding found"

echo
echo "🛑 To remove port forwarding later:"
echo "   adb -s $EMULATOR_DEVICE forward --remove tcp:$MICROSERVER_PORT"

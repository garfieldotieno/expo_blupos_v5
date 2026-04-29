#!/usr/bin/env python3
"""
Microserver Launcher for SMS API Testing - January 8, 2026

Starts the BluPOS Wallet microserver to enable testing of SMS API endpoints.

Usage:
    python start_microserver.py
"""

import sys
import os
import signal
import time
from threading import Timer

# Add the current directory to Python path to import our modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the microserver service
from apk_section.blupos_wallet.lib.services.micro_server_service import MicroServerService

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    print("\n🛑 Received shutdown signal, stopping microserver...")
    MicroServerService.stopServer()
    sys.exit(0)

def main():
    """Start the microserver for testing"""
    print("BluPOS Wallet Microserver Launcher")
    print("===================================")
    print("")

    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        print("🚀 Starting microserver...")
        MicroServerService.startServer()

        print("\n✅ Microserver started successfully!")
        print("📡 Available SMS API endpoints:")
        print("   GET  /on-boot-sms-total-count")
        print("   GET  /after-boot-total-count")
        print("   GET  /message/<id>")
        print("")
        print("🧪 Ready for testing with: python test_sms_api_endpoints.py")
        print("🛑 Press Ctrl+C to stop the server")
        print("")

        # Keep the server running
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n🛑 Shutting down microserver...")
    except Exception as e:
        print(f"❌ Failed to start microserver: {e}")
        sys.exit(1)
    finally:
        MicroServerService.stopServer()

if __name__ == "__main__":
    main()

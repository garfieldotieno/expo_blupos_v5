#!/usr/bin/env python3
"""
Script to clear cached server IP from Flutter app SharedPreferences
This forces the app to rediscover the backend server on next startup
"""

import os
import sqlite3
import json
from pathlib import Path

def clear_flutter_shared_prefs():
    """Clear Flutter SharedPreferences to force server rediscovery"""
    
    # Common Flutter app data directories
    flutter_data_dirs = [
        # Android emulator
        Path.home() / "Library/Developer/CoreSimulator/Devices" / "*" / "data/Containers/Data/Application" / "*" / "Library/Preferences",
        # Android device (common paths)
        Path.home() / ".android/avd" / "*" / "data/data/com.example.blupos_wallet/shared_prefs",
        # Linux development
        Path.home() / ".local/share/com.example.blupos_wallet",
        # Generic Flutter shared prefs location
        Path.home() / "Library/Preferences" / "com.example.blupos_wallet",
    ]
    
    # Look for SharedPreferences files
    prefs_files = [
        "*.xml",  # Android
        "*.plist",  # iOS
        "*.json",  # Custom storage
    ]
    
    print("🔍 Searching for Flutter SharedPreferences files...")
    
    # Check if we can find any Flutter app data
    found_files = []
    for data_dir in flutter_data_dirs:
        if data_dir.exists():
            for pattern in prefs_files:
                for file_path in data_dir.glob(f"**/{pattern}"):
                    if "blupos" in str(file_path).lower() or "flutter" in str(file_path).lower():
                        found_files.append(file_path)
    
    if found_files:
        print(f"📁 Found {len(found_files)} potential SharedPreferences files:")
        for f in found_files:
            print(f"  {f}")
    else:
        print("ℹ️ No SharedPreferences files found in standard locations")
        print("💡 This is normal if the app hasn't been run yet or uses different storage")
    
    # Alternative: Create a simple script to run from Flutter app
    print("\n" + "="*50)
    print("📝 FLUTTER APP SOLUTION:")
    print("="*50)
    print("Add this code to your Flutter app to clear cached server IP:")
    print("""
    // Add this method to clear cached server IP
    Future<void> clearCachedServerIp() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      print('🗑️ Cleared cached server IP - app will rediscover on next startup');
    }
    
    // Call this method when needed, e.g., on button press
    await clearCachedServerIp();
    """)
    
    print("\n" + "="*50)
    print("🔄 MANUAL SOLUTION:")
    print("="*50)
    print("1. Uninstall the Flutter app from your device/emulator")
    print("2. Reinstall the app")
    print("3. The app will rediscover the backend server on first run")
    print("\n📡 Backend is currently broadcasting on:")
    print("   IP: 192.168.0.102")
    print("   Port: 8080")
    print("   URL: http://192.168.0.102:8080")

if __name__ == "__main__":
    clear_flutter_shared_prefs()

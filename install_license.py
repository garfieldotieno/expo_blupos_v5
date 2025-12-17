#!/usr/bin/env python3
"""
License Installation Script for Expo BLUPOS v5
This script installs a license using available reset keys and displays the keys.
"""

import sys
import os

# Add the current directory to the path so we can import backend
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import Flask and setup app context
from backend import app, LicenseResetKey, create_license, fetch_licenses, randomString
from backend import datetime, timedelta
import hashlib

def print_available_keys():
    """Print all available license reset keys"""
    try:
        keys = LicenseResetKey.fetch_keys()
        print(f"\n📋 Available License Reset Keys ({len(keys)} total):")
        print("=" * 50)
        for i, key_hash in enumerate(keys, 1):
            print(f"{i:2d}. {key_hash}")
        return keys
    except Exception as e:
        print(f"❌ Error reading keys: {e}")
        return []

def find_original_key_for_hash(target_hash, max_attempts=100000):
    """Brute force search for the original key that produces a given hash"""
    print(f"\n🔍 Searching for original key for hash: {target_hash[:16]}...")

    for attempt in range(max_attempts):
        # Generate a potential key (16 characters)
        candidate = randomString(16)

        # Hash it and compare
        candidate_hash = hashlib.sha256(candidate.encode()).hexdigest()

        if candidate_hash == target_hash:
            print(f"✅ Found original key after {attempt + 1} attempts!")
            return candidate

        # Progress indicator
        if attempt % 10000 == 0 and attempt > 0:
            print(f"   Searched {attempt} keys...")

    print(f"❌ Could not find original key within {max_attempts} attempts")
    return None

def install_license_with_key(license_key, license_type="Full"):
    """Install a license using the provided key"""
    print(f"\n🔧 Installing {license_type} license with key: {license_key}")

    # Determine expiry days based on license type
    expiry_days = 366 if license_type == "Full" else 183

    # Create license payload
    payload = {
        "license_key": randomString(16),  # Generate a new license key
        "license_type": license_type,
        "license_status": True,
        "license_expiry": datetime.now() + timedelta(days=expiry_days)
    }

    try:
        result = create_license(payload)
        if result.get("status"):
            print("✅ License installed successfully!")
            print(f"   Type: {license_type}")
            print(f"   Expires: {payload['license_expiry'].strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   Days remaining: {expiry_days}")
            return True
        else:
            print(f"❌ License installation failed: {result.get('error', 'Unknown error')}")
            return False
    except Exception as e:
        print(f"❌ Error installing license: {e}")
        return False

def generate_new_keys(num_keys=5):
    """Generate and save new license reset keys"""
    print(f"\n🔑 Generating {num_keys} new license reset keys...")

    generated_keys = []
    for i in range(num_keys):
        key = randomString(16)
        LicenseResetKey.save_key(key)
        generated_keys.append(key)
        print(f"   {i+1}. {key} (hash: {hashlib.sha256(key.encode()).hexdigest()[:16]}...)")

    print("✅ New keys saved to .pos_keys.yml")
    return generated_keys

def main():
    # Use Flask application context
    with app.app_context():
        print("🚀 Expo BLUPOS v5 License Installation Script")
        print("=" * 50)

        # Check current license status
        current_licenses = fetch_licenses()
        if current_licenses:
            license_obj = current_licenses[0]
            print("📄 Current License Status:")
            print(f"   Type: {license_obj.license_type}")
            print(f"   Status: {'Active' if license_obj.license_status else 'Inactive'}")
            print(f"   Expires: {license_obj.license_expiry}")
            days_remaining = (license_obj.license_expiry.replace(tzinfo=None) - datetime.now()).days
            print(f"   Days remaining: {max(0, days_remaining)}")
        else:
            print("📄 No license currently installed")

        # Print available keys
        available_keys = print_available_keys()

        # Generate a new key and install license automatically
        print("\n🔑 Generating new license reset key...")
        new_key = randomString(16)
        LicenseResetKey.save_key(new_key)
        key_hash = hashlib.sha256(new_key.encode()).hexdigest()

        print(f"   Original Key: {new_key}")
        print(f"   Key Hash: {key_hash}")

        # Install license
        print("\n🔧 Installing Full license...")
        payload = {
            "license_key": randomString(16),
            "license_type": "Full",
            "license_status": True,
            "license_expiry": datetime.now() + timedelta(days=366)
        }

        result = create_license(payload)
        if result.get("status"):
            print("✅ License installed successfully!")
            print(f"   Type: Full")
            print(f"   Expires: {payload['license_expiry'].strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   Days remaining: 366")
        else:
            print(f"❌ License installation failed: {result.get('error', 'Unknown error')}")

        # Show all available keys
        keys = LicenseResetKey.fetch_keys()
        print(f"\n� All Available License Reset Keys ({len(keys)} total):")
        for i, key_hash in enumerate(keys, 1):
            print(f"{i:2d}. {key_hash}")

if __name__ == "__main__":
    main()

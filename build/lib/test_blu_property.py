#!/usr/bin/env python3
"""
Test script for Blu Property receipt generation system
"""

import requests
import json
import time

# Base URL for the Flask app (adjust if running on different port)
BASE_URL = "http://localhost:8080"

def test_generate_receipt():
    """Test receipt generation"""
    print("🧪 Testing Blu Property receipt generation...")

    payload = {
        "amount": 150.75,
        "payment_method": "Credit Card",
        "payment_reference": "TXN-123456789",
        "payment_gateway": "Stripe",
        "customer_info": {
            "name": "John Doe",
            "email": "john.doe@example.com",
            "phone": "+1234567890"
        },
        "items": [
            {
                "description": "Premium Service Package",
                "quantity": 1,
                "amount": 150.75
            }
        ]
    }

    try:
        response = requests.post(f"{BASE_URL}/api/blu-property/generate-receipt", json=payload)
        print(f"📡 Response status: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print("✅ Receipt generated successfully!")
            print(f"📄 Receipt UID: {data['receipt']['uid']}")
            print(f"💳 Payment Confirmation UID: {data['receipt']['payment_confirmation_uid']}")
            print(f"📊 EAN-13 Barcode: {data['receipt']['ean13_barcode']}")
            print(f"🔐 OTP Required: {data['receipt']['otp_required']}")
            print(f"⏰ OTP Expires: {data['receipt']['otp_expires_at']}")
            return data['receipt']['uid']
        else:
            print(f"❌ Failed to generate receipt: {response.text}")
            return None

    except Exception as e:
        print(f"❌ Error testing receipt generation: {e}")
        return None

def test_receipt_preview(receipt_uid):
    """Test receipt preview"""
    print(f"\n🧪 Testing receipt preview for UID: {receipt_uid}...")

    try:
        response = requests.get(f"{BASE_URL}/api/blu-property/receipt-preview/{receipt_uid}")
        print(f"📡 Response status: {response.status_code}")

        if response.status_code == 200:
            print("✅ Receipt preview retrieved successfully!")
            print("📄 Preview contains HTML content (thermal receipt template)")
            return True
        else:
            print(f"❌ Failed to get receipt preview: {response.text}")
            return False

    except Exception as e:
        print(f"❌ Error testing receipt preview: {e}")
        return False

def test_otp_verification(receipt_uid, otp_code):
    """Test OTP verification"""
    print(f"\n🧪 Testing OTP verification for receipt {receipt_uid}...")

    payload = {
        "receipt_uid": receipt_uid,
        "otp_code": otp_code
    }

    try:
        response = requests.post(f"{BASE_URL}/api/blu-property/verify-otp", json=payload)
        print(f"📡 Response status: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print("✅ OTP verified successfully!")
            print(f"📄 Receipt UID: {data['receipt']['uid']}")
            print(f"🔓 OTP Verified: {data['receipt']['otp_verified']}")
            return True
        else:
            data = response.json()
            print(f"❌ OTP verification failed: {data.get('message', 'Unknown error')}")
            return False

    except Exception as e:
        print(f"❌ Error testing OTP verification: {e}")
        return False

def test_download_receipt(receipt_uid):
    """Test receipt download"""
    print(f"\n🧪 Testing receipt download for UID: {receipt_uid}...")

    try:
        response = requests.get(f"{BASE_URL}/api/blu-property/download-receipt/{receipt_uid}")
        print(f"📡 Response status: {response.status_code}")

        if response.status_code == 200:
            print("✅ Receipt downloaded successfully!")
            print("📄 PDF file received (thermal receipt format)")
            print(f"📏 Content length: {len(response.content)} bytes")

            # Save the PDF for inspection
            with open(f"test_blu_receipt_{receipt_uid}.pdf", "wb") as f:
                f.write(response.content)
            print(f"💾 Saved as: test_blu_receipt_{receipt_uid}.pdf")

            return True
        else:
            data = response.json()
            print(f"❌ Failed to download receipt: {data.get('message', 'Unknown error')}")
            return False

    except Exception as e:
        print(f"❌ Error testing receipt download: {e}")
        return False

def run_full_test():
    """Run complete test suite"""
    print("🚀 Starting Blu Property Receipt System Test Suite")
    print("=" * 60)

    # Test 1: Generate receipt
    receipt_uid = test_generate_receipt()
    if not receipt_uid:
        print("❌ Test suite failed at receipt generation")
        return False

    # Test 2: Get receipt preview (should show OTP prompt)
    if not test_receipt_preview(receipt_uid):
        print("❌ Test suite failed at receipt preview")
        return False

    # For demo purposes, we'll need to manually get the OTP from the database
    # In a real scenario, this would be sent to the user
    print("\n📝 NOTE: In a real implementation, the OTP would be sent to the user")
    print("🔍 For testing, check the database or logs for the OTP code")
    # For this demo, let's assume we have the OTP (you would need to check the database)
    otp_code = input("🔐 Enter the OTP code from the receipt preview: ").strip()

    # Test 3: Verify OTP
    if not test_otp_verification(receipt_uid, otp_code):
        print("❌ Test suite failed at OTP verification")
        return False

    # Test 4: Download receipt (should work after OTP verification)
    if not test_download_receipt(receipt_uid):
        print("❌ Test suite failed at receipt download")
        return False

    print("\n" + "=" * 60)
    print("🎉 All tests passed! Blu Property receipt system is working correctly.")
    return True

if __name__ == "__main__":
    print("🔧 Blu Property Receipt System Test Script")
    print("Make sure the Flask app is running on http://localhost:8080")
    print()

    try:
        run_full_test()
    except KeyboardInterrupt:
        print("\n⏹️  Test interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")

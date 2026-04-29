#!/usr/bin/env python3

"""
Debug script to test the PDF preview functionality
"""

import requests
import json
import sys
import os

# Add the current directory to Python path to import backend modules
sys.path.insert(0, '/home/stark/work/Work2Backup/Work/expo_blupos_v5')

def test_pdf_preview():
    """Test the PDF preview endpoint with the same parameters as the frontend"""

    # Test URL and parameters (same as what the frontend sends)
    base_url = "http://localhost:8080"
    endpoint = "/preview-sale-receipt"

    # Parameters from the error log
    params = {
        'format': 'pdf',
        'clerk': 'Wandia',
        'total': '280',
        'transaction_code': '4047495555',
        'items': json.dumps(["10:Raha Cocoa 100g:140", "10:Raha Cocoa 100g:140"])
    }

    print("🔍 Testing PDF Preview Endpoint")
    print(f"📍 URL: {base_url}{endpoint}")
    print(f"📋 Parameters: {params}")
    print()

    try:
        # Make the request
        response = requests.get(f"{base_url}{endpoint}", params=params, timeout=10)

        print(f"📊 Response Status: {response.status_code}")
        print(f"📄 Response Headers: {dict(response.headers)}")
        print()

        if response.status_code == 200:
            print("✅ Request successful!")
            print(f"📏 Content Length: {len(response.content)} bytes")
            print(f"📄 Content Type: {response.headers.get('Content-Type', 'unknown')}")

            # Check if it's actually a PDF
            if response.headers.get('Content-Type', '').startswith('application/pdf'):
                print("✅ Content is PDF format")

                # Save to file for inspection
                with open('test_preview_output.pdf', 'wb') as f:
                    f.write(response.content)
                print("💾 Saved PDF to test_preview_output.pdf")
            else:
                print("❌ Content is not PDF format")
                print(f"📝 Response content: {response.text[:500]}...")

        elif response.status_code == 500:
            print("❌ Server Error (500)")
            try:
                error_data = response.json()
                print(f"📝 Error response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"📝 Error response: {response.text}")

        else:
            print(f"❌ Unexpected status code: {response.status_code}")
            print(f"📝 Response: {response.text}")

    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Could not connect to server")
        print("🔍 Is the Flask server running?")
    except requests.exceptions.Timeout:
        print("❌ Timeout: Server did not respond in time")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()

def test_simple_endpoint():
    """Test a simple endpoint to verify server is running"""

    base_url = "http://localhost:8080"
    endpoint = "/test-preview-simple"

    params = {
        'clerk': 'Test',
        'total': '100.00',
        'items': json.dumps(['test_item'])
    }

    print("🔍 Testing Simple Endpoint")
    print(f"📍 URL: {base_url}{endpoint}")
    print(f"📋 Parameters: {params}")
    print()

    try:
        response = requests.get(f"{base_url}{endpoint}", params=params, timeout=5)
        print(f"📊 Response Status: {response.status_code}")
        print(f"📝 Response: {response.text}")
        print()

    except Exception as e:
        print(f"❌ Error testing simple endpoint: {e}")
        print()

def check_dependencies():
    """Check if required dependencies are available"""

    print("🔧 Checking Dependencies")
    print()

    required_modules = [
        'flask',
        'reportlab',
        'xhtml2pdf',
        'qrcode',
        'pillow'
    ]

    for module in required_modules:
        try:
            __import__(module)
            print(f"✅ {module} is available")
        except ImportError:
            print(f"❌ {module} is NOT available")

    print()

if __name__ == "__main__":
    print("🚀 PDF Preview Debug Script")
    print("=" * 50)
    print()

    # Check dependencies first
    check_dependencies()

    # Test simple endpoint
    test_simple_endpoint()

    # Test PDF preview
    test_pdf_preview()

    print()
    print("📋 Debug Summary:")
    print("- Checked required dependencies")
    print("- Tested simple endpoint connectivity")
    print("- Tested PDF preview endpoint with actual parameters")
    print("- Saved any PDF output to test_preview_output.pdf")
    print()
    print("🔍 Next Steps:")
    print("1. Check if server is running")
    print("2. Check server logs for errors")
    print("3. Verify all dependencies are installed")
    print("4. Examine the PDF generation code in backend.py")

#!/usr/bin/env python3

"""
Detailed test to debug the PDF preview functionality
"""

import sys
import os
import json
import traceback
from io import BytesIO

# Add the current directory to Python path to import backend modules
sys.path.insert(0, '/home/stark/work/Work2Backup/Work/expo_blupos_v5')

def test_preview_function_directly():
    """Test the preview function directly by importing and calling it"""

    print("🔍 Testing Preview Function Directly")
    print("=" * 50)

    try:
        # Import the Flask app and function
        from backend import app, preview_sale_receipt

        print("✅ Successfully imported backend module")

        # Create a test client
        with app.test_client() as client:
            print("✅ Created test client")

            # Test the endpoint with the same parameters
            params = {
                'format': 'pdf',
                'clerk': 'Wandia',
                'total': '280',
                'transaction_code': '4047495555',
                'items': json.dumps(["10:Raha Cocoa 100g:140", "10:Raha Cocoa 100g:140"])
            }

            print(f"📋 Test parameters: {params}")

            # Make the request
            response = client.get('/preview-sale-receipt', query_string=params)

            print(f"📊 Response status: {response.status_code}")
            print(f"📄 Response headers: {dict(response.headers)}")

            if response.status_code == 200:
                print("✅ Request successful!")
                print(f"📏 Content length: {len(response.data)} bytes")
                print(f"📄 Content type: {response.headers.get('Content-Type', 'unknown')}")

                if response.headers.get('Content-Type', '').startswith('application/pdf'):
                    print("✅ Content is PDF format")

                    # Save to file
                    with open('test_preview_direct.pdf', 'wb') as f:
                        f.write(response.data)
                    print("💾 Saved PDF to test_preview_direct.pdf")
                else:
                    print("❌ Content is not PDF format")
                    print(f"📝 Response data: {response.data[:500]}...")

            else:
                print(f"❌ Request failed with status: {response.status_code}")
                print(f"📝 Response data: {response.data}")

    except Exception as e:
        print(f"❌ Exception during test: {e}")
        print("📋 Full traceback:")
        traceback.print_exc()

def test_dependencies_detailed():
    """Test each dependency in detail"""

    print("\n🔧 Testing Dependencies in Detail")
    print("=" * 50)

    dependencies = [
        ('flask', 'Flask'),
        ('reportlab', 'ReportLab'),
        ('xhtml2pdf', 'xhtml2pdf'),
        ('qrcode', 'QRCode'),
        ('pillow', 'PIL')
    ]

    for import_name, display_name in dependencies:
        try:
            module = __import__(import_name)
            print(f"✅ {display_name} ({import_name}): {module.__version__ if hasattr(module, '__version__') else 'available'}")
        except ImportError as e:
            print(f"❌ {display_name} ({import_name}): NOT AVAILABLE - {e}")
        except Exception as e:
            print(f"⚠️ {display_name} ({import_name}): ERROR - {e}")

def test_reportlab_specific():
    """Test ReportLab specifically"""

    print("\n🔧 Testing ReportLab Specifically")
    print("=" * 50)

    try:
        from reportlab.lib.pagesizes import landscape, letter, A4
        from reportlab.lib import colors
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, PageBreak, Paragraph, Spacer
        from reportlab.lib.units import inch

        print("✅ ReportLab imports successful")

        # Test creating a simple PDF
        try:
            pdf_buffer = BytesIO()
            doc = SimpleDocTemplate(pdf_buffer, pagesize=landscape(A4),
                                   leftMargin=0.5*inch, rightMargin=0.5*inch,
                                   topMargin=0.5*inch, bottomMargin=0.5*inch)
            styles = getSampleStyleSheet()

            story = []
            story.append(Paragraph("Test PDF", styles['Title']))
            story.append(Paragraph("This is a test PDF generation", styles['Normal']))

            doc.build(story)
            pdf_buffer.seek(0)

            print(f"✅ ReportLab PDF generation successful ({len(pdf_buffer.getvalue())} bytes)")

        except Exception as e:
            print(f"❌ ReportLab PDF generation failed: {e}")
            traceback.print_exc()

    except ImportError as e:
        print(f"❌ ReportLab import failed: {e}")
    except Exception as e:
        print(f"❌ ReportLab test failed: {e}")
        traceback.print_exc()

def test_qrcode_generation():
    """Test QR code generation"""

    print("\n🔧 Testing QR Code Generation")
    print("=" * 50)

    try:
        import qrcode
        from io import BytesIO
        import base64

        print("✅ QRCode imports successful")

        # Test generating a QR code
        try:
            qr = qrcode.QRCode(version=1, box_size=10, border=4)
            qr.add_data("Test QR Code")
            qr.make(fit=True)

            img = qr.make_image(fill_color="black", back_color="white")

            # Convert to base64
            buffer = BytesIO()
            img.save(buffer, format='PNG')
            buffer.seek(0)
            qr_base64 = base64.b64encode(buffer.read()).decode('utf-8')

            print(f"✅ QR code generation successful ({len(qr_base64)} bytes base64)")

        except Exception as e:
            print(f"❌ QR code generation failed: {e}")
            traceback.print_exc()

    except ImportError as e:
        print(f"❌ QRCode import failed: {e}")
    except Exception as e:
        print(f"❌ QR code test failed: {e}")
        traceback.print_exc()

def test_barcode_generation():
    """Test barcode generation"""

    print("\n🔧 Testing Barcode Generation")
    print("=" * 50)

    try:
        from PIL import Image, ImageDraw, ImageFont
        from io import BytesIO
        import base64

        print("✅ PIL imports successful")

        # Test generating a simple barcode-like image
        try:
            img = Image.new('RGB', (200, 60), color='white')
            draw = ImageDraw.Draw(img)

            # Draw some lines
            for i in range(0, 180, 4):
                if i % 8 == 0:
                    draw.rectangle([10 + i, 10, 12 + i, 50], fill='black')
                else:
                    draw.rectangle([10 + i, 15, 11 + i, 45], fill='black')

            # Convert to base64
            buffer = BytesIO()
            img.save(buffer, format='PNG')
            buffer.seek(0)
            barcode_base64 = base64.b64encode(buffer.read()).decode('utf-8')

            print(f"✅ Barcode generation successful ({len(barcode_base64)} bytes base64)")

        except Exception as e:
            print(f"❌ Barcode generation failed: {e}")
            traceback.print_exc()

    except ImportError as e:
        print(f"❌ PIL import failed: {e}")
    except Exception as e:
        print(f"❌ Barcode test failed: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    print("🚀 Detailed PDF Preview Debug Script")
    print("=" * 60)
    print()

    # Test dependencies
    test_dependencies_detailed()

    # Test specific components
    test_reportlab_specific()
    test_qrcode_generation()
    test_barcode_generation()

    # Test the preview function directly
    test_preview_function_directly()

    print()
    print("📋 Debug Complete")
    print("=" * 60)

#!/usr/bin/env python3

import requests
import json
from datetime import datetime

# Test PDF generation integrated into sales flow
def test_sales_flow_with_backend_pdf():
    """
    This test demonstrates how to integrate backend PDF generation
    into the sales checkout flow instead of using frontend HTML printing.
    """

    print("=== SALES FLOW WITH BACKEND PDF INTEGRATION ===\n")

    # Step 1: Prepare sale data (normally collected from frontend UI)
    print("Step 1: Preparing sale data...")
    test_data = {
        "sale_clerk": "Test Clerk",
        "sale_total": 225.0,
        "sale_paid_amount": 225.0,
        "sale_balance": 0.0,
        "payment_method": "CASH",
        "payment_reference": "TEST123",
        "payment_gateway": "0000-0000",
        "items_array": ["2:Royal Strawberry Yoghurt 500ml:100.0", "1:Test Item 1:50.0", "3:Test Item 3:75.0"]
    }
    print(f"Sale data: {json.dumps(test_data, indent=2)}\n")

    # Step 2: Submit sale record to backend (normally triggered by checkout button)
    print("Step 2: Submitting sale record to backend...")
    try:
        response = requests.post('http://localhost:8080/add_sale_record', json=test_data)
        print(f"Response status: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            print(f"Response: {json.dumps(result, indent=2)}")

            if result.get('status') and result.get('sale_record'):
                sale_id = result['sale_record']['id']
                sale_uid = result['sale_record']['uid']
                print(f"✅ Sale record created successfully!")
                print(f"   Sale ID: {sale_id}")
                print(f"   Sale UID: {sale_uid}\n")

                # Step 3: Automatically generate and download PDF receipt
                # (normally triggered after successful sale recording)
                print("Step 3: Generating PDF receipt from backend...")

                pdf_response = requests.get(f'http://localhost:8080/download-sale-receipt/{sale_id}')
                print(f"PDF request status: {pdf_response.status_code}")

                if pdf_response.status_code == 200:
                    # Save the PDF (normally would trigger browser download)
                    with open('backend_generated_receipt.pdf', 'wb') as f:
                        f.write(pdf_response.content)

                    print("✅ PDF receipt generated and downloaded successfully!")
                    print("   File saved as: backend_generated_receipt.pdf")
                    print(f"   File size: {len(pdf_response.content)} bytes")
                    print("   Content-Type: application/pdf")
                    print(f"   Filename: receipt_{sale_uid}.pdf\n")

                    # Verify PDF content
                    file_response = requests.head(f'http://localhost:8080/download-sale-receipt/{sale_id}')
                    content_disp = file_response.headers.get('Content-Disposition', '')
                    if 'filename=' in content_disp:
                        filename = content_disp.split('filename=')[1].strip('"')
                        print(f"   Server filename: {filename}")

                    print("\n=== INTEGRATION COMPLETE ===")
                    print("✅ Sale recorded in database")
                    print("✅ PDF receipt generated on backend")
                    print("✅ Receipt downloaded automatically")
                    print("✅ No frontend HTML receipt needed")
                    print("\nThis demonstrates how the backend PDF infrastructure")
                    print("replaces the frontend JavaScript receipt generation!")

                else:
                    print(f"❌ PDF generation failed: {pdf_response.status_code}")
                    print(f"Response: {pdf_response.text}")
            else:
                print("❌ Failed to create sale record")
                print(f"Response: {result}")
        else:
            print(f"❌ Sale submission failed: {response.status_code}")
            print(f"Response: {response.text}")

    except Exception as e:
        print(f"❌ Error during sales flow: {e}")

def demonstrate_frontend_integration():
    """
    Shows how the frontend JavaScript would be modified to use backend PDF
    """
    print("\n" + "="*60)
    print("FRONTEND INTEGRATION EXAMPLE")
    print("="*60)

    frontend_code = '''
// Modified add_sale_record() function in main.js
function add_sale_record() {
    // ... existing code ...

    fetch('/add_sale_record', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(payload)
    })
    .then(resp => resp.json())
    .then(data => {
        if (data.status && data.sale_record) {
            console.log('Sale recorded successfully');

            // NEW: Automatically download PDF receipt
            const saleId = data.sale_record.id;
            const pdfUrl = `/download-sale-receipt/${saleId}`;

            // Trigger browser download (replaces printJS HTML printing)
            const link = document.createElement('a');
            link.href = pdfUrl;
            link.download = `receipt_${data.sale_record.uid}.pdf`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            // Show success message instead of print button
            flash_message("Sale completed! Receipt downloaded.");
        } else {
            flash_message("Sale recording failed");
        }
    });
}

// Remove print_sale_receipt() function - no longer needed
// Remove printJS library inclusion
'''

    print("Modified frontend JavaScript:")
    print(frontend_code)

if __name__ == "__main__":
    test_sales_flow_with_backend_pdf()
    demonstrate_frontend_integration()

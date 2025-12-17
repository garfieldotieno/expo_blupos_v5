#!/usr/bin/env python3

import requests
import json
from datetime import datetime

# Test PDF generation
def test_pdf_generation():
    # First, let's create a test sale record
    test_data = {
        "sale_clerk": "Test Clerk",
        "sale_total": 100.0,
        "sale_paid_amount": 100.0,
        "sale_balance": 0.0,
        "payment_method": "CASH",
        "payment_reference": "TEST123",
        "payment_gateway": "0000-0000",
        "items_array": ["3:Royal Strawberry Yoghurt 500ml:100.0"]
    }

    # Try to add a sale record first
    try:
        response = requests.post('http://localhost:8080/add_sale_record', json=test_data)
        if response.status_code == 200:
            result = response.json()
            if result.get('status') and result.get('sale_record'):
                sale_id = result['sale_record']['id']
                print(f"Created sale record with ID: {sale_id}")

                # Now try to download the PDF
                pdf_response = requests.get(f'http://localhost:8080/download-sale-receipt/{sale_id}')
                if pdf_response.status_code == 200:
                    # Save the PDF
                    with open('test_receipt.pdf', 'wb') as f:
                        f.write(pdf_response.content)
                    print("PDF generated successfully! Saved as test_receipt.pdf")
                else:
                    print(f"PDF generation failed: {pdf_response.status_code}")
            else:
                print("Failed to create sale record")
        else:
            print(f"Failed to create sale record: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_pdf_generation()

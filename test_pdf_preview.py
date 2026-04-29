#!/usr/bin/env python3

# Test script to debug PDF preview generation

import sys
import os
sys.path.append('.')

def test_pdf_generation():
    try:
        print("Testing PDF generation...")

        # Test imports
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
        from reportlab.lib import colors
        from reportlab.lib.units import inch
        from io import BytesIO
        print("✓ ReportLab imports successful")

        # Test shop data loading
        def load_shop_data():
            import json
            json_file = open("shop_config.json")
            data = json.load(json_file)
            return data

        shop_data = load_shop_data()
        print(f"✓ Shop data loaded: {shop_data.get('pos_shop_name', 'Unknown')}")

        # Test PDF generation with sample data
        clerk = "Test Clerk"
        total = 280.0
        transaction_code = "1234567890"
        items_data = ['10:Raha Cocoa 100g:140', '10:Raha Cocoa 100g:140']

        print(f"Test data: clerk={clerk}, total={total}, code={transaction_code}")
        print(f"Items: {items_data}")

        # Create PDF buffer
        pdf_buffer = BytesIO()
        doc = SimpleDocTemplate(pdf_buffer, pagesize=(2.28*inch, 11*inch),
                               leftMargin=0.05*inch, rightMargin=0.05*inch,
                               topMargin=0.1*inch, bottomMargin=0.1*inch)

        styles = getSampleStyleSheet()
        title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=10, alignment=1, spaceAfter=3, leftIndent=0, rightIndent=0)
        normal_style = ParagraphStyle('Normal', parent=styles['Normal'], fontSize=7, leading=8, leftIndent=0, rightIndent=0)
        item_style = ParagraphStyle('Item', parent=styles['Normal'], fontSize=6, leading=7, fontName='Courier', leftIndent=0, rightIndent=0)
        center_style = ParagraphStyle('Center', parent=styles['Normal'], fontSize=7, alignment=1, leftIndent=0, rightIndent=0)

        story = []

        # Header
        story.append(Paragraph(shop_data['pos_shop_name'], title_style))
        story.append(Paragraph(shop_data['shop_adress'], normal_style))
        story.append(Paragraph(f"Tel: {shop_data['pos_shop_call_number']}", normal_style))

        # Preview notice
        story.append(Paragraph("*** RECEIPT PREVIEW ***", center_style))
        story.append(Paragraph(f"Served by: {clerk}", normal_style))
        story.append(Spacer(1, 3))

        # Transaction info
        story.append(Paragraph(f"Transaction: {transaction_code}", center_style))
        story.append(Paragraph("-" * 20, center_style))

        # Items section
        if items_data:
            print(f"Processing {len(items_data)} items...")
            for item_str in items_data:
                print(f"Processing item: {item_str}")
                parts = item_str.split(':')
                if len(parts) >= 3:
                    item_name = parts[1]
                    try:
                        item_price = float(parts[2])
                        display_name = item_name[:18] + ('...' if len(item_name) > 18 else '')
                        item_text = f"{display_name} {item_price:.2f}"
                        story.append(Paragraph(item_text, item_style))
                        print(f"Added item to PDF: {item_text}")
                    except ValueError as e:
                        print(f"Error parsing price: {e}")
                        continue
                else:
                    print(f"Invalid item format: {item_str}")
        else:
            story.append(Paragraph("No items in cart", item_style))
            print("No items to display")

        story.append(Paragraph("-" * 20, center_style))
        story.append(Paragraph(f"Total: KES {total:.2f}", center_style))

        # Footer
        story.append(Spacer(1, 5))
        story.append(Paragraph("Preview Mode", center_style))
        story.append(Paragraph("Payment info added after", center_style))
        story.append(Paragraph("checkout completion", center_style))

        # Build PDF
        doc.build(story)
        pdf_buffer.seek(0)

        pdf_size = len(pdf_buffer.getvalue())
        print(f"✓ PDF generated successfully! Size: {pdf_size} bytes")

        # Save test PDF
        with open('test_receipt_preview.pdf', 'wb') as f:
            f.write(pdf_buffer.getvalue())
        print("✓ Test PDF saved as test_receipt_preview.pdf")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_pdf_generation()

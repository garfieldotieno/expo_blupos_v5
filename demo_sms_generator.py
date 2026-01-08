#!/usr/bin/env python3
"""
Demo script for SMS Generator functionality
Shows sample output without interactive mode
"""

from sms_generator import SMSGenerator
from datetime import datetime

def demo_sms_generation():
    """Demonstrate SMS generation for both channels with realistic formats"""

    print("🚀 BluPOS SMS Payment Generator Demo")
    print("=" * 50)

    generator = SMSGenerator()

    # Demo Channel 80872 - With 10-Char Serial Code
    print("\n📱 Channel 80872 - Jaystar Investments Ltd (with 10-char serial code)")
    print("-" * 65)
    sms_80872 = generator.generate_sms('80872', '130.00')
    serial_code = sms_80872.split('~')[0]
    print(f"Amount: KES 130.00")
    print(f"Serial Code: {serial_code}~ (length: {len(serial_code)} chars)")
    print(f"Generated SMS: {sms_80872}")

    # Demo Channel 57938 - With Hidden Phone & 10-Char Reference
    print("\n📱 Channel 57938 - Merchant Account (with hidden phone & 10-char ref)")
    print("-" * 70)
    sms_57938 = generator.generate_sms('57938', '50.00')
    # Extract reference
    import re
    ref_match = re.search(r'ref #([A-Z0-9]+)', sms_57938)
    ref_code = ref_match.group(1) if ref_match else "N/A"
    print(f"Amount: KES 50.00")
    print(f"Reference: {ref_code} (length: {len(ref_code)} chars)")
    print(f"Generated SMS: {sms_57938}")

    # Show multiple generations to demonstrate variability
    print("\n🔄 Multiple Generations (showing randomness)")
    print("-" * 50)
    for i in range(3):
        sms = generator.generate_sms('80872', '75.50')
        serial = sms.split('~')[0]
        print(f"Generation {i+1}: Serial={serial}~ ...{sms[-40:]}")

    print("\n✅ Demo completed! Run 'python sms_generator.py' for interactive mode.")
    print("💡 Features: 10-char serial codes for 80872, 10-char refs for 57938, hidden phones, realistic timestamps!")

if __name__ == "__main__":
    demo_sms_generation()

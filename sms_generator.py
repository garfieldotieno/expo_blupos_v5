#!/usr/bin/env python3
"""
SMS Payment Message Generator for BluPOS Testing
Generates sample SMS messages for supported payment channels and scam testing

Interactive Mode:
1. Select payment channel (80872, 57938, or SCAM)
2. Enter payment amount
3. SMS message is generated and displayed
4. Option to send directly to Android emulator

Channels:
- 80872: Jaystar Investments Ltd (shortcode: 123456)
- 57938: Merchant Account (shortcode: 123457)
- SCAM: Scam messages from regular phone numbers (for testing scam prevention)

Usage: python sms_generator.py
"""

import random
import string
from datetime import datetime, timedelta
import subprocess
import sys

class SMSGenerator:
    """Interactive SMS Payment Message Generator"""

    def __init__(self):
        self.channels = {
            '80872': {
                'name': 'Jaystar Investments Ltd',
                'template': "Payment Of Kshs {amount} Has Been Received By {company} For Account {account}, From {sender} on {date} at {time}",
                'sample_senders': ['Jane Doe', 'John Smith', 'Mary Johnson', 'Robert Brown', 'Sarah Davis']
            },
            '57938': {
                'name': 'Merchant Account',
                'template': "Dear {recipient}, Your merchant account {account} has been credited with KES {amount} ref #{reference} from {sender} {phone} on {date}.",
                'sample_senders': ['John Doe', 'Alice Cooper', 'Bob Wilson', 'Carol Taylor', 'David Miller'],
                'sample_recipients': ['Jeffithah', 'Manager', 'Admin', 'Supervisor', 'Clerk']
            },
            'SCAM': {
                'name': 'Scam Message (Regular Phone Number)',
                'template': "Payment of KES {amount} has been credited to your account from {sender}. Reference: {reference}. Call {contact} to claim.",
                'sample_senders': ['Anonymous Sender', 'Payment Service', 'Bank Alert', 'Money Transfer', 'Cash App'],
                'sample_contacts': ['0712345678', '0723456789', '0734567890', '0745678901', '0756789012']
            }
        }

    def generate_sms(self, channel, amount):
        """Generate SMS message for the specified channel and amount"""
        if channel not in self.channels:
            raise ValueError(f"Unknown channel: {channel}")

        channel_info = self.channels[channel]

        # Generate current timestamp
        now = datetime.now()

        if channel == '80872':
            # Jaystar Investments Ltd format - includes serial code prefix
            sender = random.choice(channel_info['sample_senders'])
            date_str = now.strftime("%d/%m/%y")  # DD/MM/YY format
            time_str = now.strftime("%I.%M%p").lower()  # HH.MMam/pm format

            # Generate serial code (10 characters, mix of letters and numbers + tilde)
            # Matches sample: TLQ9E20B07~
            serial_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10)) + "~"

            sms = f"{serial_code}{channel_info['template'].format(
                amount=f"{float(amount):.2f}",
                company=channel_info['name'],
                account=channel,
                sender=sender,
                date=date_str,
                time=time_str
            )}"

        elif channel == '57938':
            # Merchant Account format
            sender = random.choice(channel_info['sample_senders'])
            recipient = random.choice(channel_info['sample_recipients'])

            # Generate phone number (Kenyan format, partially hidden)
            full_phone = f"254{random.randint(700, 799)}{random.randint(100000, 999999)}"
            # Hide middle digits: 254717xxx123
            phone = f"{full_phone[:6]}xxx{full_phone[-3:]}"

            # Generate reference (10 characters, mix of letters and numbers)
            # Matches sample pattern length
            reference = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))

            # Date format: DD-MMM-YYYY HH:MM:SS
            date_str = now.strftime("%d-%b-%Y %H:%M:%S")

            sms = channel_info['template'].format(
                recipient=recipient,
                account=channel,
                amount=f"{float(amount):.2f}",
                reference=reference,
                sender=sender,
                phone=phone,
                date=date_str
            )

        elif channel == 'SCAM':
            # Scam message from regular phone number - should be filtered out
            sender = random.choice(channel_info['sample_senders'])
            contact = random.choice(channel_info['sample_contacts'])

            # Generate reference (8 characters, mix of letters and numbers)
            reference = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

            sms = channel_info['template'].format(
                amount=f"{float(amount):.2f}",
                sender=sender,
                reference=reference,
                contact=contact
            )

        return sms

    def send_to_emulator(self, shortcode, sms_message):
        """Send SMS message to Android emulator using adb"""
        try:
            # Escape quotes in the message for shell
            escaped_message = sms_message.replace('"', '\\"')
            cmd = f'adb emu sms send {shortcode} "{escaped_message}"'

            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

            if result.returncode == 0:
                print(f"✅ SMS sent to emulator from shortcode {shortcode}")
                return True
            else:
                print(f"❌ Failed to send SMS: {result.stderr}")
                return False

        except Exception as e:
            print(f"❌ Error sending SMS to emulator: {e}")
            return False

    def get_shortcode_for_channel(self, channel):
        """Get the appropriate shortcode for a channel"""
        if channel == '80872':
            return '123456'
        elif channel == '57938':
            return '123457'
        elif channel == 'SCAM':
            # Generate a regular 10+ digit phone number for scam messages
            # Kenyan format: 0712345678, 0723456789, etc.
            return f'07{random.randint(10000000, 99999999)}'
        else:
            return None



def main():
    """Main entry point - Interactive SMS Generation"""
    print("""
╔══════════════════════════════════════════════════════════════╗
║                  BluPOS SMS Payment Generator                 ║
║                                                              ║
║  Generate sample SMS messages for testing payment channels   ║
║  Supported Channels: 80872 (Jaystar), 57938 (Merchant), SCAM ║
╚══════════════════════════════════════════════════════════════╝
""")

    generator = SMSGenerator()

    try:
        while True:
            print("\n" + "=" * 50)
            print("📱 SMS Payment Message Generator")
            print("=" * 50)

            # Channel selection
            print("\nAvailable Payment Channels:")
            for channel_id, info in generator.channels.items():
                print(f"  {channel_id}: {info['name']}")

            # Get channel selection
            while True:
                try:
                    channel = input("\nSelect channel (80872/57938/SCAM) or 'quit' to exit: ").strip().upper()
                    if channel == 'QUIT':
                        print("\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                        return
                    if channel in generator.channels:
                        break
                    else:
                        print("❌ Invalid channel. Please select 80872, 57938, or SCAM.")
                except KeyboardInterrupt:
                    print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                    return

            # Amount input
            while True:
                try:
                    amount = input("Enter payment amount (e.g., 130.00): ").strip()
                    # Validate amount format
                    float(amount)
                    break
                except ValueError:
                    print("❌ Invalid amount format. Please enter a number (e.g., 130.00).")
                except KeyboardInterrupt:
                    print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                    return

            # Generate SMS message
            sms_message = generator.generate_sms(channel, amount)

            print("\n" + "=" * 70)
            print("� GENERATED SMS MESSAGE:")
            print("=" * 70)
            print(f"Channel: {channel.upper()}")
            print(f"Amount: KES {amount}")
            print(f"Message: {sms_message}")
            print("=" * 70)

            # Copy to clipboard option
            try:
                import pyperclip
                copy_choice = input("\nCopy to clipboard? (y/n) [n]: ").strip().lower()
                if copy_choice in ['y', 'yes']:
                    pyperclip.copy(sms_message)
                    print("✅ SMS message copied to clipboard!")
            except ImportError:
                print("\n💡 Install 'pyperclip' for clipboard functionality: pip install pyperclip")
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                return
            except Exception:
                pass

            # Send to emulator option
            shortcode = generator.get_shortcode_for_channel(channel)
            if shortcode:
                try:
                    send_choice = input(f"\nSend to emulator (shortcode {shortcode})? (y/n) [n]: ").strip().lower()
                    if send_choice in ['y', 'yes']:
                        success = generator.send_to_emulator(shortcode, sms_message)
                        if success:
                            print("📱 SMS sent to emulator - check your Flutter app!")
                except KeyboardInterrupt:
                    print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                    return
                except Exception:
                    pass

            print("\n✅ SMS message generated successfully!")

            # Ask if user wants to generate another
            try:
                again = input("\nGenerate another SMS? (y/n) [y]: ").strip().lower()
                if again in ['n', 'no']:
                    print("\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                    break
            except KeyboardInterrupt:
                print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
                break

    except KeyboardInterrupt:
        print("\n\n👋 Goodbye! Happy testing with BluPOS SMS payments.\n")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()

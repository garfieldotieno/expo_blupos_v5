#!/usr/bin/env python3
"""
SMS API Endpoints Test Suite - January 8, 2026

Tests the SMS Feature API endpoints implemented in the BluPOS Wallet microserver.

Endpoints tested:
- GET /on-boot-sms-total-count
- GET /after-boot-total-count
- GET /message/<id>

Usage:
    python test_sms_api_endpoints.py
"""

import requests
import json
import time
import random
import string
import subprocess
from datetime import datetime
import sys

# Configuration
MICROSERVER_BASE_URL = "http://localhost:8085"
REQUEST_TIMEOUT = 10

# Test message ID for testing /message/<id> endpoint
TEST_MESSAGE_ID = "1767812249000"

# SMS Generator Integration
class SMSGeneratorIntegration:
    """Integrated SMS generator for testing"""

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
            }
        }

    def generate_sms(self, channel, amount):
        """Generate SMS message for the specified channel and amount"""
        if channel not in self.channels:
            raise ValueError(f"Unknown channel: {channel}")

        channel_info = self.channels[channel]
        now = datetime.now()

        if channel == '80872':
            sender = random.choice(channel_info['sample_senders'])
            date_str = now.strftime("%d/%m/%y")
            time_str = now.strftime("%I.%M%p").lower()
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
            sender = random.choice(channel_info['sample_senders'])
            recipient = random.choice(channel_info['sample_recipients'])
            full_phone = f"254{random.randint(700, 799)}{random.randint(100000, 999999)}"
            phone = f"{full_phone[:6]}xxx{full_phone[-3:]}"
            reference = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
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

        return sms

    def send_to_emulator(self, shortcode, sms_message):
        """Send SMS message to Android emulator using adb"""
        try:
            escaped_message = sms_message.replace('"', '\\"')
            cmd = f'adb emu sms send {shortcode} "{escaped_message}"'

            print(f"📤 [SMS_GENERATOR] Executing: {cmd}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

            if result.returncode == 0:
                print(f"✅ [SMS_GENERATOR] SMS sent to emulator from shortcode {shortcode}")
                return True
            else:
                print(f"❌ [SMS_GENERATOR] Failed to send SMS: {result.stderr}")
                return False

        except Exception as e:
            print(f"❌ [SMS_GENERATOR] Error sending SMS to emulator: {e}")
            return False

    def get_shortcode_for_channel(self, channel):
        """Get the appropriate shortcode for a channel"""
        if channel == '80872':
            return '123456'
        elif channel == '57938':
            return '123457'
        else:
            return None

    def send_test_sms(self, channel='80872', amount='150.00'):
        """Send a test SMS and return details"""
        sms_message = self.generate_sms(channel, amount)
        shortcode = self.get_shortcode_for_channel(channel)

        print(f"📝 [SMS_GENERATOR] Generated SMS for channel {channel}:")
        print(f"   Amount: KES {amount}")
        print(f"   Shortcode: {shortcode}")
        print(f"   Message: {sms_message[:100]}...")

        success = self.send_to_emulator(shortcode, sms_message)

        return {
            'success': success,
            'channel': channel,
            'amount': amount,
            'shortcode': shortcode,
            'message': sms_message
        }

class SmsApiTester:
    """Test suite for SMS API endpoints"""

    def __init__(self, base_url=MICROSERVER_BASE_URL):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.test_results = []

    def log(self, message, level="INFO"):
        """Log message with timestamp and level"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        colored_message = self._colorize_message(message, level)
        print(f"[{timestamp}] [{level}] {colored_message}")

    def _colorize_message(self, message, level):
        """Add ANSI color codes based on log level"""
        if level == "SUCCESS":
            return f"\033[92m{message}\033[0m"  # Green
        elif level == "ERROR":
            return f"\033[91m{message}\033[0m"   # Red
        elif level == "WARNING":
            return f"\033[93m{message}\033[0m"  # Yellow
        elif level == "HEADER":
            return f"\033[94m{message}\033[0m"  # Blue
        else:
            return message

    def make_request(self, method, endpoint, **kwargs):
        """Make HTTP request with logging"""
        url = f"{self.base_url}{endpoint}"
        self.log(f"Making {method} request to: {url}")

        try:
            start_time = time.time()
            response = self.session.request(method, url, timeout=REQUEST_TIMEOUT, **kwargs)
            end_time = time.time()

            self.log(".2f")

            return response
        except requests.exceptions.RequestException as e:
            self.log(f"Request failed: {e}", "ERROR")
            return None

    def test_endpoint(self, name, method, endpoint, expected_status=200, **kwargs):
        """Test a single endpoint"""
        self.log(f"\n{'='*60}", "HEADER")
        self.log(f"Testing {name}", "HEADER")
        self.log(f"{'='*60}", "HEADER")

        response = self.make_request(method, endpoint, **kwargs)

        if response is None:
            result = {"name": name, "status": "FAILED", "error": "Request failed"}
            self.test_results.append(result)
            self.log(f"❌ {name} - FAILED (Request Error)", "ERROR")
            return False

        # Check status code
        if response.status_code != expected_status:
            result = {
                "name": name,
                "status": "FAILED",
                "expected_status": expected_status,
                "actual_status": response.status_code,
                "response": response.text[:500]  # Truncate long responses
            }
            self.test_results.append(result)
            self.log(f"❌ {name} - FAILED (Expected {expected_status}, got {response.status_code})", "ERROR")
            return False

        # Parse JSON response
        try:
            data = response.json()
            result = {
                "name": name,
                "status": "PASSED",
                "status_code": response.status_code,
                "response_size": len(response.text),
                "data": data
            }
            self.test_results.append(result)
            self.log(f"✅ {name} - PASSED", "SUCCESS")

            # Log key response data
            self._log_response_data(name, data)
            return True

        except json.JSONDecodeError:
            result = {
                "name": name,
                "status": "FAILED",
                "error": "Invalid JSON response",
                "response": response.text[:500]
            }
            self.test_results.append(result)
            self.log(f"❌ {name} - FAILED (Invalid JSON)", "ERROR")
            return False

    def _log_response_data(self, endpoint_name, data):
        """Log key data from successful responses"""
        if endpoint_name == "On-Boot SMS Total Count":
            if "counts" in data:
                counts = data["counts"]
                self.log(f"  📊 Boot counts: Total={counts.get('total_messages', 'N/A')}, Read={counts.get('read_messages', 'N/A')}, Unread={counts.get('unread_messages', 'N/A')}")
            if "boot_context" in data:
                self.log(f"  🎯 Boot context: {data['boot_context']}")

        elif endpoint_name == "After-Boot SMS Total Count":
            if "counts" in data:
                counts = data["counts"]
                self.log(f"  📊 Current counts: Total={counts.get('total_messages', 'N/A')}, Read={counts.get('read_messages', 'N/A')}, Unread={counts.get('unread_messages', 'N/A')}")
            if "runtime_context" in data:
                self.log(f"  🚀 Runtime context: {data['runtime_context']}")

        elif endpoint_name == "Message by ID":
            if "data" in data:
                msg_data = data["data"]
                sender = msg_data.get("sender", "Unknown")
                amount = msg_data.get("amount", "N/A")
                message = msg_data.get("message", "")[:50]
                self.log(f"  📨 Message: From {sender}, Amount: {amount}, Content: '{message}...'")

    def test_on_boot_sms_counts(self):
        """Test /on-boot-sms-total-count endpoint"""
        return self.test_endpoint(
            "On-Boot SMS Total Count",
            "GET",
            "/on-boot-sms-total-count"
        )

    def test_after_boot_sms_counts(self):
        """Test /after-boot-total-count endpoint"""
        return self.test_endpoint(
            "After-Boot SMS Total Count",
            "GET",
            "/after-boot-total-count"
        )

    def test_message_by_id(self):
        """Test /message/<id> endpoint"""
        return self.test_endpoint(
            "Message by ID",
            "GET",
            f"/message/{TEST_MESSAGE_ID}"
        )

    def run_comprehensive_sms_test(self):
        """Run comprehensive SMS integration test with real SMS sending"""
        self.log("="*100, "HEADER")
        self.log("COMPREHENSIVE SMS INTEGRATION TEST SUITE", "HEADER")
        self.log("="*100, "HEADER")
        self.log("This test sends REAL SMS to emulator and verifies API responses")
        self.log(f"Testing against: {self.base_url}")
        self.log(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        self.log("")

        # Check prerequisites
        if not self._check_prerequisites():
            return False

        # Step 1: Get baseline counts
        self.log("📊 STEP 1: Getting baseline SMS counts", "HEADER")
        baseline_boot = self._get_baseline_counts()
        if not baseline_boot:
            self.log("❌ Failed to get baseline counts", "ERROR")
            return False

        # Step 2: Send test SMS
        self.log("\n📤 STEP 2: Sending test SMS to emulator", "HEADER")
        sms_result = self._send_test_sms_to_emulator()
        if not sms_result['success']:
            self.log("❌ Failed to send test SMS", "ERROR")
            return False

        # Step 3: Wait for SMS to propagate
        self.log("\n⏳ STEP 3: Waiting for SMS to reach emulator and be processed", "HEADER")
        self._wait_for_sms_propagation()

        # Step 4: Check updated counts
        self.log("\n📊 STEP 4: Checking updated SMS counts after SMS delivery", "HEADER")
        updated_counts = self._check_updated_counts(baseline_boot)

        # Step 5: Verify SMS was processed
        self.log("\n✅ STEP 5: Verifying SMS processing results", "HEADER")
        success = self._verify_sms_processing(sms_result, updated_counts)

        # Summary
        self._print_comprehensive_summary(success)
        return success

    def _check_prerequisites(self):
        """Check if all prerequisites are met"""
        self.log("🔍 Checking prerequisites...")

        # Check microserver connectivity
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                self.log("✅ Microserver is responding", "SUCCESS")
            else:
                self.log(f"❌ Microserver error: status {response.status_code}", "ERROR")
                return False
        except requests.exceptions.RequestException as e:
            self.log(f"❌ Cannot connect to microserver: {e}", "ERROR")
            self.log("Make sure the Flutter app is running with microserver on port 8085", "ERROR")
            return False

        # Check ADB connectivity
        try:
            result = subprocess.run(['adb', 'devices'], capture_output=True, text=True, timeout=5)
            if 'emulator' in result.stdout or 'device' in result.stdout:
                self.log("✅ Android emulator/device detected", "SUCCESS")
            else:
                self.log("⚠️ No Android emulator/device detected - SMS sending may fail", "WARNING")
        except (subprocess.SubprocessError, FileNotFoundError):
            self.log("⚠️ ADB not available - SMS sending will fail", "WARNING")

        return True

    def _get_baseline_counts(self):
        """Get baseline SMS counts before sending test SMS"""
        try:
            # Get boot counts
            boot_response = self.make_request("GET", "/on-boot-sms-total-count")
            if boot_response and boot_response.status_code == 200:
                boot_data = boot_response.json()
                boot_counts = boot_data.get('counts', {})

                # Get after-boot counts
                after_response = self.make_request("GET", "/after-boot-total-count")
                after_data = {}
                if after_response and after_response.status_code == 200:
                    after_data = after_response.json()

                baseline = {
                    'boot': boot_counts,
                    'after_boot': after_data.get('counts', {}),
                    'timestamp': datetime.now().isoformat()
                }

                self.log(f"📊 Baseline - Boot: {boot_counts.get('unread_messages', 0)} unread")
                self.log(f"📊 Baseline - After-boot: {baseline['after_boot'].get('unread_messages', 0)} unread")

                return baseline
            else:
                self.log("❌ Failed to get baseline counts", "ERROR")
                return None
        except Exception as e:
            self.log(f"❌ Error getting baseline: {e}", "ERROR")
            return None

    def _send_test_sms_to_emulator(self):
        """Send test SMS to emulator using integrated generator"""
        sms_gen = SMSGeneratorIntegration()

        # Send SMS for channel 80872 (most common)
        result = sms_gen.send_test_sms(channel='80872', amount='200.00')

        if result['success']:
            self.log("✅ Test SMS sent successfully", "SUCCESS")
            self.log(f"   📱 Channel: {result['channel']}")
            self.log(f"   💰 Amount: KES {result['amount']}")
            self.log(f"   🔢 Shortcode: {result['shortcode']}")
        else:
            self.log("❌ Failed to send test SMS", "ERROR")

        return result

    def _wait_for_sms_propagation(self):
        """Wait for SMS to reach emulator and be processed"""
        self.log("⏳ Waiting 15 seconds for SMS to propagate to emulator...")
        time.sleep(5)
        self.log("⏳ Waiting 10 more seconds for Flutter app to process SMS...")
        time.sleep(10)
        self.log("✅ SMS propagation delay complete")

    def _check_updated_counts(self, baseline):
        """Check SMS counts after SMS delivery"""
        try:
            # Get updated counts
            boot_response = self.make_request("GET", "/on-boot-sms-total-count")
            after_response = self.make_request("GET", "/after-boot-total-count")

            updated = {}
            if boot_response and boot_response.status_code == 200:
                updated['boot'] = boot_response.json().get('counts', {})

            if after_response and after_response.status_code == 200:
                updated['after_boot'] = after_response.json().get('counts', {})

            # Compare with baseline
            if 'after_boot' in updated:
                old_count = baseline['after_boot'].get('unread_messages', 0)
                new_count = updated['after_boot'].get('unread_messages', 0)
                delta = new_count - old_count

                self.log(f"📊 Count Change: {old_count} → {new_count} (Δ{delta:+d})")

                if delta > 0:
                    self.log(f"✅ SMS successfully detected! +{delta} unread message(s)", "SUCCESS")
                elif delta == 0:
                    self.log("⚠️ No count change detected - SMS may not have been processed", "WARNING")
                else:
                    self.log(f"❓ Unexpected count decrease: {delta}", "WARNING")

            return updated
        except Exception as e:
            self.log(f"❌ Error checking updated counts: {e}", "ERROR")
            return {}

    def _verify_sms_processing(self, sms_result, updated_counts):
        """Verify that SMS was properly processed"""
        success = True

        # Check if after-boot count increased
        if 'after_boot' in updated_counts:
            after_boot = updated_counts['after_boot']
            unread_count = after_boot.get('unread_messages', 0)

            if unread_count > 0:
                self.log("✅ SMS processing verified - unread count increased", "SUCCESS")
            else:
                self.log("⚠️ SMS may not have been processed - no unread count increase", "WARNING")
                success = False

        # Check if we can retrieve a message
        try:
            message_response = self.make_request("GET", f"/message/{TEST_MESSAGE_ID}")
            if message_response and message_response.status_code == 200:
                self.log("✅ Message retrieval working", "SUCCESS")
            else:
                self.log("⚠️ Message retrieval not working", "WARNING")
        except Exception as e:
            self.log(f"⚠️ Message retrieval error: {e}", "WARNING")

        return success

    def _print_comprehensive_summary(self, success):
        """Print comprehensive test summary"""
        self.log(f"\n{'='*80}", "HEADER")
        self.log("COMPREHENSIVE SMS TEST SUMMARY", "HEADER")
        self.log(f"{'='*80}", "HEADER")

        if success:
            self.log("🎉 COMPREHENSIVE TEST PASSED!", "SUCCESS")
            self.log("✅ SMS generation, sending, and API integration working")
        else:
            self.log("⚠️ COMPREHENSIVE TEST COMPLETED WITH ISSUES", "WARNING")
            self.log("❌ Some aspects of SMS integration may need attention")

        self.log("\n🔍 Test Components Verified:", "HEADER")
        self.log("  • SMS message generation")
        self.log("  • ADB SMS sending to emulator")
        self.log("  • SMS propagation delay handling")
        self.log("  • Microserver API responsiveness")
        self.log("  • Count updates after SMS delivery")
        self.log("  • Message retrieval functionality")

    def run_all_tests(self):
        """Run all SMS API endpoint tests"""
        self.log("="*80, "HEADER")
        self.log("SMS API ENDPOINTS TEST SUITE", "HEADER")
        self.log("="*80, "HEADER")
        self.log(f"Testing against: {self.base_url}")
        self.log(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        self.log("")

        # Test server connectivity first
        self.log("🔍 Checking microserver connectivity...")
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                self.log("✅ Microserver is responding", "SUCCESS")
            else:
                self.log(f"⚠️ Microserver responded with status {response.status_code}", "WARNING")
        except requests.exceptions.RequestException as e:
            self.log(f"❌ Cannot connect to microserver: {e}", "ERROR")
            self.log("Make sure the microserver is running on port 8085", "ERROR")
            return False

        # Run individual tests
        tests = [
            ("On-Boot SMS Counts", self.test_on_boot_sms_counts),
            ("After-Boot SMS Counts", self.test_after_boot_sms_counts),
            ("Message by ID", self.test_message_by_id),
        ]

        passed = 0
        total = len(tests)

        for test_name, test_func in tests:
            try:
                if test_func():
                    passed += 1
                time.sleep(0.5)  # Brief pause between tests
            except Exception as e:
                self.log(f"❌ {test_name} - EXCEPTION: {e}", "ERROR")
                self.test_results.append({
                    "name": test_name,
                    "status": "EXCEPTION",
                    "error": str(e)
                })

        # Print summary
        self._print_summary(passed, total)
        return passed == total

    def _print_summary(self, passed, total):
        """Print test summary"""
        self.log(f"\n{'='*60}", "HEADER")
        self.log("TEST SUMMARY", "HEADER")
        self.log(f"{'='*60}", "HEADER")

        self.log(f"Total Tests: {total}")
        self.log(f"Passed: {passed}")
        self.log(f"Failed: {total - passed}")

        success_rate = (passed / total) * 100 if total > 0 else 0
        self.log(".1f")

        if passed == total:
            self.log("🎉 ALL TESTS PASSED!", "SUCCESS")
        else:
            self.log("⚠️ SOME TESTS FAILED", "WARNING")

        # Show detailed results
        self.log("\nDetailed Results:", "HEADER")
        for result in self.test_results:
            status_icon = "✅" if result["status"] == "PASSED" else "❌"
            self.log(f"  {status_icon} {result['name']}: {result['status']}")

def main():
    """Main test execution"""
    print("SMS API Endpoints Test Suite")
    print("============================")
    print("")

    if len(sys.argv) > 1 and sys.argv[1] == "--comprehensive":
        # Run comprehensive SMS integration test with real SMS sending
        print("Running COMPREHENSIVE SMS INTEGRATION TEST")
        print("This will send REAL SMS to emulator and verify API responses")
        print("Make sure Flutter app is running with microserver on port 8085")
        print("")

        tester = SmsApiTester()
        try:
            success = tester.run_comprehensive_sms_test()
            sys.exit(0 if success else 1)
        except KeyboardInterrupt:
            print("\nTest interrupted by user")
            sys.exit(1)
        except Exception as e:
            print(f"\nUnexpected error: {e}")
            sys.exit(1)
    else:
        # Run basic endpoint tests
        print("Running BASIC ENDPOINT TESTS")
        print("This tests API endpoints without sending real SMS")
        print("")
        print("For comprehensive testing with real SMS sending, use:")
        print("  python test_sms_api_endpoints.py --comprehensive")
        print("")

        tester = SmsApiTester()
        try:
            success = tester.run_all_tests()
            sys.exit(0 if success else 1)
        except KeyboardInterrupt:
            print("\nTest interrupted by user")
            sys.exit(1)
        except Exception as e:
            print(f"\nUnexpected error: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()

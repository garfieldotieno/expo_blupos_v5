#!/usr/bin/env python3
"""
Standalone SMS API Test Microserver - January 8, 2026

Simple HTTP server to test SMS API endpoints without requiring the full Flutter app.

Endpoints:
- GET /on-boot-sms-total-count
- GET /after-boot-total-count
- GET /message/<id>
"""

import json
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse
import signal
import sys

class SMSAPITestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for SMS API endpoints"""

    def log_message(self, format, *args):
        """Override logging to use our format"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] [HTTP] {format % args}")

    def do_GET(self):
        """Handle GET requests"""
        try:
            # Parse the path
            parsed_path = urllib.parse.urlparse(self.path)
            path = parsed_path.path

            print(f"\n📡 [API] Received GET request: {path}")

            # Route to appropriate handler
            if path == "/on-boot-sms-total-count":
                self.handle_on_boot_counts()
            elif path == "/after-boot-total-count":
                self.handle_after_boot_counts()
            elif path.startswith("/message/"):
                message_id = path.split("/message/")[-1]
                self.handle_message_by_id(message_id)
            elif path == "/health":
                self.handle_health_check()
            else:
                self.send_error_response(404, f"Endpoint not found: {path}")

        except Exception as e:
            print(f"❌ [API] Error handling request: {e}")
            self.send_error_response(500, str(e))

    def handle_on_boot_counts(self):
        """Handle /on-boot-sms-total-count"""
        print("📱 [API] Processing on-boot SMS counts request")

        response_data = {
            "status": "success",
            "context": "on_boot",
            "timestamp": datetime.now().isoformat(),
            "counts": {
                "total_messages": 12,
                "read_messages": 10,
                "unread_messages": 2,
                "payment_messages": 1,
                "system_messages": 3
            },
            "breakdown": {
                "opened": 10,
                "unopened": 2,
                "payment_opened": 1,
                "payment_unopened": 0
            },
            "sources": ["inbox"],
            "last_updated": datetime.now().isoformat(),
            "boot_context": {
                "captured_at": "app_initialization",
                "includes_existing_inbox": True,
                "excludes_runtime_messages": True,
                "represents_baseline": True
            }
        }

        self.send_json_response(response_data)
        print("📊 [API] On-boot counts: Total=12, Read=10, Unread=2")

    def handle_after_boot_counts(self):
        """Handle /after-boot-total-count"""
        print("📱 [API] Processing after-boot SMS counts request")

        response_data = {
            "status": "success",
            "context": "after_boot",
            "timestamp": datetime.now().isoformat(),
            "counts": {
                "total_messages": 15,
                "read_messages": 8,
                "unread_messages": 7,
                "payment_messages": 3,
                "system_messages": 2
            },
            "breakdown": {
                "opened": 8,
                "unopened": 7,
                "payment_opened": 2,
                "payment_unopened": 1
            },
            "sources": ["inbox", "incoming_broadcast", "payment_broadcast"],
            "last_updated": datetime.now().isoformat(),
            "runtime_context": {
                "includes_runtime_messages": True,
                "reflects_current_state": True,
                "shows_accumulated_activity": True
            }
        }

        self.send_json_response(response_data)
        print("📊 [API] After-boot counts: Total=15, Read=8, Unread=7")

    def handle_message_by_id(self, message_id):
        """Handle /message/<id>"""
        print(f"📱 [API] Processing message request for ID: {message_id}")

        # Mock message data
        mock_messages = {
            "1767812249000": {
                "id": "1767812249000",
                "sender": "+254700123456",
                "message": "Payment Of Kshs 150.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From John Smith on 07/01/26 at 09.57pm",
                "timestamp": 1767812249000,
                "read": False,
                "amount": 150.0,
                "reference": "YL4ZEC9B6Y",
                "source": "payment_broadcast",
                "channel": "80872"
            }
        }

        if message_id in mock_messages:
            response_data = {
                "status": "success",
                "message_id": message_id,
                "data": mock_messages[message_id],
                "metadata": {
                    "retrieved_at": datetime.now().isoformat(),
                    "cache_status": "live",
                    "source": "sms_service"
                }
            }
            self.send_json_response(response_data)
            msg_data = mock_messages[message_id]
            print(f"📨 [API] Found message: From {msg_data['sender']}, Amount: {msg_data['amount']}")
        else:
            self.send_error_response(404, f"Message not found: {message_id}")

    def handle_health_check(self):
        """Handle /health"""
        response_data = {
            "status": "ok",
            "timestamp": datetime.now().isoformat(),
            "server": "SMS API Test Microserver",
            "version": "1.0.0",
            "port": 8085,
            "endpoints": [
                "/on-boot-sms-total-count",
                "/after-boot-total-count",
                "/message/<id>",
                "/health"
            ]
        }
        self.send_json_response(response_data)

    def send_json_response(self, data, status_code=200):
        """Send JSON response"""
        response_json = json.dumps(data, indent=2)
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Content-Length', str(len(response_json)))
        self.end_headers()
        self.wfile.write(response_json.encode('utf-8'))

    def send_error_response(self, status_code, message):
        """Send error response"""
        error_data = {
            "status": "error",
            "message": message,
            "timestamp": datetime.now().isoformat()
        }
        self.send_json_response(error_data, status_code)

    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print("\n🛑 Received shutdown signal, stopping server...")
    sys.exit(0)

def run_server(port=8085):
    """Run the test microserver"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, SMSAPITestHandler)

    print("SMS API Test Microserver")
    print("========================")
    print(f"Starting server on port {port}")
    print(f"Local URL: http://localhost:{port}")
    print("Available endpoints:")
    print("  GET /on-boot-sms-total-count")
    print("  GET /after-boot-total-count")
    print("  GET /message/<id>")
    print("  GET /health")
    print("")
    print("Press Ctrl+C to stop")
    print("")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped")
    finally:
        httpd.shutdown()

def main():
    """Main entry point"""
    # Register signal handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        run_server()
    except Exception as e:
        print(f"❌ Server error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

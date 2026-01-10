#!/usr/bin/env python3
"""
Standalone Micro-Server for BluPOS
Runs the micro-server independently for testing endpoints

Usage:
    python standalone_microserver.py
"""

import asyncio
import json
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse

class MicroServerHandler(BaseHTTPRequestHandler):
    """HTTP request handler for micro-server endpoints"""

    def __init__(self, *args, **kwargs):
        # Mock SMS data for testing
        self.mock_sms_data = {
            'shortcodes': [
                {
                    'id': '1767812249001',
                    'sender': '123456',
                    'message': 'Payment Of Kshs 150.00 Has Been Received By Jaystar Investments Ltd For Account 80872',
                    'timestamp': int(datetime.now().timestamp() * 1000) - 3600000,
                    'read': True,
                    'channel': '80872',
                    'source': 'shortcode_approved'
                },
                {
                    'id': '1767812249002',
                    'sender': '123457',
                    'message': 'Your merchant account 57938 has been credited with KES 200.00',
                    'timestamp': int(datetime.now().timestamp() * 1000) - 1800000,
                    'read': False,
                    'channel': '57938',
                    'source': 'shortcode_approved'
                }
            ],
            'non_shortcodes': [
                {
                    'id': '1767812249003',
                    'sender': '0712345678',
                    'message': 'Payment of KES 500.00 has been credited to your account. Call 0723456789 to claim.',
                    'timestamp': int(datetime.now().timestamp() * 1000) - 900000,
                    'read': False,
                    'channel': 'unknown',
                    'source': 'regular_phone_rejected',
                    'rejection_reason': 'Not from approved shortcode'
                }
            ],
            'read': [
                {
                    'id': '1767812249004',
                    'sender': '123456',
                    'message': 'Payment confirmation received',
                    'timestamp': int(datetime.now().timestamp() * 1000) - 7200000,
                    'read': True,
                    'channel': '80872',
                    'source': 'read_message'
                }
            ],
            'unread': [
                {
                    'id': '1767812249005',
                    'sender': '123457',
                    'message': 'New payment received: KES 300.00',
                    'timestamp': int(datetime.now().timestamp() * 1000) - 300000,
                    'read': False,
                    'channel': '57938',
                    'source': 'unread_message'
                }
            ]
        }
        super().__init__(*args, **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        print(f"📨 GET {self.path}")

        # Parse path and query parameters
        parsed_path = urllib.parse.urlparse(self.path)
        path = parsed_path.path
        query_params = urllib.parse.parse_qs(parsed_path.query)

        # Route to appropriate handler
        if path == '/health':
            self._handle_health()
        elif path == '/on-boot-sms-total-count':
            self._handle_boot_sms_counts()
        elif path == '/after-boot-total-count':
            self._handle_current_sms_counts()
        elif path == '/sms/shortcodes':
            self._handle_sms_filter('shortcodes')
        elif path == '/sms/not-shortcodes':
            self._handle_sms_filter('non_shortcodes')
        elif path == '/sms/read':
            self._handle_sms_filter('read')
        elif path == '/sms/not-read':
            self._handle_sms_filter('unread')
        elif path.startswith('/message/'):
            message_id = path.split('/message/')[1]
            self._handle_message_by_id(message_id)
        elif path == '/9':
            self._handle_option_9()
        else:
            self._handle_404()

    def do_POST(self):
        """Handle POST requests"""
        print(f"📨 POST {self.path}")

        if self.path == '/activate':
            self._handle_activate()
        elif self.path == '/test':
            self._handle_test()
        else:
            self._handle_404()

    def _handle_health(self):
        """Handle health check"""
        response = {
            'status': 'ok',
            'timestamp': datetime.now().isoformat(),
            'server': 'Standalone BluPOS Micro-Server',
            'version': '1.0.0',
            'port': 8085,
            'endpoints': [
                'GET /health',
                'GET /on-boot-sms-total-count',
                'GET /after-boot-total-count',
                'GET /sms/shortcodes',
                'GET /sms/not-shortcodes',
                'GET /sms/read',
                'GET /sms/not-read',
                'GET /message/<id>',
                'POST /activate',
                'POST /test'
            ]
        }
        self._send_json_response(200, response)

    def _handle_boot_sms_counts(self):
        """Handle boot-time SMS counts"""
        response = {
            'status': 'success',
            'context': 'on_boot',
            'timestamp': datetime.now().isoformat(),
            'counts': {
                'total_messages': 12,
                'read_messages': 10,
                'unread_messages': 2,
                'payment_messages': 1,
                'system_messages': 3,
            },
            'boot_context': {
                'captured_at': 'app_initialization',
                'includes_existing_inbox': True,
                'excludes_runtime_messages': True,
                'represents_baseline': True,
            }
        }
        self._send_json_response(200, response)

    def _handle_current_sms_counts(self):
        """Handle current SMS counts"""
        response = {
            'status': 'success',
            'context': 'after_boot',
            'timestamp': datetime.now().isoformat(),
            'counts': {
                'total_messages': 15,
                'read_messages': 8,
                'unread_messages': 7,
                'payment_messages': 3,
                'system_messages': 2,
            },
            'runtime_context': {
                'includes_runtime_messages': True,
                'reflects_current_state': True,
                'shows_accumulated_activity': True,
                'data_source': 'mock_service',
            }
        }
        self._send_json_response(200, response)

    def _handle_sms_filter(self, filter_type):
        """Handle SMS filtering by type"""
        messages = self.mock_sms_data.get(filter_type, [])

        descriptions = {
            'shortcodes': 'Messages from approved shortcodes only (123456, 123457)',
            'non_shortcodes': 'Messages from regular phone numbers (rejected as potential scams)',
            'read': 'Read messages only',
            'unread': 'Unread messages only'
        }

        response = {
            'status': 'success',
            'filter_type': filter_type,
            'description': descriptions.get(filter_type, 'Unknown filter'),
            'timestamp': datetime.now().isoformat(),
            'count': len(messages),
            'messages': messages,
            'metadata': {
                'filtered_at': datetime.now().isoformat(),
                'data_source': 'mock_sms_service',
                'filter_criteria': filter_type,
            }
        }
        self._send_json_response(200, response)

    def _handle_message_by_id(self, message_id):
        """Handle message retrieval by ID"""
        # Search across all mock data
        for category, messages in self.mock_sms_data.items():
            for msg in messages:
                if msg['id'] == message_id:
                    response = {
                        'status': 'success',
                        'message_id': message_id,
                        'data': msg,
                        'metadata': {
                            'retrieved_at': datetime.now().isoformat(),
                            'cache_status': 'mock',
                            'source': 'standalone_microserver',
                        }
                    }
                    self._send_json_response(200, response)
                    return

        # Message not found
        response = {
            'status': 'error',
            'message': 'Message not found',
            'message_id': message_id
        }
        self._send_json_response(404, response)

    def _handle_activate(self):
        """Handle activation requests"""
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            action = data.get('action', '')
            device_id = data.get('device_id', 'unknown')

            if action == 'check_expiry':
                response = {
                    'status': 'success',
                    'app_state': 'active',
                    'license_expiry': '2026-02-08T00:00:00.000Z',
                    'days_remaining': 30,
                    'license_type': 'DEMO2025',
                    'message': 'License active',
                    'device_id': device_id
                }
            else:
                response = {
                    'status': 'error',
                    'message': f'Unknown action: {action}'
                }

            self._send_json_response(200, response)
        except Exception as e:
            response = {
                'status': 'error',
                'message': f'Activation error: {str(e)}'
            }
            self._send_json_response(500, response)

    def _handle_test(self):
        """Handle test requests"""
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            action = data.get('action', '')
            device_id = data.get('device_id', 'unknown')

            if action == 'get_status':
                response = {
                    'status': 'success',
                    'app_state': 'active',
                    'license_type': 'DEMO2025',
                    'license_expiry': '2026-02-08T00:00:00.000Z',
                    'days_remaining': 30,
                    'device_id': device_id,
                    'activation_code': 'DEMO2025'
                }
            elif action == 'force_expiry':
                response = {
                    'status': 'success',
                    'message': 'License expired (mock)',
                    'app_state': 'expired',
                    'license_expiry': 'EXPIRED',
                    'device_id': device_id
                }
            else:
                response = {
                    'status': 'error',
                    'message': f'Unknown test action: {action}'
                }

            self._send_json_response(200, response)
        except Exception as e:
            response = {
                'status': 'error',
                'message': f'Test error: {str(e)}'
            }
            self._send_json_response(500, response)

    def _handle_404(self):
        """Handle 404 errors"""
        response = {
            'status': 'error',
            'message': 'Endpoint not found',
            'path': self.path,
            'method': self.command
        }
        self._send_json_response(404, response)

    def _send_json_response(self, status_code, data):
        """Send JSON response"""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

        json_response = json.dumps(data, indent=2)
        self.wfile.write(json_response.encode('utf-8'))

    def log_message(self, format, *args):
        """Override to reduce noise"""
        if "GET /health" not in format:  # Don't log health checks
            super().log_message(format, *args)

def run_server(port=8085):
    """Run the standalone micro-server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MicroServerHandler)

    print("🚀 Standalone BluPOS Micro-Server")
    print("=" * 50)
    print(f"📡 Server running on port {port}")
    print(f"🌐 Local access: http://localhost:{port}")
    print()
    print("📋 Available endpoints:")
    print("   GET  /health")
    print("   GET  /on-boot-sms-total-count")
    print("   GET  /after-boot-total-count")
    print("   GET  /sms/shortcodes")
    print("   GET  /sms/not-shortcodes")
    print("   GET  /sms/read")
    print("   GET  /sms/not-read")
    print("   GET  /message/<id>")
    print("   POST /activate")
    print("   POST /test")
    print()
    print("🧪 Mock data available for testing SMS filtering")
    print("🛑 Press Ctrl+C to stop the server")
    print()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        httpd.shutdown()

if __name__ == '__main__':
    port = 8085
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"❌ Invalid port number: {sys.argv[1]}")
            sys.exit(1)

    run_server(port)

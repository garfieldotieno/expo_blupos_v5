#!/usr/bin/env python3
"""
BLUPOS Activation Flow CLI Demo - Exact Backend Integration
Timestamp: 2026-01-12 20:24:14 UTC+3

This CLI program implements the EXACT activation flow:
1. Scan for UDP broadcasts from backend server
2. Find and log received datagrams
3. Save server configuration
4. List discovered server information
5. Prompt user for activation code
6. Process activation against backend /activate endpoint
7. Show activation result

Based on backend_broadcast_service.py and backend.py implementation.
"""

import asyncio
import json
import os
import socket
import struct
import time
import requests
from typing import Dict, Optional, Tuple

# Configuration matching backend_broadcast_service.py
MULTICAST_GROUP = '239.255.1.1'
BROADCAST_PORT = 8888
CONFIG_FILE = "server_config.json"

class BluPOSActivationClient:
    def __init__(self):
        self.server_config = {}
        self.load_server_config()

    def load_server_config(self):
        """Load saved server configuration"""
        try:
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, 'r') as f:
                    self.server_config = json.load(f)
                print("✅ Loaded saved server configuration")
        except Exception as e:
            print(f"⚠️  Error loading server config: {e}")
            self.server_config = {}

    def save_server_config(self, config: Dict):
        """Save server configuration to file"""
        try:
            self.server_config = config
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            print("💾 Server configuration saved")
        except Exception as e:
            print(f"❌ Error saving server config: {e}")

    def scan_for_broadcasts(self, timeout: int = 10) -> Optional[Dict]:
        """Scan for UDP broadcasts from backend server - matches backend_broadcast_service.py"""
        print("🔍 Scanning for backend server broadcasts...")
        print(f"   Multicast Group: {MULTICAST_GROUP}:{BROADCAST_PORT}")
        print(f"   Timeout: {timeout} seconds")

        try:
            # Create UDP socket for multicast reception
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

            # Bind to the broadcast port
            sock.bind(('', BROADCAST_PORT))

            # Join the multicast group
            group = socket.inet_aton(MULTICAST_GROUP)
            mreq = struct.pack('4sL', group, socket.INADDR_ANY)
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)

            print("📡 UDP socket bound and joined multicast group")
            print("⏳ Listening for server broadcast datagrams...")

            # Set socket timeout
            sock.settimeout(timeout)

            start_time = time.time()
            while time.time() - start_time < timeout:
                try:
                    # Receive datagram
                    data, addr = sock.recvfrom(1024)  # Buffer size

                    print(f"\n📨 RECEIVED DATAGRAM from {addr[0]}:{addr[1]}")
                    print(f"   Raw datagram ({len(data)} bytes): {data}")

                    # Try to decode and parse JSON
                    try:
                        decoded_data = data.decode('utf-8')
                        print(f"   Decoded datagram: {decoded_data}")

                        # Parse the backend broadcast datagram
                        server_info = json.loads(decoded_data)

                        # Validate this is from a BLUPOS backend (matches backend_broadcast_service.py)
                        if server_info.get('server_type') == 'blupos_backend':
                            print("✅ Valid BLUPOS backend server datagram received!")

                            # Extract server configuration
                            config = {
                                'server_ip': server_info['ip_address'],
                                'server_port': server_info['port'],
                                'server_name': server_info['server_name'],
                                'server_type': server_info['server_type'],
                                'discovered_at': time.time(),
                                'broadcast_addr': f"{addr[0]}:{addr[1]}",
                                'raw_datagram': decoded_data
                            }

                            sock.close()
                            return config
                        else:
                            print(f"⚠️  Ignoring non-BLUPOS datagram: {server_info.get('server_type')}")

                    except json.JSONDecodeError as e:
                        print(f"⚠️  Invalid JSON datagram: {e}")
                        continue

                except socket.timeout:
                    remaining = int(timeout - (time.time() - start_time))
                    if remaining > 0:
                        print(f"⏳ Still listening... ({remaining}s remaining)")
                    continue

            sock.close()
            print("❌ No valid BLUPOS backend broadcasts found within timeout")
            return None

        except Exception as e:
            print(f"❌ Broadcast scanning failed: {e}")
            return None

    def list_server_information(self):
        """List the discovered server information"""
        if not self.server_config:
            print("❌ No server configuration available")
            return

        print("\n" + "="*60)
        print("📊 DISCOVERED SERVER INFORMATION")
        print("="*60)
        print(f"Server Name: {self.server_config.get('server_name', 'Unknown')}")
        print(f"Server Type: {self.server_config.get('server_type', 'Unknown')}")
        print(f"Server IP:   {self.server_config.get('server_ip', 'Unknown')}")
        print(f"Server Port: {self.server_config.get('server_port', 'Unknown')}")
        print(f"Full URL:    http://{self.server_config.get('server_ip', 'Unknown')}:{self.server_config.get('server_port', 'Unknown')}")
        print(f"Discovered:  {time.ctime(self.server_config.get('discovered_at', 0))}")
        print(f"Broadcast:   {self.server_config.get('broadcast_addr', 'Unknown')}")
        print("="*60)

        # Show raw datagram
        raw_datagram = self.server_config.get('raw_datagram', '')
        if raw_datagram:
            print("Raw Broadcast Datagram:")
            print(f"  {raw_datagram}")
        print()

    def prompt_activation_code(self) -> Optional[str]:
        """Prompt user for activation code"""
        print("🔑 ACTIVATION REQUIRED")
        print("Please enter your activation code:")
        print("(Valid codes: BLUPOS2025, DEMO2025, or generated codes like BLUxxxxx/POSxxxxx)")

        while True:
            code = input("Activation Code: ").strip().upper()

            if not code:
                print("❌ Activation code cannot be empty")
                continue

            # Basic validation
            if len(code) < 4:
                print("❌ Activation code too short")
                continue

            return code

    def process_activation(self, activation_code: str) -> Dict:
        """Process activation against backend /activate endpoint"""
        if not self.server_config:
            return {"status": "error", "message": "No server configuration available"}

        server_ip = self.server_config.get('server_ip')
        server_port = self.server_config.get('server_port')

        if not server_ip or not server_port:
            return {"status": "error", "message": "Invalid server configuration"}

        backend_url = f"http://{server_ip}:{server_port}/activate"

        print(f"🚀 Processing activation against backend...")
        print(f"   URL: {backend_url}")
        print(f"   Code: {activation_code}")

        try:
            # Prepare activation request (matches backend.py /activate endpoint)
            payload = {
                "action": "first_time",
                "activation_code": activation_code
            }

            print(f"   Payload: {json.dumps(payload, indent=2)}")

            # Make HTTP POST request to backend
            response = requests.post(backend_url, json=payload, timeout=10)

            print(f"   Response Status: {response.status_code}")

            if response.status_code == 200:
                result = response.json()
                print("✅ Backend activation response received")
                return result
            else:
                print(f"❌ Backend returned error status: {response.status_code}")
                try:
                    error_data = response.json()
                    return {"status": "error", "message": f"HTTP {response.status_code}: {error_data.get('message', 'Unknown error')}"}
                except:
                    return {"status": "error", "message": f"HTTP {response.status_code}: {response.text}"}

        except requests.exceptions.ConnectionError:
            return {"status": "error", "message": f"Cannot connect to backend server at {server_ip}:{server_port}"}
        except requests.exceptions.Timeout:
            return {"status": "error", "message": "Backend server timeout"}
        except Exception as e:
            return {"status": "error", "message": f"Activation request failed: {str(e)}"}

    def show_activation_result(self, result: Dict):
        """Show the activation result"""
        print("\n" + "="*60)
        print("🎯 ACTIVATION RESULT")
        print("="*60)

        if result.get("status") == "success":
            print("✅ ACTIVATION SUCCESSFUL!")
            print(f"   Account ID: {result.get('account_id', 'Unknown')}")
            print(f"   License Type: {result.get('license_type', 'Unknown')}")
            print(f"   Expires: {result.get('license_expiry', 'Unknown')}")
            print(f"   App State: {result.get('app_state', 'Unknown')}")

            if result.get("license_days"):
                print(f"   Duration: {result['license_days']} days")

        else:
            print("❌ ACTIVATION FAILED!")
            print(f"   Error: {result.get('message', 'Unknown error')}")

        print("="*60)

    def run_activation_flow(self):
        """Main activation flow - EXACT sequence as specified"""
        print("🚀 BLUPOS Activation Flow - Backend Integration Demo")
        print("=" * 55)

        # Step 1: Scan for broadcasts
        print("\n1. SCANNING FOR BROADCASTS")
        server_config = self.scan_for_broadcasts(timeout=15)

        if not server_config:
            print("\n❌ No backend servers found. Please ensure the backend is running and broadcasting.")
            return

        # Step 2: Log the received datagram (already done in scan_for_broadcasts)

        # Step 3: Save the config
        print("\n2. SAVING SERVER CONFIGURATION")
        self.save_server_config(server_config)

        # Step 4: List server information
        print("\n3. DISCOVERED SERVER INFORMATION")
        self.list_server_information()

        # Step 5: Prompt for activation code
        print("4. ACTIVATION CODE INPUT")
        activation_code = self.prompt_activation_code()

        if not activation_code:
            print("❌ No activation code provided")
            return

        # Step 6: Process activation against backend endpoint
        print("\n5. PROCESSING ACTIVATION")
        result = self.process_activation(activation_code)

        # Step 7: Show result
        print("\n6. ACTIVATION RESULT")
        self.show_activation_result(result)

        print("\n🏁 Activation flow completed!")

def main():
    """Main entry point"""
    client = BluPOSActivationClient()
    client.run_activation_flow()

if __name__ == "__main__":
    main()

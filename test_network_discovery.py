#!/usr/bin/env python3
"""
Test script to verify network discovery functionality
This script tests both the backend broadcast and simulates a Flutter app client
"""

import socket
import threading
import json
import time
import sys
from backend_broadcast_service import BackendBroadcastService

def test_broadcast_service():
    """Test the backend broadcast service"""
    print("🧪 Testing Backend Broadcast Service...")

    # Start broadcast service
    service = BackendBroadcastService()
    service.start_broadcasting()

    print("📡 Broadcasting for 10 seconds...")
    time.sleep(10)

    # Stop broadcasting
    service.stop_broadcasting()
    print("✅ Broadcast service test completed")

def test_client_discovery():
    """Test the client discovery (simulates Flutter app)"""
    print("🧪 Testing Client Discovery...")

    # Create UDP socket to listen for broadcasts
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)

    try:
        # Bind to the broadcast port
        sock.bind(('0.0.0.0', 8888))

        # Join multicast group
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                       socket.inet_aton('239.255.1.1') + socket.inet_aton('0.0.0.0'))

        print("👂 Listening for broadcasts on port 8888...")

        # Set timeout for listening
        sock.settimeout(15)  # Listen for 15 seconds

        discovered_servers = []

        try:
            while True:
                try:
                    data, addr = sock.recvfrom(1024)
                    message = json.loads(data.decode('utf-8'))

                    server_info = {
                        'ip': addr[0],
                        'message': message,
                        'received_at': time.time()
                    }

                    discovered_servers.append(server_info)

                    print(f"📡 Discovered server: {message['server_name']} at {message['ip_address']}:{message['port']}")
                    print(f"   Type: {message['server_type']}, Timestamp: {message['timestamp']}")

                except socket.timeout:
                    break
                except json.JSONDecodeError as e:
                    print(f"⚠️ Invalid JSON received: {e}")
                    continue

        except KeyboardInterrupt:
            pass

        print(f"✅ Client discovery test completed. Found {len(discovered_servers)} servers.")

        if discovered_servers:
            print("\n📋 Discovered Servers:")
            for i, server in enumerate(discovered_servers, 1):
                msg = server['message']
                print(f"{i}. {msg['server_name']} ({msg['server_type']})")
                print(f"   IP: {msg['ip_address']}:{msg['port']}")
                print(f"   Timestamp: {msg['timestamp']}")
        else:
            print("❌ No servers discovered. Make sure backend broadcast is running.")

    finally:
        sock.close()

def run_full_test():
    """Run both broadcast and discovery tests"""
    print("🚀 Starting Network Discovery Test Suite")
    print("=" * 50)

    # Start broadcast service in background
    print("\n1️⃣ Starting Backend Broadcast Service...")
    broadcast_service = BackendBroadcastService()
    broadcast_service.start_broadcasting()

    # Give broadcast service time to start
    time.sleep(2)

    # Test client discovery
    print("\n2️⃣ Testing Client Discovery...")
    test_client_discovery()

    # Stop broadcast service
    print("\n3️⃣ Stopping Broadcast Service...")
    broadcast_service.stop_broadcasting()

    print("\n✅ Network Discovery Test Suite Completed!")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "broadcast":
            test_broadcast_service()
        elif sys.argv[1] == "client":
            test_client_discovery()
        else:
            print("Usage: python test_network_discovery.py [broadcast|client]")
    else:
        run_full_test()

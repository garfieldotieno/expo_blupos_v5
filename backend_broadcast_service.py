#!/usr/bin/env python3
"""
Network Discovery Broadcast Service for BluPOS Backend
Broadcasts server presence on local network for automatic discovery by Flutter app
"""

import socket
import threading
import json
import time
import logging
from datetime import datetime

class BackendBroadcastService:
    def __init__(self, server_type="blupos_backend", port=8080, broadcast_port=8888):
        self.server_type = server_type
        self.port = port
        self.broadcast_port = broadcast_port
        self.multicast_group = '239.255.1.1'
        self.running = False
        self.broadcast_thread = None

        # Setup detailed logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def start_broadcasting(self):
        """Start broadcasting server presence"""
        if self.running:
            self.logger.info("Broadcast service already running")
            return

        self.running = True
        self.broadcast_thread = threading.Thread(target=self._broadcast_loop, daemon=True)
        self.broadcast_thread.start()
        self.logger.info(f"🔍 Started broadcasting {self.server_type} on port {self.port}")

    def stop_broadcasting(self):
        """Stop broadcasting"""
        self.running = False
        if self.broadcast_thread and self.broadcast_thread.is_alive():
            self.broadcast_thread.join(timeout=2.0)
        self.logger.info("🔍 Stopped broadcasting")

    def _broadcast_loop(self):
        """Main broadcast loop - sends server info every 30 seconds"""
        try:
            # Create UDP socket for broadcasting
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)  # Local network only
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            self.logger.info(f"📡 UDP broadcast socket created on port {self.broadcast_port}")
            self.logger.info(f"📡 Multicast group: {self.multicast_group}, TTL: 2")

            broadcast_count = 0
            while self.running:
                try:
                    server_info = self._get_server_info()
                    message = json.dumps(server_info).encode('utf-8')

                    # Send broadcast
                    sock.sendto(message, (self.multicast_group, self.broadcast_port))
                    broadcast_count += 1

                    self.logger.info(f"📡 [BROADCAST #{broadcast_count}] Sent: {server_info}")
                    self.logger.debug(f"📡 Message size: {len(message)} bytes")
                    
                    time.sleep(30)  # Broadcast every 30 seconds

                except Exception as e:
                    self.logger.error(f"❌ Broadcast error: {e}")
                    time.sleep(5)  # Wait before retrying

        except Exception as e:
            self.logger.error(f"❌ Failed to create broadcast socket: {e}")
        finally:
            try:
                sock.close()
                self.logger.info("📡 Broadcast socket closed")
            except:
                pass

    def _get_server_info(self):
        """Get current server information"""
        return {
            'server_type': self.server_type,
            'ip_address': self._get_local_ip(),
            'port': self.port,
            'server_name': 'BluPOS Backend Server',
            'timestamp': int(time.time())
        }

    def _get_local_ip(self):
        """Get the local IP address of this machine"""
        try:
            # Create a socket to determine local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))  # Connect to Google DNS
            local_ip = s.getsockname()[0]
            s.close()
            return local_ip
        except Exception as e:
            self.logger.warning(f"Could not determine local IP: {e}")
            return "127.0.0.1"

# Global instance for easy access
_broadcast_service = None

def start_backend_broadcast(port=8080):
    """Start the backend broadcast service"""
    global _broadcast_service
    if _broadcast_service is None:
        _broadcast_service = BackendBroadcastService(port=port)
        _broadcast_service.start_broadcasting()
    return _broadcast_service

def stop_backend_broadcast():
    """Stop the backend broadcast service"""
    global _broadcast_service
    if _broadcast_service:
        _broadcast_service.stop_broadcasting()
        _broadcast_service = None

if __name__ == "__main__":
    # Test the broadcast service
    print("🧪 Testing Backend Broadcast Service...")
    service = BackendBroadcastService()
    service.start_broadcasting()

    try:
        print("📡 Broadcasting for 60 seconds... (Ctrl+C to stop)")
        time.sleep(60)
    except KeyboardInterrupt:
        print("\n🛑 Stopping broadcast...")
    finally:
        service.stop_broadcasting()
        print("✅ Broadcast service stopped")

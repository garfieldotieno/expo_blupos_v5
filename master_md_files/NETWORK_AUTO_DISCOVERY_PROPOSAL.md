# Network Auto-Discovery for BluPOS Systems

## Problem Statement
The Flutter app currently requires manual IP address configuration when the backend server changes networks. This creates friction for users who need to:

1. Know the exact IP address of the BluPOS backend server
2. Manually enter it in the network configuration screen
3. Update it whenever the server moves to a different network

## Proposed Solution
Implement automatic network discovery using UDP broadcast/multicast to allow BluPOS servers (both main backend and micro-server) to announce their presence on the local network.

## Architecture Overview

### Components
1. **Discovery Service** - Runs on both backend.py and micro-server
2. **Client Discovery** - Flutter app listens for server announcements
3. **Fallback Manual Config** - Traditional IP input as backup

### Server-Side (Backend & Micro-server)
```python
# UDP Broadcast Service
- Broadcasts server info every 30 seconds on port 8888
- Includes: server_type, ip_address, port, server_name
- Uses multicast group 239.255.1.1 for efficient local network discovery
```

### Client-Side (Flutter App)
```dart
// Network Discovery Service
- Listens for UDP broadcasts on port 8888
- Maintains list of discovered servers
- Auto-connects to first available server or shows selection dialog
- Falls back to manual configuration if no servers found
```

## Implementation Details

### Backend Broadcast (backend.py)
```python
import socket
import threading
import json
import time

class NetworkDiscoveryService:
    def __init__(self, server_type="blupos_backend", port=8080):
        self.server_type = server_type
        self.port = port
        self.broadcast_port = 8888
        self.multicast_group = '239.255.1.1'
        self.running = False

    def start_broadcasting(self):
        """Start broadcasting server presence"""
        self.running = True
        thread = threading.Thread(target=self._broadcast_loop)
        thread.daemon = True
        thread.start()

    def _broadcast_loop(self):
        """Broadcast server info every 30 seconds"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)

        server_info = {
            'server_type': self.server_type,
            'ip_address': self._get_local_ip(),
            'port': self.port,
            'server_name': 'BluPOS Backend Server',
            'timestamp': int(time.time())
        }

        while self.running:
            try:
                message = json.dumps(server_info).encode('utf-8')
                sock.sendto(message, (self.multicast_group, self.broadcast_port))
                time.sleep(30)  # Broadcast every 30 seconds
            except Exception as e:
                print(f"Broadcast error: {e}")
                time.sleep(5)

    def _get_local_ip(self):
        """Get local IP address"""
        try:
            # Create a socket to determine local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))  # Connect to Google DNS
            local_ip = s.getsockname()[0]
            s.close()
            return local_ip
        except:
            return "127.0.0.1"
```

### Micro-server Broadcast
Similar implementation for the micro-server with `server_type: "blupos_micro_server"`.

### Flutter Discovery Service
```dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class NetworkDiscoveryService {
  static const int broadcastPort = 8888;
  static const String multicastGroup = '239.255.1.1';

  List<Map<String, dynamic>> discoveredServers = [];
  StreamController<List<Map<String, dynamic>>> _serversController =
      StreamController.broadcast();

  Stream<List<Map<String, dynamic>>> get serversStream =>
      _serversController.stream;

  void startDiscovery() {
    RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort)
        .then((socket) {
      socket.multicastLoopback = true;
      socket.joinMulticastGroup(InternetAddress(multicastGroup));

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = socket.receive();
          if (datagram != null) {
            try {
              String message = utf8.decode(datagram.data);
              Map<String, dynamic> serverInfo = json.decode(message);
              _addOrUpdateServer(serverInfo);
            } catch (e) {
              print('Error parsing server info: $e');
            }
          }
        }
      });
    });
  }

  void _addOrUpdateServer(Map<String, dynamic> serverInfo) {
    // Check if server already exists
    int existingIndex = discoveredServers.indexWhere(
      (server) => server['ip_address'] == serverInfo['ip_address'] &&
                  server['port'] == serverInfo['port']
    );

    if (existingIndex >= 0) {
      // Update existing server
      discoveredServers[existingIndex] = {
        ...discoveredServers[existingIndex],
        ...serverInfo,
        'last_seen': DateTime.now(),
      };
    } else {
      // Add new server
      discoveredServers.add({
        ...serverInfo,
        'last_seen': DateTime.now(),
      });
    }

    // Remove old servers (not seen for 2 minutes)
    discoveredServers.removeWhere(
      (server) => DateTime.now().difference(server['last_seen']).inMinutes > 2
    );

    _serversController.add(List.from(discoveredServers));
  }

  void stopDiscovery() {
    _serversController.close();
  }
}
```

## User Experience

### Automatic Discovery Flow
1. App starts → Network discovery begins
2. If servers found → Auto-connect to first available server
3. If multiple servers → Show selection dialog
4. If no servers found → Show manual configuration popup

### Manual Configuration Popup
- Simple IP input field
- Test connection button
- Save configuration
- Option to retry discovery

## Benefits
1. **Zero Configuration**: Users don't need to know IP addresses
2. **Plug & Play**: Move servers between networks seamlessly
3. **Fallback Support**: Manual config still available
4. **Multi-Server Support**: Handle backend + micro-server scenarios

## Implementation Priority
1. **Phase 1**: Manual IP configuration popup (immediate fix)
2. **Phase 2**: Basic UDP broadcast discovery
3. **Phase 3**: Advanced features (server selection, health checks)

## Security Considerations
- Broadcast only on local network (multicast TTL=2)
- No sensitive data in broadcast messages
- Server authentication still required for actual connections

## Testing
- Test on multiple network configurations
- Verify firewall doesn't block UDP port 8888
- Test server movement between networks
- Validate fallback to manual configuration

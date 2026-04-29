import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class DiscoveredServer {
  final String serverType;
  final String ipAddress;
  final int port;
  final String serverName;
  final DateTime lastSeen;
  final int timestamp;

  DiscoveredServer({
    required this.serverType,
    required this.ipAddress,
    required this.port,
    required this.serverName,
    required this.lastSeen,
    required this.timestamp,
  });

  // Use port 8080 for HTTP API (backend server), not the discovery port 8888
  String get url => 'http://$ipAddress:8080';

  Map<String, dynamic> toJson() => {
        'serverType': serverType,
        'ipAddress': ipAddress,
        'port': port,
        'serverName': serverName,
        'lastSeen': lastSeen.toIso8601String(),
        'timestamp': timestamp,
      };

  factory DiscoveredServer.fromJson(Map<String, dynamic> json) => DiscoveredServer(
        serverType: json['serverType'],
        ipAddress: json['ipAddress'],
        port: json['port'],
        serverName: json['serverName'],
        lastSeen: DateTime.parse(json['lastSeen']),
        timestamp: json['timestamp'],
      );

  @override
  String toString() =>
      '$serverName ($serverType) at $ipAddress:$port (last seen: ${lastSeen.toLocal()})';
}

class NetworkDiscoveryService {
  static const int broadcastPort = 8888;
  static const String multicastGroup = '239.255.1.1';
  static const Duration serverTimeout = Duration(minutes: 2);

  final StreamController<List<DiscoveredServer>> _serversController =
      StreamController<List<DiscoveredServer>>.broadcast();

  List<DiscoveredServer> _discoveredServers = [];
  RawDatagramSocket? _socket;
  Timer? _cleanupTimer;
  bool _isListening = false;

  Stream<List<DiscoveredServer>> get discoveredServers => _serversController.stream;

  /// Start listening for server broadcasts
  Future<void> startDiscovery() async {
    if (_isListening) {
      print('🔍 Network discovery already running');
      return;
    }

    try {
      print('🔍 Starting network discovery service...');
      print('📡 Binding to port $broadcastPort for UDP broadcasts');
      
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);
      _socket!.multicastLoopback = true;

      print('📡 Joining multicast group: $multicastGroup');
      // Join the multicast group
      _socket!.joinMulticast(InternetAddress(multicastGroup));

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleIncomingBroadcast();
        } else if (event == RawSocketEvent.readClosed) {
          print('⚠️ [DISCOVERY] Socket read closed');
        } else if (event == RawSocketEvent.write) {
          print('⚠️ [DISCOVERY] Socket write event');
        } else {
          print('⚠️ [DISCOVERY] Socket event: $event');
        }
      });

      // Add periodic socket status check
      Timer.periodic(const Duration(seconds: 5), (_) {
        if (_socket != null && _isListening) {
          print('📡 [DISCOVERY] Socket status: listening on port $broadcastPort, multicast group: $multicastGroup');
        }
      });

      // Add periodic unicast test to help debug network issues
      Timer.periodic(const Duration(seconds: 10), (_) {
        if (_socket != null && _isListening) {
          print('📡 [DISCOVERY] Testing unicast discovery - sending test message to localhost');
          _sendTestMessage();
        }
      });

      _isListening = true;

      // Start periodic cleanup of old servers
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _cleanupOldServers();
      });

      print('✅ Network discovery started - listening for server broadcasts on port $broadcastPort');
      print('📡 Multicast group: $multicastGroup, TTL: 2');
      print('📡 [DISCOVERY] Also listening for unicast messages on same port');
    } catch (e) {
      print('❌ Failed to start network discovery: $e');
      rethrow;
    }
  }

  /// Send a test message to help debug network connectivity
  void _sendTestMessage() {
    try {
      final testMessage = json.encode({
        'server_type': 'test_discovery',
        'ip_address': '127.0.0.1',
        'port': 8888,
        'server_name': 'Test Discovery',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final testBytes = utf8.encode(testMessage);
      final testAddress = InternetAddress.loopbackIPv4;
      
      _socket!.send(testBytes, testAddress, broadcastPort);
      print('📡 [DISCOVERY] Test message sent to $testAddress:$broadcastPort');
    } catch (e) {
      print('❌ [DISCOVERY] Failed to send test message: $e');
    }
  }

  /// Stop listening for broadcasts
  void stopDiscovery() {
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isListening = false;
    _serversController.close();
    print('🔍 Network discovery stopped');
  }

  /// Handle incoming broadcast messages
  void _handleIncomingBroadcast() {
    if (_socket == null) return;

    try {
      final datagram = _socket!.receive();
      if (datagram == null) {
        print('⚠️ [DISCOVERY] No datagram received');
        return;
      }

      print('📡 [DISCOVERY] Received datagram from ${datagram.address.address}:${datagram.port}, length: ${datagram.data.length}');
      
      final message = utf8.decode(datagram.data);
      print('📡 [DISCOVERY] Received message: $message');
      
      final serverInfo = json.decode(message) as Map<String, dynamic>;
      print('📡 [DISCOVERY] Parsed server info: $serverInfo');

      _addOrUpdateServer(serverInfo);
    } catch (e) {
      print('⚠️ [DISCOVERY] Error processing broadcast message: $e');
    }
  }

  /// Add or update a discovered server
  void _addOrUpdateServer(Map<String, dynamic> serverInfo) {
    final serverType = serverInfo['server_type'] as String? ?? 'unknown';
    final ipAddress = serverInfo['ip_address'] as String? ?? '';
    final port = serverInfo['port'] as int? ?? 8080;
    final serverName = serverInfo['server_name'] as String? ?? 'Unknown Server';
    final timestamp = serverInfo['timestamp'] as int? ?? 0;

    // Skip if invalid data
    if (ipAddress.isEmpty) return;

    // Check if server already exists
    final existingIndex = _discoveredServers.indexWhere(
      (server) => server.ipAddress == ipAddress && server.port == port
    );

    final now = DateTime.now();

    if (existingIndex >= 0) {
      // Update existing server
      _discoveredServers[existingIndex] = DiscoveredServer(
        serverType: serverType,
        ipAddress: ipAddress,
        port: port,
        serverName: serverName,
        lastSeen: now,
        timestamp: timestamp,
      );
      print('🔄 Updated server: $serverName at $ipAddress:$port');
    } else {
      // Add new server
      final newServer = DiscoveredServer(
        serverType: serverType,
        ipAddress: ipAddress,
        port: port,
        serverName: serverName,
        lastSeen: now,
        timestamp: timestamp,
      );

      _discoveredServers.add(newServer);
      print('🆕 Discovered new server: $newServer');
    }

    // Notify listeners
    _serversController.add(List.from(_discoveredServers));
  }

  /// Clean up servers that haven't been seen recently
  void _cleanupOldServers() {
    final now = DateTime.now();
    final initialCount = _discoveredServers.length;

    _discoveredServers.removeWhere(
      (server) => now.difference(server.lastSeen) > serverTimeout
    );

    final removedCount = initialCount - _discoveredServers.length;
    if (removedCount > 0) {
      print('🧹 Cleaned up $removedCount old servers');
      _serversController.add(List.from(_discoveredServers));
    }
  }

  /// Get the best available server (prioritize BluPOS backend)
  DiscoveredServer? getBestServer() {
    if (_discoveredServers.isEmpty) return null;

    // Prioritize BluPOS backend over micro-server
    final bluposBackends = _discoveredServers
        .where((server) => server.serverType == 'blupos_backend')
        .toList();

    if (bluposBackends.isNotEmpty) {
      // Return the most recently seen backend
      bluposBackends.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      return bluposBackends.first;
    }

    // Fall back to any server
    _discoveredServers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return _discoveredServers.first;
  }

  /// Test connection to a discovered server
  Future<bool> testServerConnection(DiscoveredServer server) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('${server.url}/health'));
      final response = await request.close();

      client.close();
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed for ${server.url}: $e');
      return false;
    }
  }

  /// Get list of servers filtered by type
  List<DiscoveredServer> getServersByType(String serverType) {
    return _discoveredServers
        .where((server) => server.serverType == serverType)
        .toList();
  }

  /// Get all discovered servers
  List<DiscoveredServer> getAllServers() {
    return List.from(_discoveredServers);
  }

  /// Check if discovery is currently active
  bool get isDiscovering => _isListening;

  /// Get current server count
  int get serverCount => _discoveredServers.length;
}

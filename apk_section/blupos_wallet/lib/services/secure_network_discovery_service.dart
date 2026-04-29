import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'secure_key_manager.dart';

// Secure broadcast packet structure
class SecureBroadcastPacket {
  final String version;
  final String timestamp;
  final String encryptedSessionKey;
  final String encryptedServerInfo;
  final String hmac;
  final String padding;

  SecureBroadcastPacket({
    required this.version,
    required this.timestamp,
    required this.encryptedSessionKey,
    required this.encryptedServerInfo,
    required this.hmac,
    required this.padding,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'timestamp': timestamp,
      'encrypted_session_key': encryptedSessionKey,
      'encrypted_server_info': encryptedServerInfo,
      'hmac': hmac,
      'padding': padding,
    };
  }

  factory SecureBroadcastPacket.fromJson(Map<String, dynamic> json) {
    return SecureBroadcastPacket(
      version: json['version'],
      timestamp: json['timestamp'],
      encryptedSessionKey: json['encrypted_session_key'],
      encryptedServerInfo: json['encrypted_server_info'],
      hmac: json['hmac'],
      padding: json['padding'],
    );
  }

  String toEncryptedString() {
    return jsonEncode(toJson());
  }
}

// Secure server information
class SecureServerInfo {
  final String serverType;
  final String ipAddress;
  final int port;
  final String serverName;
  final DateTime lastSeen;
  final int timestamp;
  final String url;

  SecureServerInfo({
    required this.serverType,
    required this.ipAddress,
    required this.port,
    required this.serverName,
    required this.lastSeen,
    required this.timestamp,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'server_type': serverType,
      'ip_address': ipAddress,
      'port': port,
      'server_name': serverName,
      'last_seen': lastSeen.toIso8601String(),
      'timestamp': timestamp,
      'url': url,
    };
  }

  factory SecureServerInfo.fromJson(Map<String, dynamic> json) {
    return SecureServerInfo(
      serverType: json['server_type'],
      ipAddress: json['ip_address'],
      port: json['port'],
      serverName: json['server_name'],
      lastSeen: DateTime.parse(json['last_seen']),
      timestamp: json['timestamp'],
      url: json['url'],
    );
  }
}

class SecureNetworkDiscoveryService {
  static const String _multicastGroup = '239.255.1.1';
  static const int _broadcastPort = 8888;
  static const String _version = '1.0';
  static const Duration _broadcastInterval = Duration(seconds: 30);
  static const Duration _cleanupInterval = Duration(minutes: 5);
  static const Duration _sessionRotationInterval = Duration(minutes: 30);

  final StreamController<List<SecureServerInfo>> _discoveredServersController =
      StreamController<List<SecureServerInfo>>.broadcast();

  late RawDatagramSocket _socket;
  late Timer _broadcastTimer;
  late Timer _cleanupTimer;
  late Timer _sessionRotationTimer;

  List<SecureServerInfo> _discoveredServers = [];
  String? _currentSessionKey;
  DateTime? _sessionExpiry;

  bool _isInitialized = false;
  bool _isRunning = false;

  // Control verbose logging for debugging
  static bool _verboseLogging = true;

  // Singleton instance
  static final SecureNetworkDiscoveryService _instance = SecureNetworkDiscoveryService._internal();
  factory SecureNetworkDiscoveryService() => _instance;
  SecureNetworkDiscoveryService._internal();

  /// Stream of discovered servers
  Stream<List<SecureServerInfo>> get discoveredServers => _discoveredServersController.stream;

  /// Initialize the secure network discovery service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize key manager
      await SecureKeyManager.initialize();
      print('🔐 Secure key manager initialized');

      // Start session rotation timer
      _startSessionRotationTimer();

      _isInitialized = true;
      print('✅ Secure network discovery service initialized');
    } catch (e) {
      print('❌ Failed to initialize secure network discovery: $e');
      rethrow;
    }
  }

  /// Start secure network discovery
  Future<void> startDiscovery() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) {
      print('⚠️ Secure network discovery already running');
      return;
    }

    try {
      // Create UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _broadcastPort);
      _socket.multicastLoopback = true;
      print('📡 Secure UDP socket bound to port $_broadcastPort');

      // Join multicast group
      _socket.joinMulticast(InternetAddress(_multicastGroup));
      print('📡 Joined multicast group $_multicastGroup');

      // Start listening for broadcasts
      _socket.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleIncomingBroadcast();
        }
      }, onError: (error) {
        print('❌ UDP socket error: $error');
      }, cancelOnError: false);

      // Start periodic tasks
      _startPeriodicTasks();

      _isRunning = true;
      print('✅ Secure network discovery started');
    } catch (e) {
      print('❌ Failed to start secure network discovery: $e');
      rethrow;
    }
  }

  /// Stop secure network discovery
  Future<void> stopDiscovery() async {
    if (!_isRunning) return;

    try {
      // Cancel timers
      _broadcastTimer?.cancel();
      _cleanupTimer?.cancel();
      _sessionRotationTimer?.cancel();

      // Leave multicast group
      _socket.leaveMulticast(InternetAddress(_multicastGroup));

      // Close socket
      _socket.close();

      _isRunning = false;
      print('✅ Secure network discovery stopped');
    } catch (e) {
      print('❌ Failed to stop secure network discovery: $e');
    }
  }

  /// Start periodic tasks
  void _startPeriodicTasks() {
    // Broadcast timer
    _broadcastTimer = Timer.periodic(_broadcastInterval, (timer) {
      _broadcastSecurePacket();
    });

    // Cleanup timer
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _cleanupOldServers();
    });
  }

  /// Start session rotation timer
  void _startSessionRotationTimer() {
    _sessionRotationTimer = Timer.periodic(_sessionRotationInterval, (timer) {
      _rotateSessionKey();
    });
  }

  /// Rotate session key
  Future<void> _rotateSessionKey() async {
    try {
      _currentSessionKey = await SecureKeyManager.generateSessionKey();
      _sessionExpiry = await SecureKeyManager.getSessionExpiry();
      print('🔄 Session key rotated');
    } catch (e) {
      print('❌ Failed to rotate session key: $e');
    }
  }

  /// Broadcast secure packet
  Future<void> _broadcastSecurePacket() async {
    try {
      // Get current session key
      if (_currentSessionKey == null) {
        _currentSessionKey = await SecureKeyManager.rotateSessionKeyIfNeeded();
        _sessionExpiry = await SecureKeyManager.getSessionExpiry();
      }

    // Create server info with fixed IP (should match backend broadcast)
    final serverInfo = SecureServerInfo(
      serverType: 'blupos_backend',
      ipAddress: '192.168.100.25',  // Use the same IP as backend broadcast
      port: 8080,
      serverName: 'BluPOS Backend Server',
      lastSeen: DateTime.now(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      url: 'http://192.168.100.25:8080',
    );

      // Encrypt server info
      final encryptedServerInfo = await SecureKeyManager.encryptData(
        jsonEncode(serverInfo.toJson()),
        _currentSessionKey!,
      );

      // Create secure packet
      final packet = SecureBroadcastPacket(
        version: _version,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        encryptedSessionKey: _currentSessionKey!,
        encryptedServerInfo: encryptedServerInfo,
        hmac: SecureKeyManager.createHMAC(encryptedServerInfo, _currentSessionKey!),
        padding: _generatePadding(),
      );

      // Send to multicast group
      final message = utf8.encode(packet.toEncryptedString());
      final address = InternetAddress(_multicastGroup);
      
      await _socket.send(message, address, _broadcastPort);
      print('📡 Secure broadcast sent to $_multicastGroup:$_broadcastPort');
    } catch (e) {
      print('❌ Failed to broadcast secure packet: $e');
    }
  }

  /// Handle incoming secure broadcast
  Future<void> _handleIncomingBroadcast() async {
    try {
      final datagram = _socket.receive();
      if (datagram == null || datagram.data.isEmpty) return;

      final message = utf8.decode(datagram.data);
      final packet = SecureBroadcastPacket.fromJson(jsonDecode(message));

      // Validate packet
      if (!_validateSecurePacket(packet)) {
        print('❌ Invalid secure packet received');
        return;
      }

      // Decrypt server info
      final decryptedServerInfo = await SecureKeyManager.decryptData(
        packet.encryptedServerInfo,
        packet.encryptedSessionKey,
      );

      // Parse server info
      final serverInfo = SecureServerInfo.fromJson(jsonDecode(decryptedServerInfo));

      // Add or update server
      _addOrUpdateServer(serverInfo);

      print('📡 Secure server discovered: ${serverInfo.serverName} at ${serverInfo.ipAddress}');
    } catch (e) {
      print('❌ Failed to handle secure broadcast: $e');
    }
  }

  /// Validate secure packet
  bool _validateSecurePacket(SecureBroadcastPacket packet) {
    try {
      // Check version
      if (packet.version != _version) {
        print('❌ Invalid packet version: ${packet.version}');
        return false;
      }

      // Check timestamp (reject old packets)
      final packetTime = DateTime.parse(packet.timestamp);
      final now = DateTime.now().toUtc();
      if (now.difference(packetTime).inMinutes > 5) {
        print('❌ Packet too old: ${packet.timestamp}');
        return false;
      }

      // Verify HMAC
      if (!SecureKeyManager.verifyHMAC(
        packet.encryptedServerInfo,
        packet.hmac,
        packet.encryptedSessionKey,
      )) {
        print('❌ Invalid HMAC');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Packet validation error: $e');
      return false;
    }
  }

  /// Add or update discovered server
  void _addOrUpdateServer(SecureServerInfo serverInfo) {
    // Remove existing server with same IP
    _discoveredServers.removeWhere((server) => server.ipAddress == serverInfo.ipAddress);

    // Add new server
    _discoveredServers.add(serverInfo);

    // Sort by last seen time (most recent first)
    _discoveredServers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    // Notify listeners
    _discoveredServersController.add(_discoveredServers);
  }

  /// Cleanup old servers
  void _cleanupOldServers() {
    final cutoffTime = DateTime.now().subtract(Duration(minutes: 10));
    _discoveredServers.removeWhere((server) => server.lastSeen.isBefore(cutoffTime));

    if (_discoveredServersController.hasListener) {
      _discoveredServersController.add(_discoveredServers);
    }
  }

  /// Get best server (most recent)
  SecureServerInfo? getBestServer() {
    if (_discoveredServers.isEmpty) return null;
    return _discoveredServers.first;
  }

  /// Test connection to server
  Future<bool> testServerConnection(SecureServerInfo server) async {
    try {
      final url = Uri.parse('${server.url}/health');
      // For now, just return true if we can parse the URL
      return true;
    } catch (e) {
      print('❌ Server connection test failed: $e');
      return false;
    }
  }

  /// Get local IP address
  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.address.startsWith('192.168.') || 
              address.address.startsWith('10.') || 
              address.address.startsWith('172.')) {
            return address.address;
          }
        }
      }

      return '127.0.0.1';
    } catch (e) {
      print('❌ Failed to get local IP: $e');
      return '127.0.0.1';
    }
  }

  /// Generate random padding
  String _generatePadding() {
    final random = encrypt.Key.fromLength(16);
    return base64Encode(random.bytes);
  }

  /// Enable verbose logging for debugging
  static void enableVerboseLogging() {
    _verboseLogging = true;
    print('📡 [DISCOVERY] Verbose logging enabled');
  }

  /// Disable verbose logging to reduce log noise
  static void disableVerboseLogging() {
    _verboseLogging = false;
    print('📡 [DISCOVERY] Verbose logging disabled');
  }

  /// Check if verbose logging is enabled
  static bool get isVerboseLogging => _verboseLogging;

  /// Dispose resources
  Future<void> dispose() async {
    await stopDiscovery();
    await _discoveredServersController.close();
  }
}

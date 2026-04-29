import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/micro_server_service.dart';
import '../services/heartbeat_service.dart';
import '../services/secure_network_discovery_service.dart';

class ActivationPage extends StatefulWidget {
  final VoidCallback? onActivationSuccess;
  final bool isReactivation; // true for reactivation (expired state), false for first-time

  const ActivationPage({
    super.key,
    this.onActivationSuccess,
    this.isReactivation = false,
  });

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _activationCodeController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController();
  String _statusMessage = 'Ready to activate. Enter activation code.';
  bool _isActivating = false;
  bool _serverReady = true; // Server IP is pre-populated from boot discovery

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'BluPOS Wallet ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _loadServerConfiguration();
  }

  Future<void> _loadServerConfiguration() async {
    try {
      print('🔍 [ACTIVATION] Loading server configuration from SharedPreferences...');

      // Load the server IP that was discovered during app boot
      final prefs = await SharedPreferences.getInstance();
      final savedServerIp = prefs.getString('server_ip');

      print('🔍 [ACTIVATION] Saved server IP from preferences: $savedServerIp');

      if (savedServerIp != null && savedServerIp.isNotEmpty) {
        // Extract just the IP part (remove port if present)
        final ipOnly = savedServerIp.split(':').first;
        setState(() {
          _serverIpController.text = ipOnly;
          _statusMessage = 'Server configuration loaded. Enter activation code.';
        });
        print('✅ [ACTIVATION] Loaded server IP from boot discovery: $ipOnly');
        print('📡 [ACTIVATION] Server configuration ready for activation');
      } else {
        // For testing/development: Use a known backend IP if none is saved
        print('⚠️ [ACTIVATION] No server IP found in preferences - checking for backend broadcasts...');

        // Try to find backend server via UDP broadcast
        final backendConfig = await _scanForBackendBroadcast();
        if (backendConfig != null) {
          final discoveredIp = backendConfig['server_ip'];
          setState(() {
            _serverIpController.text = discoveredIp;
            _statusMessage = 'Backend server found. Enter activation code.';
          });
          print('✅ [ACTIVATION] Discovered backend server via broadcast: $discoveredIp');

          // Save the discovered IP for future use
          await prefs.setString('server_ip', '$discoveredIp:8080');
        } else {
          // Fallback for development/testing
          const fallbackIp = '192.168.0.102'; // Known backend server IP
          setState(() {
            _serverIpController.text = fallbackIp;
            _statusMessage = 'Using fallback server IP. Enter activation code.';
          });
          print('⚠️ [ACTIVATION] Using fallback server IP: $fallbackIp');
          print('📝 [ACTIVATION] To use real backend, ensure server is broadcasting on UDP port 8888');
        }
      }
    } catch (e) {
      print('❌ [ACTIVATION] Error loading server configuration: $e');
      setState(() {
        _statusMessage = 'Error loading server configuration.';
        _serverReady = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _scanForBackendBroadcast() async {
    print('🔍 [ACTIVATION] Scanning for backend server broadcasts...');
    print('📡 [ACTIVATION] Listening on UDP multicast group: 239.255.1.1:8888');

    try {
      // Create UDP socket for multicast reception (similar to CLI demo)
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
      socket.multicastHops = 2;

      // Join multicast group
      final groupAddress = InternetAddress('239.255.1.1');
      socket.joinMulticast(groupAddress);

      print('📡 [ACTIVATION] UDP socket bound and joined multicast group');

      // Listen for broadcasts with timeout
      final completer = Completer<Map<String, dynamic>?>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            print('📨 [ACTIVATION] RECEIVED BROADCAST DATAGRAM:');
            print('   From: ${datagram.address}:${datagram.port}');
            print('   Raw data: $message');

            try {
              final serverInfo = jsonDecode(message);
              print('   Parsed data: $serverInfo');

              if (serverInfo['server_type'] == 'blupos_backend') {
                print('✅ [ACTIVATION] Valid BLUPOS backend server found!');
                socket.close();

                final config = {
                  'server_ip': serverInfo['ip_address'],
                  'server_port': serverInfo['port'],
                  'server_name': serverInfo['server_name'],
                  'raw_datagram': message,
                };

                completer.complete(config);
                return;
              } else {
                print('⚠️ [ACTIVATION] Ignoring non-BLUPOS broadcast: ${serverInfo['server_type']}');
              }
            } catch (e) {
              print('⚠️ [ACTIVATION] Failed to parse broadcast datagram: $e');
            }
          }
        }
      });

      // Timeout after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          print('⏰ [ACTIVATION] Broadcast scan timeout - no backend servers found');
          socket.close();
          completer.complete(null);
        }
      });

      return await completer.future;

    } catch (e) {
      print('❌ [ACTIVATION] Broadcast scanning failed: $e');
      return null;
    }
  }

  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      setState(() {
        _serverIpController.text = savedIp;
      });
    }
    // If no saved IP, leave empty for auto-discovery
  }

  Future<void> _saveServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
  }

  Future<void> _startServerDiscovery() async {
    setState(() {
      _statusMessage = 'Checking micro-server status...';
    });

    // Small delay to simulate checking
    await Future.delayed(const Duration(seconds: 1));

    if (MicroServerService.isRunning) {
      setState(() {
        _statusMessage = 'Micro-server is running. Ready to activate.';
      });
    } else {
      setState(() {
        _statusMessage = 'Micro-server not running. Please restart the app.';
      });
    }
  }

  void _onActivatePressed() async {
    if (_activationCodeController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter activation code';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _statusMessage = 'Activating device...';
    });

    try {
      // Get stored account ID (BluPOS is single source of truth)
      final prefs = await SharedPreferences.getInstance();
      String? existingAccountId = prefs.getString('persistentAccountId');

      // Save the server IP for persistence
      await _saveServerIp(_serverIpController.text);

      // Use the configured server IP
      final serverInput = _serverIpController.text.trim();
      final serverUrl = serverInput.startsWith('http')
          ? serverInput
          : serverInput.contains(':')
              ? 'http://$serverInput'
              : 'http://$serverInput:8080'; // Default to port 8080 if no port specified

      // Try activation with web system (BluPOS single source of truth)
      final activationResult = await _activateWithWeb(_activationCodeController.text, existingAccountId, serverUrl);

      if (activationResult['success'] == true) {
        // Success - update stored account ID with official one from server
        final officialAccountId = activationResult['account_id'];
        if (officialAccountId != null && officialAccountId != existingAccountId) {
          await prefs.setString('persistentAccountId', officialAccountId);
          print('🔄 Updated persistent account ID to official: $officialAccountId');
        }

        // Update license expiry date from server response
        final licenseExpiry = activationResult['license_expiry'];
        if (licenseExpiry != null) {
          await prefs.setString('licenseExpiry', licenseExpiry);
          await prefs.setBool('isActivated', true);
          print('🔄 Updated license expiry to: $licenseExpiry');
        }

        // Update local state
        setState(() {
          _isActivating = false;
          _statusMessage = 'Device activated successfully';
        });

        // Call the callback to update app state
        widget.onActivationSuccess?.call();

        // Navigate back after short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
        return;
      } else {
        // Activation failed, show error
        setState(() {
          _isActivating = false;
          _statusMessage = activationResult['message'] ?? 'Activation failed';
        });
        return;
      }

    } catch (e) {
      setState(() {
        _isActivating = false;
        _statusMessage = 'Activation error: ${e.toString()}';
      });
    }
  }

  Future<Map<String, dynamic>> _activateWithWeb(String activationCode, String? existingAccountId, String masterServer) async {
    try {
      // Step 1: Send activation request (BluPOS is source of truth, so account_id is optional)
      final url = Uri.parse('$masterServer/activate');
      final requestData = {
        'action': 'first_time',
        'activation_code': activationCode,
        // Don't send account_id initially - let BluPOS provide the official one
      };

      print('🚀 Sending activation request without account_id (BluPOS is source of truth)');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Server error: ${response.statusCode}'};
      }

      final result = jsonDecode(response.body);
      print('📡 Server response: ${result['status']}');

      if (result['status'] == 'success') {
        // Success! Get the official account_id from server response
        final officialAccountId = result['account_id'];
        print('✅ Activation successful! Official account_id: $officialAccountId');

        // Start heartbeat service with the official account_id
        try {
          await HeartbeatService.startHeartbeat(
            accountId: officialAccountId,
            licenseKey: activationCode, // Use activation code as license key
          );
          print('✅ Heartbeat service started with official account_id');
        } catch (e) {
          print('⚠️ Failed to start heartbeat service: $e');
        }

        return {
          'success': true,
          'message': result['message'] ?? 'Activation successful',
          'account_id': officialAccountId,
          'license_type': result['license_type'],
          'license_expiry': result['license_expiry'],
        };
      } else {
        // Activation failed
        return {'success': false, 'message': result['message'] ?? 'Activation failed'};
      }

    } catch (e) {
      print('❌ Activation error: $e');
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20), // Conservative spacing from top (matches welcome page)

              // Back Button (pushed up, matches welcome page button style)
              Container(
                width: double.infinity,
                height: 50 * 1.35, // 35% increase from 50px base height (matches welcome page)
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF182A62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Input Field Container (now yellow background, full width to match buttons)
              Container(
                width: double.infinity,
                height: 280, // Increased height to eliminate 56px overflow
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEC620), // Changed to yellow to match theme
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) {
                        print('🎨 Building activation icon - isReactivation: ${widget.isReactivation}');
                        final iconColor = widget.isReactivation ? Colors.green.shade600 : const Color(0xFF182A62);
                        print('🎨 Icon color: $iconColor');
                        print('🎨 Using Icons.power_settings_new (power button icon)');
                        return Icon(
                          Icons.power_settings_new,
                          size: 48,
                          color: iconColor,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Device Activation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show fields immediately with pre-populated IP
                    if (_serverReady) ...[
                      // Server IP Input Field (Read-only, shown after discovery)
                      TextFormField(
                        controller: _serverIpController,
                        decoration: InputDecoration(
                          labelText: 'BluPOS Server IP',
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                        readOnly: true, // Make the field unmodifiable
                        enabled: false, // Disable interaction
                      ),
                      const SizedBox(height: 12),

                      // Activation Code Input Field (shown after IP discovery)
                      TextFormField(
                        controller: _activationCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Activation Code',
                          labelStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isActivating ? Colors.orange : Colors.black54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(), // Pushes buttons to bottom (matches welcome page)

              // Activate Button (pushed to bottom, matches welcome page button style)
              Container(
                width: double.infinity,
                height: 50 * 1.35, // 35% increase from 50px base height (matches welcome page)
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: _isActivating ? null : _onActivatePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF182A62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Activate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Scan QR Button (below activate button)
              SizedBox(
                width: double.infinity,
                height: 50 * 1.35, // Same height as activate button
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement QR scanning
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR scanning coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    _serverIpController.dispose();
    super.dispose();
  }
}

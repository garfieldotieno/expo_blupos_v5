import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/micro_server_service.dart';

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
  String _statusMessage = 'Enter activation code';
  bool _isActivating = false;
  bool _isDiscovering = false;
  String? _deviceUid;
  String? _discoveredServer;

  @override
  void initState() {
    super.initState();
    _deviceNameController.text = 'BluPOS Wallet ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _startServerDiscovery();
  }

  Future<void> _startServerDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _statusMessage = 'Checking micro-server status...';
    });

    // Small delay to simulate checking
    await Future.delayed(const Duration(seconds: 1));

    if (MicroServerService.isRunning) {
      setState(() {
        _discoveredServer = 'localhost:${MicroServerService.PORT}';
        _statusMessage = 'Micro-server is running. Ready to activate.';
      });
    } else {
      setState(() {
        _statusMessage = 'Micro-server not running. Please restart the app.';
      });
    }

    setState(() {
      _isDiscovering = false;
    });
  }

  void _onActivatePressed() async {
    if (_activationCodeController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter activation code';
      });
      return;
    }

    if (!MicroServerService.isRunning) {
      setState(() {
        _statusMessage = 'Micro-server not running. Please restart the app.';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _statusMessage = 'Activating device...';
    });

    try {
      // Generate device ID
      final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';

      // Call micro-server activation API
      final url = Uri.parse('http://localhost:${MicroServerService.PORT}/activate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'first_time',
          'device_id': deviceId,
          'activation_code': _activationCodeController.text,
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          _isActivating = false;
          _statusMessage = 'Server error: ${response.statusCode}';
        });
        return;
      }

      final result = jsonDecode(response.body);

      if (result['status'] != 'success') {
        setState(() {
          _isActivating = false;
          _statusMessage = 'Activation failed: ${result['message']}';
        });
        return;
      }

      // Success
      setState(() {
        _isActivating = false;
        _statusMessage = result['message'];
      });

      // Call the callback to update app state
      widget.onActivationSuccess?.call();

      // Navigate back after short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      setState(() {
        _isActivating = false;
        _statusMessage = 'Activation error: ${e.toString()}';
      });
    }
  }

  Future<void> _requestSmsPermission() async {
    // TODO: Implement SMS permission request
    setState(() {
      _statusMessage = 'SMS permissions requested';
    });
  }

  Future<void> _startMicroServer() async {
    // TODO: Implement micro-server startup
    setState(() {
      _statusMessage = 'Micro-server started';
    });
  }

  void _updateServerStatus() {
    // TODO: Update server status indicator
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
                height: 280,
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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        TextField(
                          controller: _activationCodeController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                        ),
                        Positioned(
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            color: const Color(0xFFFEC620),
                            child: const Text(
                              'Activation Code',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

              const Spacer(), // Pushes button to bottom (matches welcome page)

              // Activate Button (pushed to bottom, matches welcome page button style)
              Container(
                width: double.infinity,
                height: 50 * 1.35, // 35% increase from 50px base height (matches welcome page)
                margin: const EdgeInsets.only(bottom: 16),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }
}

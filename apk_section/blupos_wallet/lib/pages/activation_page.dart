import 'package:flutter/material.dart';
import '../services/activation_service.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _activationCodeController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  String _statusMessage = 'Enter device name and activation code';
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
      _statusMessage = 'Discovering BluPOS server...';
    });

    try {
      final serverUrl = await ActivationService.discoverMasterServer();
      if (serverUrl != null) {
        setState(() {
          _discoveredServer = serverUrl;
          _statusMessage = 'BluPOS server found at $serverUrl';
        });

        // Test connection
        final connectionTest = await ActivationService.testMasterConnection();
        if (connectionTest) {
          setState(() {
            _statusMessage = 'Connected to BluPOS server. Ready to activate.';
          });
        } else {
          setState(() {
            _statusMessage = 'Server found but connection failed. Please check network.';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'No BluPOS server found. Please ensure BluPOS is running and on the same network.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Server discovery failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  void _onActivatePressed() async {
    if (_deviceNameController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter device name';
      });
      return;
    }

    if (_activationCodeController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter activation code';
      });
      return;
    }

    if (_discoveredServer == null) {
      setState(() {
        _statusMessage = 'No BluPOS server found. Please ensure BluPOS is running.';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _statusMessage = 'Activating device...';
    });

    try {
      // Step 1: Register device
      setState(() {
        _statusMessage = 'Registering device with BluPOS...';
      });

      final registrationResult = await ActivationService.registerDevice(
        deviceName: _deviceNameController.text,
      );

      if (!registrationResult['success']) {
        setState(() {
          _isActivating = false;
          _statusMessage = 'Device registration failed: ${registrationResult['message']}';
        });
        return;
      }

      final activationCode = registrationResult['activation_code'];
      _deviceUid = registrationResult['device_uid'];

      // Step 2: Activate device using the provided activation code
      setState(() {
        _statusMessage = 'Activating device license...';
      });

      final activationResult = await ActivationService.activateDevice(
        activationCode: _activationCodeController.text,
      );

      if (!activationResult['success']) {
        setState(() {
          _isActivating = false;
          _statusMessage = 'Activation failed: ${activationResult['message']}';
        });
        return;
      }

      // Step 3: Update device status
      if (_deviceUid != null) {
        await ActivationService.updateDeviceStatus(
          deviceUid: _deviceUid!,
          isOnline: true,
        );
      }

      // Success
      setState(() {
        _isActivating = false;
        _statusMessage = 'Device activated successfully! You can now access Wallet and Reports.';
      });

      // Navigate to wallet after short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // This would normally navigate to wallet page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activation complete! Switch to Wallet tab.')),
          );
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
      appBar: AppBar(
        title: const Text(
          'Activation',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 280,
                height: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    const Icon(
                      Icons.power_settings_new,
                      size: 48,
                      color: Color(0xFF182A62),
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
                    TextField(
                      controller: _activationCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Activation Code',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textAlign: TextAlign.center,
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
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 280,
                child: ElevatedButton(
                  onPressed: _isActivating ? null : _onActivatePressed,
                  child: _isActivating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Activate Device'),
                ),
              ),
            ),
          ],
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

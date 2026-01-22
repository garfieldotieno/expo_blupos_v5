import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeScannerPage({
    super.key,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool _hasPermission = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Payment Code'),
          backgroundColor: const Color(0xFF182A62),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera permission required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant camera permission to scan payment codes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _requestCameraPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182A62),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Payment Code'),
        backgroundColor: const Color(0xFF182A62),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on, color: Colors.white),
            onPressed: () {
              // Toggle torch if available
              try {
                controller.toggleTorch();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Flash not available')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android, color: Colors.white),
            onPressed: () {
              // Switch camera if available
              try {
                controller.switchCamera();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Camera switch not available')),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isScanning) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                final BarcodeFormat? format = barcode.format;

                print('🔍 Scanned barcode - Format: $format, Raw Value: "$code"');

                if (code != null && code.isNotEmpty) {
                  setState(() {
                    _isScanning = true;
                  });

                  // Debug: Show what we scanned
                  print('📱 Processing scanned code: "$code"');

                  // Validate barcode format
                  if (_isValidPaymentBarcode(code)) {
                    print('✅ Valid payment barcode format: $code');

                    // Show success animation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Scanned: $code'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );

                    // Return result after short delay
                    Future.delayed(const Duration(milliseconds: 500), () {
                      widget.onBarcodeScanned(code);
                      Navigator.of(context).pop();
                    });
                  } else {
                    print('❌ Invalid payment barcode format: $code');

                    // Invalid barcode format
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid format. Expected: XXX_DAYS_YYYY'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );

                    // Reset scanning flag after error
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        setState(() {
                          _isScanning = false;
                        });
                      }
                    });
                  }
                } else {
                  print('⚠️ Scanned barcode but no raw value');
                }
              }
            },
          ),

          // Overlay with scan area guide
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Align payment code\nwithin the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom instructions with test buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan Payment QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Align the QR code within the frame above, or use test buttons',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Test buttons for development
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _simulateScan('183_DAYS_9500'),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Test 183 Days'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _simulateScan('366_DAYS_19000'),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Test 366 Days'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => controller.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on),
                        label: const Text('Flash'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _simulateScan(String simulatedCode) {
    print('🎭 Simulating scan of: "$simulatedCode"');

    setState(() {
      _isScanning = true;
    });

    // Validate the simulated barcode
    if (_isValidPaymentBarcode(simulatedCode)) {
      print('✅ Simulated scan valid: $simulatedCode');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated scan: $simulatedCode'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );

      // Process the simulated scan
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onBarcodeScanned(simulatedCode);
        Navigator.of(context).pop();
      });
    } else {
      print('❌ Simulated scan invalid: $simulatedCode');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid simulated barcode format'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      // Reset scanning flag
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      });
    }
  }

  bool _isValidPaymentBarcode(String code) {
    // Validate barcode format: XXX_DAYS_YYYY where XXX is 183 or 366, YYYY is amount
    print('🔍 Validating barcode format: "$code"');

    try {
      final parts = code.split('_');
      print('🔍 Split parts: $parts');

      if (parts.length != 3) {
        print('❌ Invalid part count: ${parts.length}, expected 3');
        return false;
      }

      final daysStr = parts[0];
      final daysKeyword = parts[1];
      final amountStr = parts[2];

      print('🔍 Parsed - Days: "$daysStr", Keyword: "$daysKeyword", Amount: "$amountStr"');

      // Check keyword
      if (daysKeyword != 'DAYS') {
        print('❌ Invalid keyword: "$daysKeyword", expected "DAYS"');
        return false;
      }

      final days = int.parse(daysStr);
      final amount = int.parse(amountStr);

      print('🔍 Parsed values - Days: $days, Amount: $amount');

      // Check if days is valid (183 or 366)
      if (days != 183 && days != 366) {
        print('❌ Invalid days value: $days, expected 183 or 366');
        return false;
      }

      // Check if amount matches expected for days
      final expectedAmount = days == 183 ? 9500 : 19000;
      if (amount != expectedAmount) {
        print('❌ Amount mismatch: got $amount, expected $expectedAmount for $days days');
        return false;
      }

      print('✅ Valid payment barcode: $days days, KES $amount');
      return true;
    } catch (e) {
      print('❌ Validation error: $e');
      return false;
    }
  }
}

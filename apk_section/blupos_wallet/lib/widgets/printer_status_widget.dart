import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/printer_service.dart';

/// Yellow card widget that displays thermal printer connection status
class PrinterStatusWidget extends StatefulWidget {
  const PrinterStatusWidget({Key? key}) : super(key: key);

  @override
  _PrinterStatusWidgetState createState() => _PrinterStatusWidgetState();
}

class _PrinterStatusWidgetState extends State<PrinterStatusWidget> {
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    // Check printer status every 60 seconds for better efficiency
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkPrinterStatus();
    });

    // Initial status check
    _checkPrinterStatus();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPrinterStatus() async {
    if (!mounted) return;

    try {
      debugPrint('🔄 [PRINTER] Starting automatic status check...');
      final printerService = Provider.of<PrinterService>(context, listen: false);
      debugPrint('🔍 [PRINTER] Discovering Bluetooth devices...');
      await printerService.discoverDevices();

      final status = printerService.isConnected
          ? '✅ CONNECTED: ${printerService.printerName}'
          : '❌ DISCONNECTED';
      debugPrint('📊 [PRINTER] Status check completed: $status');
    } catch (e) {
      debugPrint('❌ [PRINTER] Status check failed: $e');
    }
  }

  Future<void> _showDeviceSelection(BuildContext context, PrinterService printerService) async {
    debugPrint('🔍 [UI] User initiated manual printer connection');
    debugPrint('🔄 [UI] Showing discovery dialog...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Discovering Printers...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for thermal printers...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('🔍 [BLUETOOTH] Starting device discovery...');
      final devices = await printerService.discoverDevices();
      debugPrint('✅ [BLUETOOTH] Discovery completed. Found ${devices.length} devices');

      Navigator.of(context).pop(); // Close loading dialog

      if (devices.isEmpty) {
        debugPrint('⚠️ [BLUETOOTH] No thermal printers found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔍 No thermal printers found'),
            action: SnackBarAction(
              label: 'HELP',
              onPressed: () {
                debugPrint('ℹ️ [UI] User requested Bluetooth help');
                // Show Bluetooth help instructions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('💡 Bluetooth Help: 1) Turn on Bluetooth 2) Pair your thermal printer 3) Try again'),
                    duration: Duration(seconds: 5),
                  )
                );
              },
            ),
          )
        );
        return;
      }

      debugPrint('📋 [UI] Displaying ${devices.length} available printers');
      for (var device in devices) {
        debugPrint('   - ${device.name ?? 'Unknown'} (${device.remoteId})');
      }

              // Use deviceInfos from the printer service which includes proper names
              final deviceList = printerService.deviceInfos.map((deviceInfo) {
                final device = deviceInfo.device;
                final name = deviceInfo.name.trim();
                final macAddress = deviceInfo.macAddress;

                final displayName = name.isNotEmpty ? name : 'Unknown Device';
                String deviceType = 'Unknown Device';
                bool isThermalPrinter = false;
                Color typeColor = Colors.grey;

                // Check for thermal printer patterns
                final lowerName = name.toLowerCase();
                if (lowerName.contains('printer') ||
                    lowerName.contains('tm-') ||
                    lowerName.contains('epson') ||
                    lowerName.contains('star') ||
                    lowerName.contains('citizen') ||
                    lowerName.contains('615-') ||
                    lowerName.startsWith('r58p') ||
                    lowerName.contains('thermal')) {
                  deviceType = 'Thermal Printer';
                  typeColor = Colors.green;
                  isThermalPrinter = true;
                } else if (lowerName.contains('headphone') ||
                           lowerName.contains('earbuds') ||
                           lowerName.contains('speaker')) {
                  deviceType = 'Audio Device';
                  typeColor = Colors.blue;
                } else if (lowerName.contains('mouse') ||
                           lowerName.contains('keyboard') ||
                           lowerName.contains('trackpad')) {
                  deviceType = 'Input Device';
                  typeColor = Colors.orange;
                } else if (lowerName.contains('phone') ||
                           lowerName.contains('android') ||
                           lowerName.contains('iphone')) {
                  deviceType = 'Mobile Device';
                  typeColor = Colors.purple;
                } else if (name.isNotEmpty && name != 'Unknown Device') {
                  deviceType = 'Bluetooth Device';
                  typeColor = Colors.grey;
                }

                return {
                  'device': device,
                  'displayName': displayName,
                  'deviceType': deviceType,
                  'typeColor': typeColor,
                  'isThermalPrinter': isThermalPrinter,
                  'macAddress': macAddress,
                };
              }).toList();

              // Sort devices: thermal printers first, then by name
              deviceList.sort((a, b) {
                final aIsThermal = a['isThermalPrinter'] as bool;
                final bIsThermal = b['isThermalPrinter'] as bool;
                if (aIsThermal && !bIsThermal) return -1;
                if (!aIsThermal && bIsThermal) return 1;
                return (a['displayName'] as String).compareTo(b['displayName'] as String);
              });

              // Show device selection modal with enhanced interface
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Thermal Printer'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Available Bluetooth devices (thermal printers prioritized):',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: deviceList.length,
                            itemBuilder: (context, index) {
                              final deviceInfo = deviceList[index];
                              final device = deviceInfo['device'] as fbp.BluetoothDevice;
                              final displayName = deviceInfo['displayName'] as String;
                              final deviceType = deviceInfo['deviceType'] as String;
                              final typeColor = deviceInfo['typeColor'] as Color;
                              final isThermalPrinter = deviceInfo['isThermalPrinter'] as bool;
                              final macAddress = deviceInfo['macAddress'] as String;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                elevation: isThermalPrinter ? 4 : 2,
                                color: isThermalPrinter ? Colors.green[50] : Colors.white,
                                child: ListTile(
                                  leading: Icon(
                                    isThermalPrinter ? Icons.print : Icons.bluetooth,
                                    color: isThermalPrinter ? Colors.green : Colors.blue,
                                    size: 32,
                                  ),
                                  title: Text(
                                    displayName.isNotEmpty ? displayName : 'Unknown Device',
                                    style: TextStyle(
                                      fontWeight: isThermalPrinter ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 16,
                                      color: isThermalPrinter ? Colors.green[800] : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deviceType,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: typeColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (isThermalPrinter)
                                        const Text(
                                          '✅ Recommended for thermal printing',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      Text(
                                        'ID: ${macAddress.length >= 6 ? macAddress.substring(macAddress.length - 6) : macAddress}', // Show last 6 chars only or full if shorter
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: isThermalPrinter ? Colors.green : Colors.grey,
                                  ),
                                  onTap: () async {
                                    debugPrint('🖱️ [UI] User selected device: ${displayName} (${macAddress})');
                                    Navigator.of(context).pop();
                                    await _connectToDevice(context, printerService, device);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        debugPrint('❌ [UI] User cancelled device selection');
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Discovery failed: $e');
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discovery failed: ${e.toString()}'),
          action: SnackBarAction(
            label: 'HELP',
            onPressed: () {
              // Show detailed troubleshooting help
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Bluetooth Troubleshooting'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Turn on Bluetooth in device settings'),
                      Text('2. Pair your thermal printer in Bluetooth settings'),
                      Text('3. Grant all Bluetooth permissions to this app'),
                      Text('4. Ensure location services are enabled'),
                      Text('5. Restart Bluetooth if issues persist'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        )
      );
    }
  }

  Future<void> _connectToDevice(BuildContext context, PrinterService printerService, dynamic device) async {
    debugPrint('🔌 [BLUETOOTH] Starting connection to ${device.name ?? 'Unknown'} (${device.remoteId})');
    debugPrint('🔄 [UI] Showing connection dialog...');

    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context; // Store dialog context
        return AlertDialog(
          title: const Text('Connecting...'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Pairing and connecting to printer...'),
            ],
          ),
        );
      },
    );

    try {
      debugPrint('🔌 [BLUETOOTH] Attempting to pair and connect...');
      final connected = await printerService.pairAndConnectToDevice(device);

      // Close connecting dialog using stored context
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      if (connected) {
        debugPrint('✅ [BLUETOOTH] Successfully connected to ${printerService.printerName}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Connected to ${printerService.printerName}'))
          );
        }
      } else {
        debugPrint('❌ [BLUETOOTH] Connection attempt failed');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Failed to connect to printer'))
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [BLUETOOTH] Connection error: $e');
      // Close connecting dialog using stored context
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Connection failed: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterService>(
      builder: (context, printerService, child) {
        final isConnected = printerService.isConnected;
        final printerName = printerService.printerName;

        return Card(
          color: Colors.yellow[100],
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Status icon
                Icon(
                  isConnected ? Icons.print : Icons.print_disabled,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),

                // Status text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thermal Printer',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected
                          ? 'Connected: $printerName'
                          : 'Not Connected',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Connection action button
                TextButton(
                  onPressed: () {
                    if (isConnected) {
                      // If connected, show disconnect option
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Disconnect Printer'),
                          content: const Text('Are you sure you want to disconnect the current printer?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await printerService.disconnect();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Printer disconnected'))
                                );
                              },
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // If not connected, show device selection
                      _showDeviceSelection(context, printerService);
                    }
                  },
                  child: Text(isConnected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact printer status indicator for app bars or headers
class PrinterStatusIndicator extends StatelessWidget {
  final double size;

  const PrinterStatusIndicator({
    Key? key,
    this.size = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterService>(
      builder: (context, printerService, child) {
        final isConnected = printerService.isConnected;

        return Tooltip(
          message: isConnected
            ? 'Printer Connected: ${printerService.printerName}'
            : 'Printer Not Connected',
          child: Icon(
            isConnected ? Icons.print : Icons.print_disabled,
            color: isConnected ? Colors.green : Colors.red,
            size: size,
          ),
        );
      },
    );
  }
}

/// Floating action button for quick printer actions
class PrinterFab extends StatelessWidget {
  const PrinterFab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterService>(
      builder: (context, printerService, child) {
        return FloatingActionButton(
          onPressed: () => _showPrinterMenu(context, printerService),
          backgroundColor: printerService.isConnected ? Colors.green : Colors.orange,
          child: const Icon(Icons.print),
          tooltip: 'Printer Actions',
        );
      },
    );
  }

  void _showPrinterMenu(BuildContext context, PrinterService printerService) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  printerService.isConnected ? Icons.print : Icons.print_disabled,
                  color: printerService.isConnected ? Colors.green : Colors.red,
                ),
                title: Text(
                  printerService.isConnected
                    ? 'Connected: ${printerService.printerName}'
                    : 'Not Connected'
                ),
                subtitle: const Text('Current printer status'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Discover Printers'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showDeviceDiscovery(context, printerService);
                },
              ),
              if (printerService.isConnected)
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Disconnect Printer'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await printerService.disconnect();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printer disconnected'))
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Check Status'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await printerService.discoverDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        printerService.isConnected
                          ? 'Printer connected: ${printerService.printerName}'
                          : 'No printer connected'
                      )
                    )
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeviceDiscovery(BuildContext context, PrinterService printerService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Discovering Printers...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for thermal printers...'),
          ],
        ),
      ),
    );

    try {
      final devices = await printerService.discoverDevices();
      Navigator.of(context).pop(); // Close loading dialog

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No thermal printers found'))
        );
        return;
      }

      // Show device selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Thermal Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(device.name ?? 'Unknown Printer'),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _connectToDevice(context, printerService, device);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery failed: $e'))
      );
    }
  }

  Future<void> _connectToDevice(BuildContext context, PrinterService printerService, dynamic device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connecting...'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Pairing and connecting to printer...'),
          ],
        ),
      ),
    );

    try {
      final connected = await printerService.pairAndConnectToDevice(device);
      Navigator.of(context).pop(); // Close connecting dialog

      if (connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${printerService.printerName}'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to printer'))
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close connecting dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e'))
      );
    }
  }
}

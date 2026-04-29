import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'activation_service.dart';

class HeartbeatService {
  static Timer? _heartbeatTimer;
  static bool _isRunning = false;
  static String? _currentAccountId;
  static String? _currentLicenseKey;

  static bool get isRunning => _isRunning;

  // Start heartbeat service
  static Future<void> startHeartbeat({
    required String accountId,
    required String licenseKey,
  }) async {
    if (_isRunning) {
      print('🔄 Heartbeat service already running');
      return;
    }

    _currentAccountId = accountId;
    _currentLicenseKey = licenseKey;

    _isRunning = true;
    print('🚀 Starting heartbeat service for account: $accountId');

    // Send initial heartbeat immediately
    await _sendHeartbeat();

    // Schedule periodic heartbeats every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _sendHeartbeat();
    });
  }

  // Stop heartbeat service
  static void stopHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
    }
    _isRunning = false;
    _currentAccountId = null;
    _currentLicenseKey = null;
    print('🛑 Heartbeat service stopped');
  }

  // Send heartbeat
  static Future<void> _sendHeartbeat() async {
    if (_currentAccountId == null || _currentLicenseKey == null) {
      print('❌ Cannot send heartbeat: missing account ID or license key');
      return;
    }

    try {
      // Get battery level (simulated for now)
      final batteryLevel = await _getBatteryLevel();

      // Get network type
      final networkType = await _getNetworkType();

      final result = await ActivationService.sendHeartbeat(
        accountId: _currentAccountId!,
        licenseKey: _currentLicenseKey!,
        batteryLevel: batteryLevel,
        networkType: networkType,
      );

      if (result['success'] == true) {
        print('💓 Heartbeat sent successfully at ${DateTime.now()}');
      } else {
        print('❌ Heartbeat failed: ${result['message']}');
      }
    } catch (e) {
      print('❌ Heartbeat error: $e');
    }
  }

  // Get battery level (simulated)
  static Future<int> _getBatteryLevel() async {
    // TODO: Implement actual battery level detection
    // For now, return a simulated value
    return 85; // 85%
  }

  // Get network type
  static Future<String> _getNetworkType() async {
    try {
      // Check if connected to WiFi or mobile data
      final result = await Process.run('sh', ['-c', 'iwconfig 2>/dev/null | grep ESSID || echo "mobile"']);
      if (result.stdout.toString().contains('ESSID')) {
        return 'WIFI';
      } else {
        return 'MOBILE';
      }
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  // Check if heartbeat should be running based on app state
  static Future<bool> shouldHeartbeatRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActivated = prefs.getBool('isActivated') ?? false;
      final licenseExpiry = prefs.getString('licenseExpiry');

      if (!isActivated || licenseExpiry == null) {
        return false;
      }

      final expiryDate = DateTime.tryParse(licenseExpiry);
      if (expiryDate == null || expiryDate.isBefore(DateTime.now())) {
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking heartbeat state: $e');
      return false;
    }
  }

  // Resume heartbeat if app was restarted and should be running
  static Future<void> resumeIfNeeded() async {
    if (_isRunning) return;

    final shouldRun = await shouldHeartbeatRun();
    if (!shouldRun) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('persistentAccountId');
      final licenseKey = prefs.getString('activationCode');

      if (accountId != null && licenseKey != null) {
        await startHeartbeat(accountId: accountId, licenseKey: licenseKey);
        print('▶️ Heartbeat service resumed');
      }
    } catch (e) {
      print('❌ Error resuming heartbeat: $e');
    }
  }
}

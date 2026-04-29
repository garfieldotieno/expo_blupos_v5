import '../utils/api_client.dart';

class ActivationService {
  // Generate unique device ID
  static String generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'APK${timestamp.toString().substring(8)}${random.toString().padLeft(4, '0')}';
  }

  // Discover BluPOS master server
  static Future<String?> discoverMasterServer() async {
    return await ApiClient.discoverMasterServer();
  }

  // Test connection to discovered master
  static Future<bool> testMasterConnection() async {
    return await ApiClient.testConnection();
  }

  // Register device with BluPOS master
  static Future<Map<String, dynamic>> registerDevice({
    required String deviceName,
    String? deviceIp,
  }) async {
    final deviceData = {
      'device_uid': generateDeviceId(),
      'device_name': deviceName,
      'device_ip': deviceIp ?? 'auto',
      'device_type': 'mobile_wallet',
      'capabilities': ['sms_parsing', 'micro_server', 'payment_processing'],
    };

    try {
      final response = await ApiClient.post('/api/apk/devices', deviceData);
      return {
        'success': true,
        'device_uid': response['device_uid'],
        'activation_code': response['activation_code'],
        'message': 'Device registered successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to register device',
      };
    }
  }

  // Activate device using activation code
  static Future<Map<String, dynamic>> activateDevice({
    required String activationCode,
    String? deviceIp,
  }) async {
    final activationData = {
      'activation_code': activationCode,
      'device_ip': deviceIp ?? 'auto',
      'activation_time': DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiClient.post('/api/apk/activate', activationData);

      // Create APK license after successful activation
      final licenseResult = await createApkLicense(
        response['device_uid'],
        licenseType: 'APK_BASIC',
      );

      return {
        'success': true,
        'device_uid': response['device_uid'],
        'license_created': licenseResult['success'],
        'license_type': 'APK_BASIC',
        'message': 'Device activated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Activation failed',
      };
    }
  }

  // Create APK license for device
  static Future<Map<String, dynamic>> createApkLicense(
    String deviceUid, {
    String licenseType = 'APK_BASIC',
  }) async {
    final licenseData = {
      'device_uid': deviceUid,
      'license_type': licenseType,
      'features': _getLicenseFeatures(licenseType),
    };

    try {
      final response = await ApiClient.post('/api/apk/licenses', licenseData);
      return {
        'success': true,
        'license_id': response['id'],
        'license_type': licenseType,
        'features': _getLicenseFeatures(licenseType),
        'expiry_date': response['license_expiry'],
        'message': 'License created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'License creation failed',
      };
    }
  }

  // Get license features based on type
  static List<String> _getLicenseFeatures(String licenseType) {
    switch (licenseType) {
      case 'APK_PREMIUM':
        return [
          'wallet_full_access',
          'sms_parsing_full',
          'micro_server_full',
          'reports_advanced',
          'export_pdf_csv',
          'real_time_sync',
        ];
      case 'APK_BASIC':
      default:
        return [
          'wallet_basic',
          'sms_parsing_limited',
          'micro_server_basic',
          'reports_basic',
        ];
    }
  }

  // Check device activation status
  static Future<Map<String, dynamic>> checkActivationStatus(String deviceUid) async {
    try {
      final response = await ApiClient.get('/api/apk/devices/$deviceUid');
      return {
        'success': true,
        'is_activated': response['activated_at'] != null,
        'device_name': response['device_name'],
        'last_seen': response['last_seen'],
        'license_status': response['license_status'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to check activation status',
      };
    }
  }

  // Update device status (online/offline)
  static Future<Map<String, dynamic>> updateDeviceStatus({
    required String deviceUid,
    required bool isOnline,
    String? deviceIp,
  }) async {
    final statusData = {
      'device_uid': deviceUid,
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
      'device_ip': deviceIp,
    };

    try {
      final response = await ApiClient.put('/api/apk/devices/$deviceUid', statusData);
      return {
        'success': true,
        'message': 'Device status updated',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update device status',
      };
    }
  }

  // Send heartbeat to web system
  static Future<Map<String, dynamic>> sendHeartbeat({
    required String accountId,
    required String licenseKey,
    int batteryLevel = 100,
    String networkType = 'WIFI',
  }) async {
    final heartbeatData = {
      'account_id': accountId,
      'license_key': licenseKey,
      'timestamp': DateTime.now().toIso8601String(),
      'battery_level': batteryLevel,
      'network_type': networkType,
    };

    try {
      final response = await ApiClient.post('/heartbeat', heartbeatData);
      return {
        'success': true,
        'message': 'Heartbeat sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send heartbeat',
      };
    }
  }
}

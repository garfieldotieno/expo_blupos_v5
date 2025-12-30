import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MicroServerService {
  static const int PORT = 8085;
  static HttpServer? _server;
  static bool _isRunning = false;
  static late String _currentDeviceId;

  // Dummy activation codes for prototyping
  static const Map<String, Map<String, dynamic>> _dummyActivationCodes = {
    'BLUPOS2025': {
      'description': 'Demo activation code for development',
      'license_days': 30,
      'features': ['wallet', 'reports', 'activation']
    },
    'DEMO2025': {
      'description': 'Demo code for testing purposes',
      'license_days': 7,
      'features': ['wallet', 'reports']
    }
  };

  static bool get isRunning => _isRunning;
  static String get currentDeviceId => _currentDeviceId;

  static Map<String, Map<String, dynamic>> get dummyCodes => _dummyActivationCodes;

  static Future<void> startServer() async {
    if (_isRunning) {
      print('🔄 Micro-server already running on port $PORT');
      return;
    }

    // Load or generate persistent device ID
    final prefs = await SharedPreferences.getInstance();
    String? existingDeviceId = prefs.getString('persistentDeviceId');

    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      // Use existing device ID
      _currentDeviceId = existingDeviceId;
      print('📱 Using existing device ID: $_currentDeviceId');
    } else {
      // Generate new device ID and persist it
      _currentDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('persistentDeviceId', _currentDeviceId);
      print('🆕 Generated new device ID: $_currentDeviceId');
    }

    try {
      final router = Router();

      // Health check endpoint
      router.get('/health', _healthHandler);

      // Activation endpoint
      router.post('/activate', _activateHandler);

      // Test utilities endpoint
      router.post('/test', _testHandler);

      // CORS headers for web compatibility
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsHeaders())
          .addHandler(router);

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, PORT);

      _isRunning = true;

      final localIp = _getLocalIp();
      print('🚀 Micro-server started successfully!');
      print('📱 Current Device ID: $_currentDeviceId');
      print('📡 Server running on:');
      print('   Local: http://localhost:$PORT');
      print('   Network: http://$localIp:$PORT');
      print('📋 Available endpoints:');
      print('   GET  /health  - Health check');
      print('   POST /activate - Device activation & license management');
      print('   POST /test    - Testing utilities (force expiry, reset)');
      print('🔑 Available activation codes for testing:');
      _dummyActivationCodes.forEach((code, details) {
        print('   $code - ${details['description']} (${details['license_days']} days)');
      });
      print('🧪 Test endpoints for UI iteration (use device_id: $_currentDeviceId):');
      print('   POST /test?action=force_expiry&device_id=$_currentDeviceId - Force license expiry');
      print('   POST /test?action=reset_first_time&device_id=$_currentDeviceId - Reset to first-time state');
      print('   POST /test?action=get_status&device_id=$_currentDeviceId - Get current status');
      print('   POST /activate?action=check_expiry&device_id=$_currentDeviceId - Check license status');

    } catch (e) {
      print('❌ Failed to start micro-server: $e');
      _isRunning = false;
      rethrow;
    }
  }

  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      print('🛑 Micro-server stopped');
    }
  }

  static Middleware _corsHeaders() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
        });
      };
    };
  }

  static Future<Response> _healthHandler(Request request) async {
    try {
      // Check BluPOS backend state automatically
      final bluposState = await _checkBluPOSState();

      final response = {
        'status': 'ok',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'server': 'BluPOS Micro-Server',
        'version': '1.0.0',
        'port': PORT,
        'blupos_sync': bluposState,
      };

      print('🏥 Health check requested - ${DateTime.now()} - BluPOS state: ${bluposState['app_state']}');
      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ Health check error: $e');
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'server': 'BluPOS Micro-Server',
          'version': '1.0.0',
          'port': PORT,
          'blupos_sync': {
            'status': 'error',
            'error': e.toString(),
            'app_state': 'unknown'
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<Response> _testHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final action = data['action'] as String?;
      final deviceId = data['device_id'] as String?;

      print('🧪 Test request - Action: $action, Device: $deviceId');

      if (action == null || deviceId == null) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Missing required fields: action, device_id'
        }), headers: {'Content-Type': 'application/json'});
      }

      final prefs = await SharedPreferences.getInstance();
      final response = await _handleTestAction(action, deviceId, prefs);

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'},
      );

    } catch (e) {
      print('❌ Test error: $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Internal server error: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  static Future<Response> _activateHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final action = data['action'] as String?;
      final deviceId = data['device_id'] as String?;
      final activationCode = data['activation_code'] as String?;

      print('🔐 Activation request - Action: $action, Device: $deviceId');

      if (action == null || deviceId == null) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Missing required fields: action, device_id'
        }), headers: {'Content-Type': 'application/json'});
      }

      final prefs = await SharedPreferences.getInstance();
      final response = await _handleActivationAction(action, deviceId, activationCode, prefs);

      return Response.ok(
        jsonEncode(response),
        headers: {'Content-Type': 'application/json'},
      );

    } catch (e) {
      print('❌ Activation error: $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Internal server error: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  static Future<Map<String, dynamic>> _handleTestAction(
    String action,
    String deviceId,
    SharedPreferences prefs,
  ) async {
    switch (action) {
      case 'force_expiry':
        // Force license to expire immediately
        final expiredDate = DateTime.now().subtract(const Duration(days: 1));
        await prefs.setString('licenseExpiry', expiredDate.toIso8601String());

        print('⚠️ License forced to expire for device: $deviceId');

        return {
          'status': 'success',
          'message': 'License expired',
          'app_state': 'expired',
          'license_expiry': 'EXPIRED',
          'device_id': deviceId,
        };

      case 'reset_first_time':
        // Reset device to first-time state
        await prefs.remove('isActivated');
        await prefs.remove('licenseExpiry');
        await prefs.remove('deviceId');
        await prefs.remove('activationCode');
        await prefs.remove('features');

        print('🔄 Device reset to first-time state for device: $deviceId');

        return {
          'status': 'success',
          'message': 'Reset to first time',
          'app_state': 'first_time',
          'device_id': deviceId,
        };

      case 'update_license':
        final licenseType = prefs.getString('license_type') as String?;
        if (licenseType == null || (licenseType != 'BLUPOS2025' && licenseType != 'DEMO2025')) {
          return {
            'status': 'error',
            'message': 'Invalid license type. Use BLUPOS2025 or DEMO2025'
          };
        }

        final codeData = _dummyActivationCodes[licenseType]!;
        final licenseDays = codeData['license_days'] as int;

        // Update license with new expiry - use UTC
        final expiryDate = DateTime.now().toUtc().add(Duration(days: licenseDays));
        await prefs.setString('licenseExpiry', expiryDate.toIso8601String());
        await prefs.setBool('isActivated', true);

        print('🔄 License updated to $licenseType for device: $deviceId');

        return {
          'status': 'success',
          'message': 'License updated',
          'license_type': licenseType,
          'license_expiry': expiryDate.toIso8601String(),
          'device_id': deviceId,
        };

      case 'get_status':
        final isActivated = prefs.getBool('isActivated') ?? false;
        final expiryString = prefs.getString('licenseExpiry');
        final licenseType = prefs.getString('activationCode');
        final deviceIdStored = prefs.getString('deviceId');

        String appState = 'first_time';
        int? daysRemaining;

        if (isActivated && expiryString != null) {
          final expiryDate = DateTime.tryParse(expiryString);
          if (expiryDate != null) {
            final now = DateTime.now();
            if (expiryDate.isBefore(now)) {
              appState = 'expired';
            } else {
              appState = 'active';
              daysRemaining = expiryDate.difference(now).inDays;
            }
          }
        }

        print('📊 Status check for device: $deviceId');

        return {
          'status': 'success',
          'app_state': appState,
          'license_type': licenseType,
          'license_expiry': expiryString,
          'days_remaining': daysRemaining,
          'activation_code': licenseType,
          'device_id': deviceIdStored,
        };

      default:
        return {
          'status': 'error',
          'message': 'Unknown test action: $action'
        };
    }
  }

  static Future<Map<String, dynamic>> _handleActivationAction(
    String action,
    String deviceId,
    String? activationCode,
    SharedPreferences prefs,
  ) async {
    switch (action) {
      case 'first_time':
        if (activationCode == null) {
          return {
            'status': 'error',
            'message': 'Activation code required for first-time activation'
          };
        }

        // Simulate activation logic
        final isValidCode = _validateActivationCode(activationCode);
        if (!isValidCode) {
          return {
            'status': 'error',
            'message': 'Invalid activation code'
          };
        }

        // Special handling for BLUPOS2025 - direct navigation to active page
        if (activationCode == 'BLUPOS2025') {
          // Set device as activated without going through activation process
          await prefs.setBool('isActivated', true);
          final expiryDate = DateTime.now().toUtc().add(const Duration(days: 30));
          await prefs.setString('licenseExpiry', expiryDate.toIso8601String());
          await prefs.setString('deviceId', deviceId);
          await prefs.setString('activationCode', activationCode);
          await prefs.setStringList('features', ['wallet', 'reports', 'activation']);

          print('🚀 BLUPOS2025: Direct navigation to active page for device: $deviceId');

          return {
            'status': 'success',
            'message': 'Direct navigation to active page',
            'license_expiry': expiryDate.toIso8601String(),
            'app_state': 'active',
            'device_id': deviceId,
            'direct_navigation': true,
          };
        }

        // Regular activation for other codes
        final codeData = _dummyActivationCodes[activationCode]!;
        final licenseDays = codeData['license_days'] as int;

        // Set activation status and license expiry - use UTC like backend
        await prefs.setBool('isActivated', true);
        final expiryDate = DateTime.now().toUtc().add(Duration(days: licenseDays));
        await prefs.setString('licenseExpiry', expiryDate.toIso8601String());
        await prefs.setString('deviceId', deviceId);
        await prefs.setString('activationCode', activationCode);
        await prefs.setStringList('features', List<String>.from(codeData['features'] as List));

        print('✅ First-time activation successful for device: $deviceId');

        return {
          'status': 'success',
          'message': 'Device activated successfully',
          'license_expiry': expiryDate.toIso8601String(),
          'app_state': 'active',
          'device_id': deviceId,
        };

      case 'check_expiry':
        final isActivated = prefs.getBool('isActivated') ?? false;
        final expiryString = prefs.getString('licenseExpiry');
        final licenseType = prefs.getString('activationCode');

        if (!isActivated) {
          return {
            'status': 'success',
            'app_state': 'first_time',
            'message': 'Device not activated'
          };
        }

        if (expiryString != null) {
          final expiryDate = DateTime.tryParse(expiryString);
          if (expiryDate != null) {
            final now = DateTime.now();
            if (expiryDate.isBefore(now)) {
              final daysOverdue = now.difference(expiryDate).inDays;
              return {
                'status': 'success',
                'app_state': 'expired',
                'license_expiry': expiryString,
                'days_overdue': daysOverdue,
                'license_type': licenseType,
                'message': 'License expired'
              };
            } else {
              final daysRemaining = expiryDate.difference(now).inDays;
              return {
                'status': 'success',
                'app_state': 'active',
                'license_expiry': expiryString,
                'days_remaining': daysRemaining,
                'license_type': licenseType,
                'message': 'License active'
              };
            }
          }
        }

        return {
          'status': 'success',
          'app_state': 'active',
          'license_expiry': expiryString,
          'license_type': licenseType,
          'message': 'License active'
        };

      case 'reactivate':
        if (activationCode == null) {
          return {
            'status': 'error',
            'message': 'Activation code required for reactivation'
          };
        }

        final isValidCode = _validateActivationCode(activationCode);
        if (!isValidCode) {
          return {
            'status': 'error',
            'message': 'Invalid activation code'
          };
        }

        // Extend license for another 30 days - use UTC
        final newExpiryDate = DateTime.now().toUtc().add(const Duration(days: 30));
        await prefs.setString('licenseExpiry', newExpiryDate.toIso8601String());

        print('🔄 License reactivated for device: $deviceId');

        return {
          'status': 'success',
          'message': 'License reactivated successfully',
          'license_expiry': newExpiryDate.toIso8601String(),
          'app_state': 'active',
          'device_id': deviceId,
        };

      default:
        return {
          'status': 'error',
          'message': 'Unknown action: $action'
        };
    }
  }

  static bool _validateActivationCode(String code) {
    // Check against dummy activation codes for prototyping
    return _dummyActivationCodes.containsKey(code);
  }

  static Future<Map<String, dynamic>> _checkBluPOSState() async {
    try {
      // Use http package for simpler POST request to BluPOS backend
      final url = Uri.parse('http://localhost:8080/activate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'check_expiry'}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status'] == 'success') {
        print('✅ BluPOS state synced: ${data['app_state']}');
        return {
          'status': 'success',
          'app_state': data['app_state'],
          'account_id': data['account_id'],
          'license_expiry': data['license_expiry'],
          'days_remaining': data['days_remaining'],
          'license_type': data['license_type'],
        };
      } else {
        print('⚠️ BluPOS state check failed: ${data['message']}');
        return {
          'status': 'error',
          'app_state': 'unknown',
          'error': data['message'],
        };
      }
    } catch (e) {
      print('❌ BluPOS connection failed: $e');
      return {
        'status': 'error',
        'app_state': 'disconnected',
        'error': e.toString(),
      };
    }
  }

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return 'Unknown';
  }
}

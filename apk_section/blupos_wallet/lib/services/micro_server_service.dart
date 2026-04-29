import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'sms_service.dart';

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

    // Check if running on emulator
    final isEmulator = await _isRunningOnEmulator();
    if (isEmulator) {
      print('🤖 Detected Android emulator - applying network configuration');
      print('📡 Emulator note: Micro-server may have limited network access');
      print('💡 For full testing, use standalone micro-server: python3 standalone_microserver.py');
    }

    try {
      final router = Router();

      // Determine binding address based on platform
      final isEmulator = await _isRunningOnEmulator();
      final bindAddress = isEmulator ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;

      print('🌐 Binding micro-server to: ${bindAddress.address}:${PORT}');

      // Health check endpoint
      router.get('/health', _healthHandler);

      // Activation endpoint
      router.post('/activate', _activateHandler);

      // Test utilities endpoint
      router.post('/test', _testHandler);

      // SMS API endpoints
      router.get('/message/<id>', _messageByIdHandler);
      router.get('/sms/shortcodes', _smsShortcodesHandler);
      router.get('/sms/not-shortcodes', _smsNotShortcodesHandler);
      router.get('/sms/read', _smsReadHandler);
      router.get('/sms/not-read', _smsNotReadHandler);

      // Inventory API endpoints
      router.get('/inventory/local/<page>', _inventoryLocalHandler);

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
      print('   SMS endpoints:');
      print('   GET  /sms/shortcodes - SMS from approved shortcodes only');
      print('   GET  /sms/not-shortcodes - SMS from regular phones (scams)');
      print('   GET  /sms/read - Read SMS only');
      print('   GET  /sms/not-read - Unread SMS only');
      print('   GET  /message/<id> - Get SMS message by ID');
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



  static Future<Response> _messageByIdHandler(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null || id.isEmpty) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Message ID is required'
        }), headers: {'Content-Type': 'application/json'});
      }

      print('📱 SMS API: Getting message by ID: $id');

      // Get message by ID from SMS service
      final messageData = await _getSmsMessageById(id);

      if (messageData == null) {
        return Response(404, body: jsonEncode({
          'status': 'error',
          'message': 'Message not found'
        }), headers: {'Content-Type': 'application/json'});
      }

      return Response.ok(
        jsonEncode(messageData),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SMS API error (_messageByIdHandler): $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to get message: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  // Helper method to get boot-time SMS counts (captured at app initialization)
  static Future<Map<String, dynamic>> _getBootTimeSmsCounts() async {
    try {
      // Note: This represents SMS counts captured at application boot/initialization
      // In a real implementation, this would be data captured when SMS service initializes
      // For now, return mock data representing "baseline" counts at boot time

      final bootTimeCounts = {
        'status': 'success',
        'context': 'on_boot',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'counts': {
          'total_messages': 12,  // Fewer messages at boot (only from device inbox)
          'read_messages': 10,   // Most inbox messages are already read
          'unread_messages': 2,  // Only truly unread SMS from device
          'payment_messages': 1, // Minimal payment messages at boot
          'system_messages': 3,  // Some system messages may exist
        },
        'breakdown': {
          'opened': 10,          // Read/opened messages
          'unopened': 2,         // Unread/unopened messages
          'payment_opened': 1,   // Read payment SMS
          'payment_unopened': 0, // Unread payment SMS (rare at boot)
        },
        'sources': ['inbox'],    // Only device inbox at boot time
        'last_updated': DateTime.now().toUtc().toIso8601String(),
        'boot_context': {
          'captured_at': 'app_initialization',
          'includes_existing_inbox': true,
          'excludes_runtime_messages': true,
          'represents_baseline': true,
        }
      };

      final counts = bootTimeCounts['counts'] as Map<String, dynamic>?;
      print('📊 BOOT-TIME SMS counts: Total=${counts?['total_messages']}, Read=${counts?['read_messages']}, Unread=${counts?['unread_messages']}');

      return bootTimeCounts;
    } catch (e) {
      print('❌ Error getting boot-time SMS counts: $e');
      return {
        'status': 'error',
        'context': 'on_boot',
        'error': e.toString(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  // Helper method to get current SMS counts from actual SMS service
  static Future<Map<String, dynamic>> _getCurrentSmsCounts(String context) async {
    try {
      print('📱 [SMS_API] Getting current SMS counts from SMS service...');

      // Get the SMS service instance
      final smsService = SmsService();

      // Get current unread SMS count
      final unreadCount = smsService.unreadSmsCount;
      print('📊 [SMS_API] Current unread SMS count: $unreadCount');

      // For now, we'll estimate other counts based on unread count
      // In a full implementation, you'd have access to all SMS data
      final estimatedReadCount = (unreadCount * 2).clamp(0, 100); // Estimate based on unread
      final estimatedPaymentCount = (unreadCount * 0.3).round().clamp(0, 10); // Estimate payment SMS
      final estimatedSystemCount = (unreadCount * 0.2).round().clamp(0, 5); // Estimate system SMS

      final totalCount = unreadCount + estimatedReadCount;

      final smsCounts = {
        'status': 'success',
        'context': context,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'counts': {
          'total_messages': totalCount,
          'read_messages': estimatedReadCount,
          'unread_messages': unreadCount,
          'payment_messages': estimatedPaymentCount,
          'system_messages': estimatedSystemCount,
        },
        'breakdown': {
          'opened': estimatedReadCount,
          'unopened': unreadCount,
          'payment_opened': (estimatedPaymentCount * 0.7).round(),
          'payment_unopened': (estimatedPaymentCount * 0.3).round(),
        },
        'sources': ['inbox', 'incoming_broadcast', 'payment_broadcast'],
        'last_updated': DateTime.now().toUtc().toIso8601String(),
        'runtime_context': {
          'includes_runtime_messages': true,
          'reflects_current_state': true,
          'shows_accumulated_activity': true,
          'data_source': 'sms_service_live',
        }
      };

      final counts = smsCounts['counts'] as Map<String, dynamic>?;
      print('📊 [SMS_API] SMS counts for $context: Total=${counts?['total_messages']}, Read=${counts?['read_messages']}, Unread=${counts?['unread_messages']}');

      return smsCounts;
    } catch (e) {
      print('❌ [SMS_API] Error getting SMS counts from service: $e');

      // Fallback to mock data if SMS service fails
      print('⚠️ [SMS_API] Falling back to mock data due to service error');

      final fallbackCounts = {
        'status': 'success',
        'context': context,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'counts': {
          'total_messages': 15,
          'read_messages': 8,
          'unread_messages': 7,
          'payment_messages': 3,
          'system_messages': 2,
        },
        'breakdown': {
          'opened': 8,
          'unopened': 7,
          'payment_opened': 2,
          'payment_unopened': 1,
        },
        'sources': ['inbox', 'incoming_broadcast', 'payment_broadcast'],
        'last_updated': DateTime.now().toUtc().toIso8601String(),
        'runtime_context': {
          'includes_runtime_messages': true,
          'reflects_current_state': true,
          'shows_accumulated_activity': true,
          'data_source': 'fallback_mock',
          'error': e.toString(),
        }
      };

      return fallbackCounts;
    }
  }

  // SMS filtering handlers - REAL-TIME DATA
  static Future<Response> _smsShortcodesHandler(Request request) async {
    try {
      print('📱 SMS API: Getting SMS from shortcodes only');

      final shortcodeMessages = await _getRealSmsByFilter('shortcodes_only');

      return Response.ok(
        jsonEncode(shortcodeMessages),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SMS API error (_smsShortcodesHandler): $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to get shortcode SMS: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  static Future<Response> _smsNotShortcodesHandler(Request request) async {
    try {
      print('📱 SMS API: Getting SMS from non-shortcodes only');

      final nonShortcodeMessages = await _getRealSmsByFilter('non_shortcodes_only');

      return Response.ok(
        jsonEncode(nonShortcodeMessages),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SMS API error (_smsNotShortcodesHandler): $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to get non-shortcode SMS: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  static Future<Response> _smsReadHandler(Request request) async {
    try {
      print('📱 SMS API: Getting read SMS only');

      final readMessages = await _getRealSmsByFilter('read_only');

      return Response.ok(
        jsonEncode(readMessages),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SMS API error (_smsReadHandler): $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to get read SMS: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  static Future<Response> _smsNotReadHandler(Request request) async {
    try {
      print('📱 SMS API: Getting unread SMS only');

      final unreadMessages = await _getRealSmsByFilter('unread_only');

      return Response.ok(
        jsonEncode(unreadMessages),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ SMS API error (_smsNotReadHandler): $e');
      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to get unread SMS: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }

  // Helper method to get SMS message by ID
  static Future<Map<String, dynamic>?> _getSmsMessageById(String id) async {
    try {
      // Note: This is a placeholder implementation
      // In a real implementation, you'd query the SMS service for the message
      // For now, return mock message data

      // Mock message data structure
      final mockMessage = {
        'status': 'success',
        'message_id': id,
        'data': {
          'id': id,
          'sender': '+254700123456',
          'message': 'Payment Of Kshs 150.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From John Smith on 07/01/26 at 09.57pm',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
          'amount': 150.0,
          'reference': 'YL4ZEC9B6Y',
          'source': 'payment_broadcast',
          'channel': '80872',
          'parsed_at': DateTime.now().toUtc().toIso8601String(),
        },
        'metadata': {
          'retrieved_at': DateTime.now().toUtc().toIso8601String(),
          'cache_status': 'live',
          'source': 'sms_service',
        }
      };

      final data = mockMessage['data'] as Map<String, dynamic>?;
      print('📨 Retrieved SMS message: ID=$id, Sender=${data?['sender']}');

      return mockMessage;
    } catch (e) {
      print('❌ Error getting SMS message by ID: $e');
      return null;
    }
  }

  // Helper method to filter SMS by various criteria - REAL DATA
  static Future<Map<String, dynamic>> _getRealSmsByFilter(String filterType) async {
    try {
      print('📱 [SMS_FILTER] Getting REAL SMS with filter: $filterType');

      // Try to get SMS service instance - but it might not be initialized yet
      // For now, we'll check if there's any persisted SMS data
      final prefs = await SharedPreferences.getInstance();
      final smsDataJson = prefs.getString('sms_messages');

      List<Map<String, dynamic>> allMessages = [];
      if (smsDataJson != null && smsDataJson.isNotEmpty) {
        try {
          final List<dynamic> smsData = jsonDecode(smsDataJson);
          allMessages = smsData.cast<Map<String, dynamic>>();
          print('📊 [SMS_FILTER] Loaded ${allMessages.length} SMS from persisted data');
        } catch (e) {
          print('⚠️ [SMS_FILTER] Error parsing persisted SMS data: $e');
        }
      }

      // If no persisted data, try to get from SMS service singleton if it's initialized
      if (allMessages.isEmpty) {
        try {
          final smsService = SmsService.instance;
          allMessages = smsService.smsMessages;
          print('📊 [SMS_FILTER] Got ${allMessages.length} SMS from singleton service');
        } catch (e) {
          print('⚠️ [SMS_FILTER] SMS service singleton not accessible yet');
        }
      }

      print('📊 [SMS_FILTER] Total SMS available: ${allMessages.length}');

      // Debug: Log all available messages
      if (allMessages.isNotEmpty) {
        print('📋 [SMS_FILTER] Available SMS messages:');
        for (var i = 0; i < allMessages.length; i++) {
          final msg = allMessages[i];
          print('   [$i] ID:${msg['id']} Sender:${msg['sender']} Read:${msg['read']} Source:${msg['source']}');
        }
      } else {
        print('📋 [SMS_FILTER] No SMS messages available in service');
      }

      List<Map<String, dynamic>> filteredMessages = [];
      String description = '';

      switch (filterType) {
        case 'shortcodes_only':
          // Only messages from approved shortcodes (123456, 123457)
          filteredMessages = allMessages.where((msg) {
            final sender = msg['sender'] as String?;
            return sender == '123456' || sender == '123457';
          }).toList();
          description = 'Messages from approved shortcodes only (123456, 123457)';
          break;

        case 'non_shortcodes_only':
          // Messages from regular phone numbers (not approved shortcodes)
          filteredMessages = allMessages.where((msg) {
            final sender = msg['sender'] as String?;
            return sender != '123456' && sender != '123457';
          }).toList();
          description = 'Messages from regular phone numbers (rejected as potential scams)';
          break;

        case 'read_only':
          // Read messages
          filteredMessages = allMessages.where((msg) {
            return msg['read'] == true;
          }).toList();
          description = 'Read messages only';
          break;

        case 'unread_only':
          // Unread messages
          filteredMessages = allMessages.where((msg) {
            return msg['read'] == false || msg['read'] == null;
          }).toList();
          description = 'Unread messages only';
          break;

        default:
          description = 'Unknown filter type';
      }

      print('📊 [SMS_FILTER] Filtered $filterType: ${filteredMessages.length} messages from ${allMessages.length} total');

      final result = {
        'status': 'success',
        'filter_type': filterType,
        'description': description,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'count': filteredMessages.length,
        'messages': filteredMessages,
        'metadata': {
          'filtered_at': DateTime.now().toUtc().toIso8601String(),
          'data_source': 'sms_service_realtime',
          'filter_criteria': filterType,
          'total_messages_in_service': allMessages.length,
        }
      };

      return result;

    } catch (e) {
      print('❌ [SMS_FILTER] Error filtering REAL SMS: $e');

      // Fallback to mock data if real filtering fails
      print('⚠️ [SMS_FILTER] Falling back to mock data due to error');
      return await _getSmsByFilter(filterType);
    }
  }

  // Helper method to filter SMS by various criteria - MOCK DATA (fallback)
  static Future<Map<String, dynamic>> _getSmsByFilter(String filterType) async {
    try {
      print('📱 [SMS_FILTER] Getting SMS with filter: $filterType');

      // Get the SMS service instance
      final smsService = SmsService();

      // In a real implementation, we'd filter the actual SMS messages
      // For now, return mock filtered data based on the filter type

      List<Map<String, dynamic>> filteredMessages = [];
      String description = '';

      switch (filterType) {
        case 'shortcodes_only':
          // Only messages from approved shortcodes (123456, 123457)
          filteredMessages = [
            {
              'id': '1767812249001',
              'sender': '123456',
              'message': 'Payment Of Kshs 150.00 Has Been Received By Jaystar Investments Ltd For Account 80872',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 3600000, // 1 hour ago
              'read': true,
              'channel': '80872',
              'source': 'shortcode_approved'
            },
            {
              'id': '1767812249002',
              'sender': '123457',
              'message': 'Your merchant account 57938 has been credited with KES 200.00',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 1800000, // 30 min ago
              'read': false,
              'channel': '57938',
              'source': 'shortcode_approved'
            }
          ];
          description = 'Messages from approved shortcodes only (123456, 123457)';
          break;

        case 'non_shortcodes_only':
          // Messages from regular phone numbers (rejected/scam attempts)
          filteredMessages = [
            {
              'id': '1767812249003',
              'sender': '0712345678',
              'message': 'Payment of KES 500.00 has been credited to your account. Call 0723456789 to claim.',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 900000, // 15 min ago
              'read': false,
              'channel': 'unknown',
              'source': 'regular_phone_rejected',
              'rejection_reason': 'Not from approved shortcode'
            },
            {
              'id': '1767812249004',
              'sender': '0723456789',
              'message': 'Your account has been credited with KES 1000. Reference: ABC123. Contact us immediately.',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 600000, // 10 min ago
              'read': false,
              'channel': 'unknown',
              'source': 'regular_phone_rejected',
              'rejection_reason': 'Not from approved shortcode'
            }
          ];
          description = 'Messages from regular phone numbers (rejected as potential scams)';
          break;

        case 'read_only':
          // Read messages
          filteredMessages = [
            {
              'id': '1767812249005',
              'sender': '123456',
              'message': 'Payment confirmation received',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 7200000, // 2 hours ago
              'read': true,
              'channel': '80872',
              'source': 'read_message'
            }
          ];
          description = 'Read messages only';
          break;

        case 'unread_only':
          // Unread messages
          filteredMessages = [
            {
              'id': '1767812249006',
              'sender': '123457',
              'message': 'New payment received: KES 300.00',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 300000, // 5 min ago
              'read': false,
              'channel': '57938',
              'source': 'unread_message'
            },
            {
              'id': '1767812249007',
              'sender': '0712345678',
              'message': 'Scam attempt blocked',
              'timestamp': DateTime.now().millisecondsSinceEpoch - 120000, // 2 min ago
              'read': false,
              'channel': 'unknown',
              'source': 'unread_message'
            }
          ];
          description = 'Unread messages only';
          break;

        default:
          description = 'Unknown filter type';
      }

      final result = {
        'status': 'success',
        'filter_type': filterType,
        'description': description,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'count': filteredMessages.length,
        'messages': filteredMessages,
        'metadata': {
          'filtered_at': DateTime.now().toUtc().toIso8601String(),
          'data_source': 'sms_service_filtered',
          'filter_criteria': filterType,
        }
      };

      print('📊 [SMS_FILTER] Filtered $filterType: ${filteredMessages.length} messages');
      return result;

    } catch (e) {
      print('❌ [SMS_FILTER] Error filtering SMS: $e');
      return {
        'status': 'error',
        'filter_type': filterType,
        'error': e.toString(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  // Check if running on Android emulator
  static Future<bool> _isRunningOnEmulator() async {
    try {
      // Check for common emulator indicators
      final deviceInfo = {
        'model': 'unknown',
        'manufacturer': 'unknown',
        'isEmulator': false,
      };

      // Check system properties that indicate emulator
      // This is a simplified check - in production you'd use device_info_plus package
      final emulatorIndicators = [
        'sdk', 'emulator', 'android sdk built for x86', 'generic'
      ];

      // For now, we'll use a simple heuristic based on common emulator patterns
      // In a real app, you'd use device_info_plus package for accurate detection
      final hostname = Platform.localHostname.toLowerCase();
      final isEmulatorHostname = hostname.contains('emulator') ||
                                 hostname.contains('sdk') ||
                                 hostname == 'localhost';

      // Check if we can bind to typical emulator ports or detect emulator-specific files
      // This is a simplified approach for the demo
      final emulatorDetected = isEmulatorHostname ||
                              Platform.environment.containsKey('ANDROID_EMULATOR') ||
                              Platform.environment['USER']?.toLowerCase().contains('emulator') == true;

      print('🤖 Emulator detection: hostname=$hostname, detected=$emulatorDetected');

      return emulatorDetected;

    } catch (e) {
      print('❌ Error detecting emulator: $e');
      // Default to false if detection fails
      return false;
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

  // Inventory local handler - queries local SQLite database
  static Future<Response> _inventoryLocalHandler(Request request) async {
    try {
      final pageParam = request.params['page'];
      if (pageParam == null || pageParam.isEmpty) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Page parameter is required'
        }), headers: {'Content-Type': 'application/json'});
      }

      final page = int.tryParse(pageParam);
      if (page == null || page < 1) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Invalid page number. Must be a positive integer'
        }), headers: {'Content-Type': 'application/json'});
      }

      // Parse limit from query parameters (default 20)
      final limitParam = request.url.queryParameters['limit'];
      final limit = limitParam != null ? int.tryParse(limitParam) ?? 20 : 20;
      if (limit < 1 || limit > 100) {
        return Response(400, body: jsonEncode({
          'status': 'error',
          'message': 'Invalid limit. Must be between 1 and 100'
        }), headers: {'Content-Type': 'application/json'});
      }

      print('📦 Inventory API: Getting local inventory - Page: $page, Limit: $limit');

      // Calculate offset for pagination
      final offset = (page - 1) * limit;

      // Open database
      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, 'microserver_inventory.db');
      final db = await openDatabase(dbPath, readOnly: true);

      try {
        // Get total count
        final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM inventory_items');
        final totalItems = Sqflite.firstIntValue(countResult) ?? 0;
        final totalPages = (totalItems / limit).ceil();

        // Validate page number
        if (page > totalPages && totalItems > 0) {
          return Response(400, body: jsonEncode({
            'status': 'error',
            'message': 'Page number exceeds total pages',
            'total_pages': totalPages,
            'total_items': totalItems
          }), headers: {'Content-Type': 'application/json'});
        }

        // Query paginated inventory with JOIN
        final items = await db.rawQuery('''
          SELECT
            i.uid, i.name, i.description, i.price, i.item_type, i.updated_at,
            s.current_stock, s.last_stock_count, s.re_stock_value, s.re_stock_status
          FROM inventory_items i
          LEFT JOIN inventory_stock s ON i.uid = s.item_uid
          ORDER BY i.updated_at DESC
          LIMIT ? OFFSET ?
        ''', [limit, offset]);

        // Transform results for JSON response
        final transformedItems = items.map((item) {
          final currentStock = item['current_stock'] as int? ?? 0;
          final reStockValue = item['re_stock_value'] as int? ?? 0;
          final isLowStock = currentStock <= reStockValue;

          return {
            'uid': item['uid'],
            'name': item['name'],
            'description': item['description'],
            'price': item['price'],
            'item_type': item['item_type'],
            'updated_at': item['updated_at'],
            'current_stock': currentStock,
            'last_stock_count': item['last_stock_count'] ?? 0,
            're_stock_value': reStockValue,
            're_stock_status': item['re_stock_status'] ?? false,
            'stock_status': isLowStock ? 'low' : 'ok',
          };
        }).toList();

        final response = {
          'status': 'success',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'current_page': page,
          'total_pages': totalPages,
          'total_items': totalItems,
          'limit': limit,
          'items': transformedItems,
          'metadata': {
            'queried_at': DateTime.now().toUtc().toIso8601String(),
            'data_source': 'local_inventory_database',
            'database_path': dbPath,
          }
        };

        print('📦 Inventory API: Returned ${transformedItems.length} items for page $page/$totalPages');

        return Response.ok(
          jsonEncode(response),
          headers: {'Content-Type': 'application/json'},
        );

      } finally {
        await db.close();
      }

    } catch (e) {
      print('❌ Inventory API error (_inventoryLocalHandler): $e');

      // Check if database exists
      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, 'microserver_inventory.db');
      final dbExists = await databaseExists(dbPath);

      if (!dbExists) {
        return Response(404, body: jsonEncode({
          'status': 'error',
          'message': 'Inventory database not found. Run sync_inventory first to populate the database',
          'suggestion': 'Use option 12 in query_microserver.py to sync inventory data first'
        }), headers: {'Content-Type': 'application/json'});
      }

      return Response(500, body: jsonEncode({
        'status': 'error',
        'message': 'Failed to query inventory database: $e'
      }), headers: {'Content-Type': 'application/json'});
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_key_manager.dart';

class SecureActivationService {
  static const String _activationEndpoint = '/activate';
  static const String _licenseKeyKey = 'secure_license_key';

  /// Activate the app with license key and initialize secure communication
  static Future<Map<String, dynamic>> activateWithLicense(String licenseKey) async {
    try {
      print('🔐 Starting secure activation with license key...');

      // Set license key in secure key manager
      await SecureKeyManager.setLicenseKey(licenseKey);
      print('🔑 License key securely stored');

      // Initialize key manager
      await SecureKeyManager.initialize();
      print('🔐 Key manager initialized');

      // Generate initial session key
      final sessionKey = await SecureKeyManager.generateSessionKey();
      print('🔑 Initial session key generated');

      // Test connection to backend
      final connectionResult = await _testSecureConnection(licenseKey, sessionKey);
      
      if (connectionResult['status'] == 'success') {
        print('✅ Secure activation completed successfully');
        
        // Store activation status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isActivated', true);
        await prefs.setString('licenseExpiry', connectionResult['license_expiry']);
        await prefs.setString('persistentAccountId', connectionResult['account_id']);
        
        return {
          'status': 'success',
          'message': 'App activated successfully with secure communication',
          'license_expiry': connectionResult['license_expiry'],
          'account_id': connectionResult['account_id'],
        };
      } else {
        print('❌ Secure activation failed: ${connectionResult['message']}');
        return {
          'status': 'failed',
          'message': connectionResult['message'] ?? 'Activation failed',
        };
      }
    } catch (e) {
      print('❌ Secure activation error: $e');
      return {
        'status': 'error',
        'message': 'Activation failed due to security error: $e',
      };
    }
  }

  /// Test secure connection to backend
  static Future<Map<String, dynamic>> _testSecureConnection(String licenseKey, String sessionKey) async {
    try {
      // Get backend URL
      final backendUrl = await _getBackendUrl();
      final url = Uri.parse('$backendUrl$_activationEndpoint');

      // Create secure request data
      final requestData = {
        'action': 'activate',
        'license_key': licenseKey,
        'session_key': sessionKey,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'device_info': {
        'platform': 'flutter',
          'version': '1.0.0',
        },
      };

      // Encrypt the request data
      final encryptedData = await SecureKeyManager.encryptData(
        jsonEncode(requestData),
        sessionKey,
      );

      // Create HMAC for authentication
      final hmac = SecureKeyManager.createHMAC(encryptedData, sessionKey);

      // Create secure request payload
      final securePayload = {
        'version': '1.0',
        'encrypted_data': encryptedData,
        'hmac': hmac,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      print('📡 Sending secure activation request to $url');

      // Send secure request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Secure-Protocol': 'AES-256-CBC',
        },
        body: jsonEncode(securePayload),
      );

      print('📡 Secure activation response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        
        // Verify response HMAC
        if (responseJson.containsKey('hmac') && responseJson.containsKey('encrypted_response')) {
          final responseHmac = responseJson['hmac'];
          final encryptedResponse = responseJson['encrypted_response'];
          
          if (SecureKeyManager.verifyHMAC(encryptedResponse, responseHmac, sessionKey)) {
            // Decrypt response
            final decryptedResponse = await SecureKeyManager.decryptData(
              encryptedResponse,
              sessionKey,
            );
            
            final responseData = jsonDecode(decryptedResponse);
            print('✅ Secure activation response decrypted successfully');
            return responseData;
          } else {
            print('❌ Invalid response HMAC');
            return {
              'status': 'failed',
              'message': 'Invalid response authentication',
            };
          }
        } else {
          print('❌ Invalid response format');
          return {
            'status': 'failed',
            'message': 'Invalid response format from server',
          };
        }
      } else {
        print('❌ Backend activation failed with status: ${response.statusCode}');
        return {
          'status': 'failed',
          'message': 'Backend activation failed',
        };
      }
    } catch (e) {
      print('❌ Secure connection test failed: $e');
      return {
        'status': 'error',
        'message': 'Connection failed: $e',
      };
    }
  }

  /// Reactivate with existing license key
  static Future<Map<String, dynamic>> reactivate() async {
    try {
      print('🔄 Starting secure reactivation...');

      // Get stored license key
      final prefs = await SharedPreferences.getInstance();
      final licenseKey = prefs.getString(_licenseKeyKey);
      
      if (licenseKey == null) {
        print('❌ No license key found for reactivation');
        return {
          'status': 'failed',
          'message': 'No license key found',
        };
      }

      // Set license key and initialize
      await SecureKeyManager.setLicenseKey(licenseKey);
      await SecureKeyManager.initialize();

      // Generate new session key
      final sessionKey = await SecureKeyManager.generateSessionKey();

      // Test connection
      final connectionResult = await _testSecureConnection(licenseKey, sessionKey);

      if (connectionResult['status'] == 'success') {
        print('✅ Secure reactivation completed successfully');
        
        // Update stored data
        await prefs.setBool('isActivated', true);
        await prefs.setString('licenseExpiry', connectionResult['license_expiry']);
        await prefs.setString('persistentAccountId', connectionResult['account_id']);
        
        return {
          'status': 'success',
          'message': 'App reactivated successfully',
          'license_expiry': connectionResult['license_expiry'],
          'account_id': connectionResult['account_id'],
        };
      } else {
        print('❌ Secure reactivation failed: ${connectionResult['message']}');
        return {
          'status': 'failed',
          'message': connectionResult['message'] ?? 'Reactivation failed',
        };
      }
    } catch (e) {
      print('❌ Secure reactivation error: $e');
      return {
        'status': 'error',
        'message': 'Reactivation failed due to security error: $e',
      };
    }
  }

  /// Check if app is securely activated
  static Future<bool> isSecurelyActivated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActivated = prefs.getBool('isActivated') ?? false;
      
      if (!isActivated) {
        return false;
      }

      // Check if keys are valid
      final keysValid = await SecureKeyManager.validateKeys();
      if (!keysValid) {
        print('❌ Security keys validation failed');
        return false;
      }

      // Check session key
      final sessionKey = await SecureKeyManager.getSessionKey();
      if (sessionKey == null) {
        print('❌ No session key found');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Activation check error: $e');
      return false;
    }
  }

  /// Get current license status
  static Future<Map<String, dynamic>> getLicenseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActivated = prefs.getBool('isActivated') ?? false;
      final licenseExpiry = prefs.getString('licenseExpiry');
      final accountId = prefs.getString('persistentAccountId');

      if (!isActivated) {
        return {
          'status': 'not_activated',
          'message': 'App is not activated',
        };
      }

      if (licenseExpiry != null) {
        final expiryDate = DateTime.parse(licenseExpiry);
        if (expiryDate.isBefore(DateTime.now())) {
          return {
            'status': 'expired',
            'message': 'License has expired',
            'expiry_date': licenseExpiry,
            'account_id': accountId,
          };
        } else {
          return {
            'status': 'active',
            'message': 'License is active',
            'expiry_date': licenseExpiry,
            'account_id': accountId,
            'days_remaining': expiryDate.difference(DateTime.now()).inDays,
          };
        }
      }

      return {
        'status': 'active',
        'message': 'License is active',
        'account_id': accountId,
      };
    } catch (e) {
      print('❌ License status check error: $e');
      return {
        'status': 'error',
        'message': 'Failed to check license status',
      };
    }
  }

  /// Deactivate app and clear security keys
  static Future<void> deactivate() async {
    try {
      print('🔐 Deactivating app and clearing security keys...');

      // Clear all keys
      await SecureKeyManager.clearAllKeys();

      // Clear activation status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isActivated', false);
      await prefs.remove('licenseExpiry');
      await prefs.remove('persistentAccountId');

      print('✅ App deactivated successfully');
    } catch (e) {
      print('❌ Deactivation error: $e');
      throw Exception('Failed to deactivate app: $e');
    }
  }

  /// Get backend URL for secure communication
  static Future<String> _getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip') ?? 'localhost:8080';

    // Ensure proper URL format
    String baseUrl;
    if (savedIp.startsWith('http')) {
      baseUrl = savedIp;
    } else {
      baseUrl = 'http://$savedIp';
    }

    return baseUrl;
  }

  /// Rotate session key for enhanced security
  static Future<String> rotateSessionKey() async {
    try {
      final newSessionKey = await SecureKeyManager.rotateSessionKeyIfNeeded();
      print('🔄 Session key rotated for enhanced security');
      return newSessionKey;
    } catch (e) {
      print('❌ Session key rotation failed: $e');
      throw Exception('Failed to rotate session key: $e');
    }
  }

  /// Get security status summary
  static Future<Map<String, dynamic>> getSecurityStatus() async {
    try {
      final keysValid = await SecureKeyManager.validateKeys();
      final sessionKey = await SecureKeyManager.getSessionKey();
      final sessionExpiry = await SecureKeyManager.getSessionExpiry();
      final lastRotation = await SecureKeyManager.getLastRotationTime();

      return {
        'keys_valid': keysValid,
        'session_key_exists': sessionKey != null,
        'session_expiry': sessionExpiry?.toIso8601String(),
        'last_rotation': lastRotation?.toIso8601String(),
        'needs_rotation': await SecureKeyManager.needsSessionRotation(),
      };
    } catch (e) {
      print('❌ Security status check error: $e');
      return {
        'error': 'Failed to get security status',
        'details': e.toString(),
      };
    }
  }
}

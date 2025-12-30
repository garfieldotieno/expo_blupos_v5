import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class SecureKeyManager {
  static const String _masterKeyKey = 'secure_master_key';
  static const String _licenseKeyKey = 'secure_license_key';
  static const String _sessionKeyKey = 'secure_session_key';
  static const String _sessionExpiryKey = 'secure_session_expiry';
  static const String _lastRotationKey = 'secure_last_rotation';

  // Key derivation parameters
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16; // 128 bits
  static const int _iterations = 10000;

  // Session key rotation interval (30 minutes)
  static const Duration _sessionRotationInterval = Duration(minutes: 30);

  /// Initialize the key manager with master key generation if needed
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate master key if it doesn't exist
    if (!prefs.containsKey(_masterKeyKey)) {
      await _generateMasterKey();
    }
  }

  /// Generate and store master key
  static Future<void> _generateMasterKey() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate cryptographically secure random master key
    final masterKey = _generateRandomKey();
    final masterKeyBase64 = base64Encode(masterKey);
    
    await prefs.setString(_masterKeyKey, masterKeyBase64);
    print('🔐 Generated new master key');
  }

  /// Set license key (derived from activation)
  static Future<void> setLicenseKey(String licenseKey) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Hash the license key for security
    final licenseHash = _hashLicenseKey(licenseKey);
    await prefs.setString(_licenseKeyKey, licenseHash);
    print('🔑 License key set and hashed');
  }

  /// Generate session key for secure communication
  static Future<String> generateSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate cryptographically secure random session key
    final sessionKey = _generateRandomKey();
    final sessionKeyBase64 = base64Encode(sessionKey);
    
    // Store session key and expiry
    final expiry = DateTime.now().add(_sessionRotationInterval);
    await prefs.setString(_sessionKeyKey, sessionKeyBase64);
    await prefs.setString(_sessionExpiryKey, expiry.toIso8601String());
    await prefs.setString(_lastRotationKey, DateTime.now().toIso8601String());
    
    print('🔑 Generated new session key, expires at: ${expiry.toIso8601String()}');
    return sessionKeyBase64;
  }

  /// Get current session key
  static Future<String?> getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKeyKey);
  }

  /// Check if session key needs rotation
  static Future<bool> needsSessionRotation() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_sessionExpiryKey);
    
    if (expiryString == null) {
      return true; // No session key exists
    }
    
    final expiry = DateTime.parse(expiryString);
    return DateTime.now().isAfter(expiry);
  }

  /// Rotate session key if needed
  static Future<String> rotateSessionKeyIfNeeded() async {
    if (await needsSessionRotation()) {
      print('🔄 Rotating session key...');
      return await generateSessionKey();
    }
    
    final sessionKey = await getSessionKey();
    if (sessionKey != null) {
      return sessionKey;
    }
    
    // Fallback: generate new session key
    return await generateSessionKey();
  }

  /// Encrypt data using session key
  static Future<String> encryptData(String data, String sessionKey) async {
    try {
      final key = encrypt.Key.fromBase64(sessionKey);
      final iv = encrypt.IV.fromLength(16); // 128-bit IV
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(data, iv: iv);
      
      // Return IV + encrypted data for decryption
      return base64Encode(iv.bytes) + ':' + encrypted.base64;
    } catch (e) {
      print('❌ Encryption failed: $e');
      throw Exception('Failed to encrypt data');
    }
  }

  /// Decrypt data using session key
  static Future<String> decryptData(String encryptedData, String sessionKey) async {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid encrypted data format');
      }
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypter(encrypt.AES(
        encrypt.Key.fromBase64(sessionKey),
        mode: encrypt.AESMode.cbc
      ));
      
      final decrypted = encrypted.decrypt64(parts[1], iv: iv);
      return decrypted;
    } catch (e) {
      print('❌ Decryption failed: $e');
      throw Exception('Failed to decrypt data');
    }
  }

  /// Create HMAC for authentication
  static String createHMAC(String data, String sessionKey) {
    final key = base64Decode(sessionKey);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(data));
    return base64Encode(digest.bytes);
  }

  /// Verify HMAC for authentication
  static bool verifyHMAC(String data, String expectedHMAC, String sessionKey) {
    final calculatedHMAC = createHMAC(data, sessionKey);
    return calculatedHMAC == expectedHMAC;
  }

  /// Generate cryptographically secure random key
  static Uint8List _generateRandomKey() {
    final random = encrypt.Key.fromLength(_keyLength);
    return random.bytes;
  }

  /// Hash license key for secure storage
  static String _hashLicenseKey(String licenseKey) {
    final bytes = utf8.encode(licenseKey);
    final digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  /// Get master key
  static Future<String?> getMasterKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_masterKeyKey);
  }

  /// Get license key hash
  static Future<String?> getLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKeyKey);
  }

  /// Get session expiry time
  static Future<DateTime?> getSessionExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_sessionExpiryKey);
    return expiryString != null ? DateTime.parse(expiryString) : null;
  }

  /// Get last rotation time
  static Future<DateTime?> getLastRotationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final rotationString = prefs.getString(_lastRotationKey);
    return rotationString != null ? DateTime.parse(rotationString) : null;
  }

  /// Clear all keys (for security purposes)
  static Future<void> clearAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_masterKeyKey);
    await prefs.remove(_licenseKeyKey);
    await prefs.remove(_sessionKeyKey);
    await prefs.remove(_sessionExpiryKey);
    await prefs.remove(_lastRotationKey);
    print('🔐 All keys cleared');
  }

  /// Validate key integrity
  static Future<bool> validateKeys() async {
    try {
      final masterKey = await getMasterKey();
      final licenseKey = await getLicenseKey();
      
      if (masterKey == null || licenseKey == null) {
        return false;
      }
      
      // Validate master key format
      final masterKeyBytes = base64Decode(masterKey);
      if (masterKeyBytes.length != _keyLength) {
        return false;
      }
      
      // Validate license key format
      final licenseKeyBytes = base64Decode(licenseKey);
      if (licenseKeyBytes.length != 32) { // SHA-256 hash length
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ Key validation failed: $e');
      return false;
    }
  }
}

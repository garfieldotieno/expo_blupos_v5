import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_client.dart';

/// SMS Reconciliation Service for APK Integration
/// Handles communication between APK SMS detection and backend reconciliation service
/// Uses existing auto-discovery mechanism from ApiClient for dynamic backend resolution
class SMSReconciliationService extends ChangeNotifier {
  String _backendUrl = ''; // Dynamic URL from auto-discovery
  final String _apiBaseUrl = '/api/sms';
  
  bool _isAutoModeEnabled = false;
  bool _isListening = false;
  List<Map<String, dynamic>> _paymentQueue = [];
  Map<String, dynamic>? _selectedPayment;
  Map<String, dynamic>? _pendingCheckout;
  
  bool get isAutoModeEnabled => _isAutoModeEnabled;
  bool get isListening => _isListening;
  List<Map<String, dynamic>> get paymentQueue => _paymentQueue;
  Map<String, dynamic>? get selectedPayment => _selectedPayment;
  Map<String, dynamic>? get pendingCheckout => _pendingCheckout;
  
  SMSReconciliationService() {
    _loadSettings();
    _initializeAutoDiscovery();
  }
  
  /// Initialize auto-discovery using existing ApiClient mechanism
  Future<void> _initializeAutoDiscovery() async {
    try {
      // Use the same mechanism as activation service for backend URL resolution
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('server_ip') ?? 'localhost:8080';

      // Ensure proper URL format (same logic as secure_activation_service.dart)
      String baseUrl;
      if (savedIp.startsWith('http')) {
        baseUrl = savedIp;
      } else {
        baseUrl = 'http://$savedIp';
      }

      _backendUrl = baseUrl;
      print('📱 SMS Reconciliation Service: Using backend URL: $_backendUrl');
      notifyListeners();
    } catch (e) {
      print('❌ SMS Reconciliation Service: Auto-discovery failed: $e');
      // Remove fallback mechanism - ensure zero-config resolution
      // The app should rely entirely on auto-discovery and network discovery
      // If auto-discovery fails, the app should handle it gracefully without hardcoded fallbacks
      // Use the default saved IP from shared preferences
      _backendUrl = 'http://localhost:8080'; // Use default only as last resort
      notifyListeners();
    }
  }
  
  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoModeEnabled = prefs.getBool('sms_auto_mode') ?? false;
    notifyListeners();
  }
  
  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_auto_mode', _isAutoModeEnabled);
  }
  
  /// Toggle automatic SMS processing mode
  Future<void> toggleAutoMode() async {
    _isAutoModeEnabled = !_isAutoModeEnabled;
    await _saveSettings();
    notifyListeners();
  }
  
  /// Enable automatic SMS processing mode
  Future<void> enableAutoMode() async {
    _isAutoModeEnabled = true;
    await _saveSettings();
    notifyListeners();
  }
  
  /// Disable automatic SMS processing mode
  Future<void> disableAutoMode() async {
    _isAutoModeEnabled = false;
    await _saveSettings();
    notifyListeners();
  }
  
  /// Start SMS listening service
  Future<void> startSMSListening() async {
    _isListening = true;
    notifyListeners();
    // Note: Actual SMS listening would be implemented in platform channels
    // This is the Dart service layer that coordinates with platform channels
  }
  
  /// Stop SMS listening service
  Future<void> stopSMSListening() async {
    _isListening = false;
    notifyListeners();
  }
  
  /// Process incoming SMS message
  Future<Map<String, dynamic>> processSMSMessage(String channel, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl$_apiBaseUrl/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'channel': channel,
          'message': message
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        // Handle different response types
        if (result['status'] == 'queued') {
          // Payment added to queue - refresh queue
          await _refreshPaymentQueue();
          return {
            'status': 'queued',
            'message': result['message'],
            'queueLength': result['queue_length']
          };
        } else if (result['status'] == 'pending') {
          // No pending checkout - payment created for manual review
          return {
            'status': 'pending',
            'message': result['message'],
            'pendingId': result['pending_id']
          };
        } else if (result['status'] == 'success') {
          // Direct reconciliation (shouldn't happen with queue system)
          return {
            'status': 'success',
            'message': result['message']
          };
        } else {
          return {
            'status': 'error',
            'message': result['message'] ?? 'Unknown error occurred'
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed to process SMS message'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
  
  /// Refresh payment queue from backend
  Future<void> _refreshPaymentQueue() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl$_apiBaseUrl/queue'),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _paymentQueue = List<Map<String, dynamic>>.from(result['queue']);
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error refreshing payment queue: $e');
    }
  }
  
  /// Get current payment queue
  Future<List<Map<String, dynamic>>> getPaymentQueue() async {
    await _refreshPaymentQueue();
    return _paymentQueue;
  }
  
  /// Select payment for reconciliation
  Future<Map<String, dynamic>> selectPayment(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl$_apiBaseUrl/select-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'payment_id': paymentId
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          _selectedPayment = result['payment_data'];
          _pendingCheckout = result['pending_checkout'];
          notifyListeners();
          
          return {
            'status': 'success',
            'message': result['message'],
            'paymentData': _selectedPayment,
            'pendingCheckout': _pendingCheckout
          };
        } else {
          return {
            'status': 'error',
            'message': result['message'] ?? 'Failed to select payment'
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed to select payment'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
  
  /// Confirm payment reconciliation
  Future<Map<String, dynamic>> confirmPayment(String paymentId, bool clerkConfirmation) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl$_apiBaseUrl/reconcile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'payment_id': paymentId,
          'clerk_confirmation': clerkConfirmation
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          // Refresh queue after successful reconciliation
          await _refreshPaymentQueue();
          
          // Clear selected payment
          _selectedPayment = null;
          _pendingCheckout = null;
          notifyListeners();
          
          return {
            'status': 'success',
            'message': result['message'],
            'amountReconciled': result['amount_reconciled'],
            'remainingBalance': result['remaining_balance'],
            'unblockSales': result['unblock_sales'],
            'queueLength': result['queue_length']
          };
        } else if (result['status'] == 'rejected') {
          // Payment rejected - refresh queue
          await _refreshPaymentQueue();
          
          return {
            'status': 'rejected',
            'message': result['message'],
            'queueLength': result['queue_length']
          };
        } else {
          return {
            'status': 'error',
            'message': result['message'] ?? 'Failed to confirm payment'
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed to confirm payment'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
  
  /// Get SMS processing status
  Future<Map<String, dynamic>> getSMSStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl$_apiBaseUrl/status'),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          return {
            'status': 'success',
            'queueLength': result['queue_length'],
            'pendingCheckout': result['pending_checkout'],
            'pendingCheckoutDetails': result['pending_checkout_details']
          };
        } else {
          return {
            'status': 'error',
            'message': 'Failed to get SMS status'
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed to get SMS status'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
  
  /// Test SMS processing with sample messages
  Future<Map<String, dynamic>> testSMSProcessing() async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl$_apiBaseUrl/test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          return {
            'status': 'success',
            'testResults': result['test_results'],
            'message': result['message']
          };
        } else {
          return {
            'status': 'error',
            'message': result['message'] ?? 'Test failed'
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Test failed'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
  
  /// Clear selected payment
  void clearSelectedPayment() {
    _selectedPayment = null;
    _pendingCheckout = null;
    notifyListeners();
  }
  
  /// Clear payment queue
  void clearPaymentQueue() {
    _paymentQueue.clear();
    notifyListeners();
  }
  
  /// Reset service state
  void reset() {
    _isAutoModeEnabled = false;
    _isListening = false;
    _paymentQueue.clear();
    _selectedPayment = null;
    _pendingCheckout = null;
    notifyListeners();
  }
}

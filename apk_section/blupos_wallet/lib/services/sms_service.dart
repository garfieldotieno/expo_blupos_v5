import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_reconciliation_service.dart';

class SmsService extends ChangeNotifier {
  static const platform = MethodChannel('com.blupos.wallet/sms');

  List<Map<String, dynamic>> _smsMessages = [];
  int _unreadSmsCount = 0;
  Timer? _smsCheckTimer;
  bool _isListening = false;

  // Stream for SMS arrival notifications
  final StreamController<void> _smsArrivalController = StreamController<void>.broadcast();
  Stream<void> get onSmsArrival => _smsArrivalController.stream;

  // Stream for unread SMS count changes (for continuous blinking)
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  List<Map<String, dynamic>> get smsMessages => _smsMessages;
  int get unreadSmsCount => _unreadSmsCount;
  bool get isListening => _isListening;

  // Load SMS messages from inbox with comprehensive logging
  Future<void> _loadSmsMessages() async {
    try {
      print('📱 [SMS_SERVICE] Starting inbox scan...');

      // Query device SMS inbox for unread messages
      final result = await platform.invokeMethod('loadSmsInbox');

      if (result != null && result is List) {
        // Cast to dynamic first, then convert to Map<String, dynamic>
        final List<dynamic> rawList = result;
        final inboxSms = rawList.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList();
        print('📱 [SMS_SERVICE] Found ${inboxSms.length} unread SMS in device inbox');

        // Process each unread SMS from inbox
        for (final smsData in inboxSms) {
          // Check if we already have this SMS (avoid duplicates)
          final existingIndex = _smsMessages.indexWhere((msg) => msg['id'] == smsData['id']);
          if (existingIndex == -1) {
            // Add new unread SMS from inbox
            final messageData = {
              'id': smsData['id'],
              'body': smsData['message'] ?? '',
              'sender': smsData['sender'] ?? '',
              'timestamp': smsData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'read': false,
              'source': 'inbox', // Mark as loaded from device inbox
            };

            _smsMessages.insert(0, messageData);
            print('📨 [SMS_SERVICE] Loaded unread SMS from inbox: ${smsData['sender']} - "${smsData['message']}"');
          } else {
            print('ℹ️ [SMS_SERVICE] Duplicate SMS detected, skipping: ${smsData['sender']}');
          }
        }

        // Update count and emit stream event
        _updateUnreadCount();
        print('📊 [SMS_SERVICE] Inbox scan complete. Total unread: $_unreadSmsCount');
      } else {
        print('📱 [SMS_SERVICE] No unread SMS found in device inbox');
      }

      notifyListeners();
    } catch (e) {
      print('❌ [SMS_SERVICE] Error loading SMS messages: $e');
      // Continue with persisted data if inbox loading fails
    }
  }

  // Start listening for incoming SMS using platform channels
  Future<void> _startSmsListener() async {
    try {
      print('👂 [SMS_SERVICE] Starting native SMS listener...');

      // Start native SMS monitoring via platform channel
      await platform.invokeMethod('startSmsMonitoring');

      _isListening = true;
      print('✅ [SMS_SERVICE] SMS listener started (native)');
    } catch (e) {
      print('❌ [SMS_SERVICE] Error starting SMS listener: $e');
      _isListening = false;
    }
  }

  // Get recent SMS messages (last 24 hours)
  List<Map<String, dynamic>> getRecentSms() {
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    return _smsMessages.where((msg) {
      final messageTime = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] ?? 0);
      return messageTime.isAfter(oneDayAgo);
    }).toList();
  }

  // Setup platform channel listener for incoming SMS
  void _setupPlatformChannel() {
    platform.setMethodCallHandler((call) async {
      print('📡 [SMS_SERVICE] Platform method called: ${call.method}');

      if (call.method == 'onSmsReceived') {
        // Emit SMS arrival event for any incoming SMS (for blinking animation)
        _smsArrivalController.add(null);
        print('📨 [SMS_SERVICE] SMS arrival notification emitted for blinking animation');

        final smsData = call.arguments as Map<String, dynamic>;
        print('📨 [SMS_SERVICE] SMS data received: $smsData');
        _handleIncomingSms(smsData);
      } else if (call.method == 'onPaymentReceived') {
        print('💰 [SMS_SERVICE] Payment data received call');
        final paymentData = call.arguments as Map<String, dynamic>;
        print('💰 [SMS_SERVICE] Payment data: $paymentData');
        _handleIncomingPayment(paymentData);
      } else {
        print('❓ [SMS_SERVICE] Unknown method call: ${call.method}');
      }
    });
  }

  // Handle incoming SMS from native SMS monitoring (any SMS for blinking animation)
  void _handleIncomingSms(Map<String, dynamic> smsData) {
    print('\n📨 [SMS_INCOMING] === INCOMING SMS RECEIVED ===');
    print('📨 [SMS_INCOMING] From: ${smsData['sender']} | Message: "${smsData['message']}"');

    // Log current state before adding new SMS
    final previousCount = _unreadSmsCount;
    final previousTotal = _smsMessages.length;
    print('📊 [SMS_STATE_BEFORE] Count: $previousCount | Total: $previousTotal | Periodic monitoring active: ${_smsCheckTimer?.isActive ?? false}');

    final messageData = {
      'id': smsData['timestamp'].toString(),
      'body': smsData['message'] ?? '',
      'sender': smsData['sender'] ?? '',
      'timestamp': smsData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'source': 'incoming_broadcast', // Mark as real-time incoming
    };

    _smsMessages.insert(0, messageData);
    print('📨 [SMS_INCOMING] Added to message list - New total: ${_smsMessages.length}');

    // Update unread count and emit stream event
    _updateUnreadCount();

    // Log state after processing
    print('📊 [SMS_STATE_AFTER] Count: $_unreadSmsCount | Total: ${_smsMessages.length} | Change: ${previousCount} → $_unreadSmsCount');
    print('🔗 [SMS_TRANSITION] Real-time SMS integrated with periodic monitoring state');
    print('✅ [SMS_INCOMING] === SMS PROCESSING COMPLETE ===\n');

    notifyListeners();
  }

  // Handle incoming payment from native SMS monitoring
  void _handleIncomingPayment(Map<String, dynamic> paymentData) {
    print('\n💰 [SMS_PAYMENT] === PAYMENT SMS RECEIVED ===');
    print('💰 [SMS_PAYMENT] Amount: ${paymentData['amount']} | Reference: ${paymentData['reference']} | From: ${paymentData['sender']}');
    print('💰 [SMS_PAYMENT] Message: "${paymentData['message']}"');

    // Log current state before processing payment SMS
    final previousCount = _unreadSmsCount;
    final previousTotal = _smsMessages.length;
    print('📊 [SMS_STATE_BEFORE_PAYMENT] Count: $previousCount | Total: $previousTotal | Periodic monitoring: ${_smsCheckTimer?.isActive ?? false}');

    // Convert payment data to SMS message format
    final smsData = {
      'id': paymentData['timestamp'].toString(),
      'body': paymentData['message'] ?? '',
      'sender': paymentData['sender'] ?? '',
      'timestamp': paymentData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'amount': paymentData['amount'] ?? 0.0,
      'reference': paymentData['reference'] ?? '',
      'source': 'payment_broadcast', // Mark as payment SMS
    };

    _smsMessages.insert(0, smsData);
    print('💰 [SMS_PAYMENT] Added payment SMS to message list - New total: ${_smsMessages.length}');

    // ✅ CRITICAL: Trigger reconciliation workflow
    print('🔄 [SMS_PAYMENT] Triggering reconciliation workflow...');
    _triggerSMSReconciliation(smsData);

    // Update unread count and emit stream event
    _updateUnreadCount();

    // Log comprehensive state after payment processing
    print('📊 [SMS_STATE_AFTER_PAYMENT] Count: $_unreadSmsCount | Total: ${_smsMessages.length} | Change: ${previousCount} → $_unreadSmsCount');
    print('🔗 [SMS_TRANSITION] Payment SMS integrated with periodic monitoring - Next 2-minute cycle will reflect this state');
    print('✅ [SMS_PAYMENT] === PAYMENT PROCESSING COMPLETE ===\n');

    notifyListeners();
  }

  // ✅ CRITICAL: Trigger reconciliation workflow
  Future<void> _triggerSMSReconciliation(Map<String, dynamic> smsData) async {
    try {
      // Extract channel and message from SMS data
      final channel = _extractChannelFromSMS(smsData['body'], smsData['sender']);
      final message = smsData['body'];

      // Get SMS reconciliation service instance
      final reconciliationService = SMSReconciliationService();

      // Process SMS for reconciliation
      final result = await reconciliationService.processSMSMessage(channel, message);

      print('✅ [SMS_SERVICE] SMS reconciliation triggered: ${result['status']}');
    } catch (e) {
      print('❌ [SMS_SERVICE] SMS reconciliation failed: $e');
    }
  }

  // ✅ Add SMS parsing logic - Shortcode sender based
  String _extractChannelFromSMS(String message, String sender) {
    // Map specific shortcodes to channels
    if (sender == '123456') {
      return '80872';  // Shortcode 123456 maps to channel 80872
    } else if (sender == '123457') {
      return '57938';  // Shortcode 123457 maps to channel 57938
    }
    return 'unknown';
  }

  // ✅ Add payment detection logic
  bool _isPaymentMessage(String message) {
    final paymentKeywords = [
      'Payment Of', 'credited with', 'Kshs', 'KES',
      'received', 'confirmed', 'M-PESA', 'transaction'
    ];
    return paymentKeywords.any((keyword) =>
      message.toLowerCase().contains(keyword.toLowerCase())
    );
  }

  // Load persisted SMS data on initialization
  Future<void> _loadPersistedSmsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smsDataJson = prefs.getString('sms_messages');
      if (smsDataJson != null) {
        final List<dynamic> smsData = jsonDecode(smsDataJson);
        _smsMessages = smsData.cast<Map<String, dynamic>>();
        _updateUnreadCount();
        print('📱 [SMS_SERVICE] Loaded ${_smsMessages.length} persisted SMS messages');
      }
    } catch (e) {
      print('❌ [SMS_SERVICE] Error loading persisted SMS data: $e');
      _smsMessages = [];
    }
  }

  // Save SMS data to persistence
  Future<void> _saveSmsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smsDataJson = jsonEncode(_smsMessages);
      await prefs.setString('sms_messages', smsDataJson);
      await prefs.setInt('unread_sms_count', _unreadSmsCount);
      print('💾 [SMS_SERVICE] Saved SMS data: ${_smsMessages.length} messages, $_unreadSmsCount unread');
    } catch (e) {
      print('❌ [SMS_SERVICE] Error saving SMS data: $e');
    }
  }

  // Initialize SMS service with persistence
  Future<void> initialize() async {
    try {
      // Load persisted data first
      await _loadPersistedSmsData();

      // Request SMS permissions
      final smsPermission = await Permission.sms.request();
      final receiveSmsPermission = await Permission.sms.request();
      final readSmsPermission = await Permission.sms.request();

      if (smsPermission.isGranted || receiveSmsPermission.isGranted || readSmsPermission.isGranted) {
        print('✅ [SMS_SERVICE] SMS permissions granted');
        await _loadSmsMessages(); // Load from device inbox
        await _startSmsListener();
        _setupPlatformChannel();

        // Start real-time monitoring (no more 2-minute delays)
        _startRealTimeMonitoring();

        // Immediate status logging at startup
        _logImmediateStartupStatus();

        // Debug listener to verify stream is working
        _unreadCountController.stream.listen((count) {
          print('🔍 [SMS_SERVICE] INTERNAL STREAM LISTENER: Received count $count');
          notifyListeners();
        });

        // ✅ CRITICAL FIX: Listen to unread count changes for real-time updates
        _unreadCountController.stream.listen((count) {
          notifyListeners();
        });

        // ✅ IMMEDIATE UPDATE: Emit current count immediately for UI initialization
        print('📡 [SMS_SERVICE] Emitting current unread count immediately: $_unreadSmsCount');
        _unreadCountController.add(_unreadSmsCount);
      } else {
        print('❌ [SMS_SERVICE] SMS permissions denied - using persisted data only');
        // Still emit current unread count for UI
        _unreadCountController.add(_unreadSmsCount);
      }
    } catch (e) {
      print('❌ [SMS_SERVICE] Error initializing SMS service: $e');
    }
  }

  // Update unread SMS count with persistence
  void _updateUnreadCount() {
    print('🔄 [SMS_SERVICE] _updateUnreadCount called');
    final previousCount = _unreadSmsCount;

    // Detailed breakdown of message states
    final totalMessages = _smsMessages.length;
    final readMessages = _smsMessages.where((msg) => msg['read'] == true).length;
    final unreadMessages = _smsMessages.where((msg) => msg['read'] == false).length;
    final nullReadStatus = _smsMessages.where((msg) => msg['read'] == null).length;

    _unreadSmsCount = unreadMessages;

    print('🔢 [SMS_SERVICE] Detailed count breakdown:');
    print('   • Total messages in memory: $totalMessages');
    print('   • Read messages: $readMessages');
    print('   • Unread messages: $unreadMessages');
    print('   • Null read status: $nullReadStatus');
    print('   • Previous count: $previousCount → New count: $_unreadSmsCount');

    // Background activity counts logging
    print('📊 [SMS_BACKGROUND] Total: $totalMessages | Read: $readMessages | Unread: $unreadMessages');

    // Log individual unread messages for debugging
    if (_unreadSmsCount > 0 && _unreadSmsCount <= 5) {  // Only log if reasonable number to avoid spam
      print('📋 [SMS_DEBUG] Current unread messages:');
      _smsMessages.where((msg) => msg['read'] == false).take(5).forEach((msg) {
        final sender = msg['sender'] ?? 'unknown';
        final body = (msg['body'] ?? '').toString().substring(0, 50);
        final timestamp = msg['timestamp'];
        print('   • From: $sender | "$body..." | Time: $timestamp');
      });
    } else if (_unreadSmsCount > 5) {
      print('📋 [SMS_DEBUG] Too many unread messages (${_unreadSmsCount}) to list individually');
    }

    // Emit change if count changed
    if (_unreadSmsCount != previousCount) {
      _unreadCountController.add(_unreadSmsCount);

      // Save to persistence when count changes
      _saveSmsData();

      print('📨 [SMS_SERVICE] Unread SMS count changed: $previousCount → $_unreadSmsCount');
      print('📡 [SMS_SERVICE] Emitting unread count to stream: $_unreadSmsCount');
    } else {
      print('📊 [SMS_SERVICE] Unread count unchanged: $_unreadSmsCount');
    }

    // Special logging for zero count to help debug the "always 1" issue
    if (_unreadSmsCount == 0) {
      print('✅ [SMS_SERVICE] Zero unread messages - inbox is clear');
    } else if (_unreadSmsCount == 1) {
      print('⚠️ [SMS_SERVICE] Exactly 1 unread message - verify this is correct');
    }
  }

  // Mark SMS as read with persistence
  Future<void> markSmsAsRead(String messageId) async {
    try {
      final index = _smsMessages.indexWhere((msg) => msg['id'] == messageId);
      if (index != -1) {
        _smsMessages[index]['read'] = true;
        _updateUnreadCount();
        notifyListeners();
        print('✅ [SMS_SERVICE] Marked SMS as read: $messageId');
      }
    } catch (e) {
      print('❌ [SMS_SERVICE] Error marking SMS as read: $e');
    }
  }

  // Mark all SMS as read with persistence
  void markAllSmsAsRead() {
    for (var msg in _smsMessages) {
      msg['read'] = true;
    }
    _unreadSmsCount = 0;
    _saveSmsData(); // Save the cleared state
    notifyListeners();
    print('✅ [SMS_SERVICE] Marked all SMS as read');
  }

  // Force immediate comprehensive status check - ties resting and incoming states
  Future<void> forceComprehensiveStatusCheck() async {
    print('\n🔍 [SMS_COMPREHENSIVE] === COMPREHENSIVE STATUS CHECK ===');

    // Check current in-memory state
    final memoryTotal = _smsMessages.length;
    final memoryRead = _smsMessages.where((msg) => msg['read'] == true).length;
    final memoryUnread = _smsMessages.where((msg) => msg['read'] == false).length;

    print('💾 [SMS_COMPREHENSIVE] Current Memory State: Total=$memoryTotal | Read=$memoryRead | Unread=$memoryUnread');

    // Check device inbox for comparison
    try {
      final result = await platform.invokeMethod('loadSmsInbox');
      if (result != null && result is List) {
        final deviceUnread = result.length;
        print('📱 [SMS_COMPREHENSIVE] Device Inbox State: $deviceUnread unread SMS');

        // Compare memory vs device
        if (deviceUnread != memoryUnread) {
          print('⚠️ [SMS_COMPREHENSIVE] MISMATCH: Memory($memoryUnread) ≠ Device($deviceUnread)');
        } else {
          print('✅ [SMS_COMPREHENSIVE] SYNC: Memory and device counts match');
        }
      }
    } catch (e) {
      print('❌ [SMS_COMPREHENSIVE] Error checking device inbox: $e');
    }

    // Check periodic monitoring state
    final periodicActive = _smsCheckTimer?.isActive ?? false;
    final listenerActive = _isListening;
    print('⚙️ [SMS_COMPREHENSIVE] System State: Periodic=$periodicActive | Listener=$listenerActive');

    // Check message sources and ages
    final sources = _smsMessages.map((msg) => msg['source'] ?? 'unknown').toSet();
    print('🏷️ [SMS_COMPREHENSIVE] Message Sources: $sources');

    if (_smsMessages.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldest = _smsMessages.map((msg) => msg['timestamp'] ?? 0).reduce((a, b) => a < b ? a : b);
      final newest = _smsMessages.map((msg) => msg['timestamp'] ?? 0).reduce((a, b) => a > b ? a : b);

      final oldestHours = (now - oldest) / (1000 * 60 * 60);
      final newestHours = (now - newest) / (1000 * 60 * 60);

      print('⏰ [SMS_COMPREHENSIVE] Time Range: Oldest=${oldestHours.toStringAsFixed(1)}h ago | Newest=${newestHours.toStringAsFixed(1)}h ago');
    }

    // Check stream listeners
    final streamListeners = _unreadCountController.hasListener;
    print('🌊 [SMS_COMPREHENSIVE] Stream State: Has listeners=$streamListeners');

    print('🔗 [SMS_COMPREHENSIVE] State transition ready - incoming SMS will integrate with this resting state');
    print('✅ [SMS_COMPREHENSIVE] === STATUS CHECK COMPLETE ===\n');
  }

  // Start real-time SMS monitoring (no more 2-minute delays)
  void _startRealTimeMonitoring() {
    // Cancel any existing timer to remove old 2-minute cycle
    _smsCheckTimer?.cancel();

    // Start immediate inbox check on startup
    _checkInboxImmediately();

    // Set up frequent inbox checks to detect new SMS (every 10 seconds)
    _smsCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        print('🔄 [SMS_REALTIME] Checking for new SMS...');

        // Actually check device inbox for new messages
        await _refreshInboxPeriodically();

        // Log current status after refresh
        final currentStatus = {
          'total': _smsMessages.length,
          'unread': _unreadSmsCount,
          'listening': _isListening,
          'timestamp': DateTime.now().toIso8601String()
        };
        print('📊 [SMS_REALTIME] Status after refresh: $currentStatus');

        // Force UI update if needed
        notifyListeners();

      } catch (e) {
        print('❌ [SMS_REALTIME] Error during SMS refresh check: $e');
      }
    });

    print('✅ [SMS_SERVICE] Real-time monitoring started (10-second inbox checks)');
  }

  // Immediate inbox check on startup
  Future<void> _checkInboxImmediately() async {
    try {
      print('🚀 [SMS_REALTIME] Immediate inbox check on startup...');
      await _loadSmsMessages(); // Load any existing unread SMS
      print('✅ [SMS_REALTIME] Initial inbox check complete');
    } catch (e) {
      print('❌ [SMS_REALTIME] Error during immediate inbox check: $e');
    }
  }

  // Periodic inbox refresh for fresh SMS updates
  Future<void> _refreshInboxPeriodically() async {
    try {
      print('🔍 [SMS_INBOX_REFRESH] Checking for new SMS in device inbox...');

      // Query device SMS inbox for any new messages
      final result = await platform.invokeMethod('loadSmsInbox');

      if (result != null && result is List) {
        final List<dynamic> rawList = result;
        final inboxSms = rawList.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).toList();

        int newSmsCount = 0;

        // Process each SMS from inbox
        for (final smsData in inboxSms) {
          // Check if we already have this SMS (avoid duplicates)
          final existingIndex = _smsMessages.indexWhere((msg) => msg['id'] == smsData['id']);
          if (existingIndex == -1) {
            // Add new SMS from inbox
            final messageData = {
              'id': smsData['id'],
              'body': smsData['message'] ?? '',
              'sender': smsData['sender'] ?? '',
              'timestamp': smsData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              'read': false,
              'source': 'inbox_refresh', // Mark as loaded from periodic refresh
            };

            _smsMessages.insert(0, messageData);
            newSmsCount++;
            print('🆕 [SMS_INBOX_REFRESH] New SMS detected: ${smsData['sender']} - "${smsData['message']?.substring(0, 50)}..."');
          }
        }

        if (newSmsCount > 0) {
          // Update count and emit stream event for new messages
          _updateUnreadCount();
          print('📨 [SMS_INBOX_REFRESH] Added $newSmsCount new SMS messages to inbox');
        } else {
          print('📋 [SMS_INBOX_REFRESH] No new SMS messages found');
        }
      } else {
        print('📋 [SMS_INBOX_REFRESH] No SMS data returned from device inbox');
      }

    } catch (e) {
      print('❌ [SMS_INBOX_REFRESH] Error refreshing inbox: $e');
    }
  }

  // Immediate startup status logging
  void _logImmediateStartupStatus() {
    try {
      print('\n🚀 [SMS_SERVICE] === IMMEDIATE STARTUP STATUS ===');

      final readCount = _smsMessages.where((msg) => msg['read'] == true).length;
      final unreadCount = _smsMessages.where((msg) => msg['read'] == false).length;
      final recentCount = getRecentSms().length;
      final totalCount = _smsMessages.length;

      print('📊 [STARTUP_STATUS] Total SMS: $totalCount | Read: $readCount | Unread: $unreadCount | Recent (24h): $recentCount');
      print('📊 [STARTUP_STATUS] SMS Listener Active: $_isListening');
      print('📊 [STARTUP_STATUS] Real-time Monitoring: Every 10 seconds');

      if (totalCount > 0) {
        final latestSms = _smsMessages.first;
        final oldestSms = _smsMessages.last;
        final latestTime = DateTime.fromMillisecondsSinceEpoch(latestSms['timestamp'] ?? 0);
        final oldestTime = DateTime.fromMillisecondsSinceEpoch(oldestSms['timestamp'] ?? 0);

        print('📱 [STARTUP_INBOX] Latest SMS: ${latestSms['sender']} at ${latestTime.toIso8601String()}');
        print('📱 [STARTUP_INBOX] Oldest SMS: ${oldestSms['sender']} at ${oldestTime.toIso8601String()}');
        print('📱 [STARTUP_INBOX] Time span: ${oldestTime.difference(latestTime).inHours} hours');
      } else {
        print('📱 [STARTUP_INBOX] Inbox empty - no SMS messages stored');
      }

      print('✅ [SMS_SERVICE] === STARTUP STATUS COMPLETE ===\n');

    } catch (e) {
      print('❌ [SMS_SERVICE] Error logging startup status: $e');
    }
  }

  // Dispose resources
  @override
  void dispose() {
    _smsCheckTimer?.cancel();
    _isListening = false;

    // Save data before disposing
    _saveSmsData();

    // Close stream controllers to prevent memory leaks
    _smsArrivalController.close();
    _unreadCountController.close();

    print('🗑️ [SMS_SERVICE] Disposed SMS service');

    super.dispose();
  }
}

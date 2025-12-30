import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService extends ChangeNotifier {
  List<Map<String, dynamic>> _smsMessages = [];
  int _unreadSmsCount = 0;
  Timer? _smsCheckTimer;
  bool _isListening = false;

  List<Map<String, dynamic>> get smsMessages => _smsMessages;
  int get unreadSmsCount => _unreadSmsCount;
  bool get isListening => _isListening;

  // Initialize SMS service
  Future<void> initialize() async {
    try {
      // Request SMS permissions
      final smsPermission = await Permission.sms.request();
      final receiveSmsPermission = await Permission.sms.request();
      final readSmsPermission = await Permission.sms.request();

      if (smsPermission.isGranted || receiveSmsPermission.isGranted || readSmsPermission.isGranted) {
        print('✅ SMS permissions granted');
        await _loadSmsMessages();
        await _startSmsListener();
      } else {
        print('❌ SMS permissions denied');
      }
    } catch (e) {
      print('❌ Error initializing SMS service: $e');
    }
  }

  // Load SMS messages from inbox
  Future<void> _loadSmsMessages() async {
    try {
      print('📱 Loading SMS messages...');

      // Note: flutter_sms doesn't provide direct SMS reading
      // We'll simulate SMS detection by checking periodically
      // In a real implementation, you might need a different approach
      // or use platform channels to access SMS directly

      _smsMessages = [];
      _updateUnreadCount();
      print('📱 SMS service initialized (simulated)');

      notifyListeners();
    } catch (e) {
      print('❌ Error loading SMS messages: $e');
    }
  }

  // Start listening for incoming SMS (simulated)
  Future<void> _startSmsListener() async {
    try {
      print('👂 Starting SMS listener (simulated)...');

      // Since flutter_sms doesn't provide real-time SMS listening,
      // we'll simulate SMS detection by periodically checking
      // In production, you might need to implement platform channels
      // or use a different SMS package

      _smsCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _simulateSmsCheck();
      });

      _isListening = true;
      print('✅ SMS listener started (simulated)');
    } catch (e) {
      print('❌ Error starting SMS listener: $e');
      _isListening = false;
    }
  }

  // Simulate SMS checking (for testing purposes)
  void _simulateSmsCheck() {
    // This is a simulation - in real implementation,
    // you would check actual SMS inbox for new messages
    // For now, we'll just maintain the count
    // You can call incrementSmsCount() from external triggers
  }

  // Method to increment SMS count (call this when SMS is detected)
  void incrementSmsCount() {
    _unreadSmsCount++;
    print('📨 SMS count increased to $_unreadSmsCount');
    notifyListeners();
  }

  // Method to simulate receiving SMS (for testing)
  void simulateIncomingSms() {
    final smsData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'body': 'Test SMS message',
      'sender': '+1234567890',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
    };

    _smsMessages.insert(0, smsData);
    _unreadSmsCount++;
    print('📨 Simulated SMS received, count now: $_unreadSmsCount');

    notifyListeners();
  }

  // Update unread SMS count
  void _updateUnreadCount() {
    _unreadSmsCount = _smsMessages.where((msg) => msg['read'] == false).length;
  }

  // Mark SMS as read
  Future<void> markSmsAsRead(String messageId) async {
    try {
      final index = _smsMessages.indexWhere((msg) => msg['id'] == messageId);
      if (index != -1) {
        _smsMessages[index]['read'] = true;
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking SMS as read: $e');
    }
  }

  // Mark all SMS as read
  void markAllSmsAsRead() {
    for (var msg in _smsMessages) {
      msg['read'] = true;
    }
    _unreadSmsCount = 0;
    notifyListeners();
  }

  // Get recent SMS messages (last 24 hours)
  List<Map<String, dynamic>> getRecentSms() {
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    return _smsMessages.where((msg) {
      final messageTime = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] ?? 0);
      return messageTime.isAfter(oneDayAgo);
    }).toList();
  }

  // Dispose resources
  void dispose() {
    _smsCheckTimer?.cancel();
    _isListening = false;
    super.dispose();
  }
}

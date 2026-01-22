                                                                                                                                                                                                                                                                                              import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'pages/activation_page.dart';
import 'pages/pdf_view_page.dart';
import 'utils/api_client.dart';
import 'services/micro_server_service.dart';
import 'services/heartbeat_service.dart';
import 'services/printer_service.dart';
import 'services/sms_service.dart';
import 'widgets/blinking_sms_icon.dart';
import 'widgets/sms_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend URL from shared preferences
  try {
    await ApiClient.initializeBackendUrl();
  } catch (e) {
    print('⚠️  Failed to initialize backend URL: $e');
  }

  // Start micro-server
  try {
    await MicroServerService.startServer();

  } catch (e) {
    print('⚠️  Failed to start micro-server: $e');
  }

  // Resume heartbeat service if needed
  try {
    await HeartbeatService.resumeIfNeeded();
  } catch (e) {
    print('⚠️  Failed to resume heartbeat service: $e');
  }

  runApp(const BluPOSWalletApp());
}

class BluPOSWalletApp extends StatelessWidget {
  const BluPOSWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PrinterService>(
          create: (_) => PrinterServiceFactory.create(),
        ),
      ],
      child: MaterialApp(
        title: 'BluPOS Wallet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF182A62),
          scaffoldBackgroundColor: const Color(0xFFD7D7D7),
          fontFamily: 'Poppins',
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF182A62),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

enum AppState { firstTime, active, expired }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  AppState _appState = AppState.firstTime;
  bool _isLoading = true;
  String _expiryDateDisplay = '--/--/----';
  String _accountIdDisplay = 'Not Activated';
  bool _isSyncing = false;

  // SMS service for blinking animation
  late final SmsService _smsService;
  late StreamSubscription<void> _smsArrivalSubscription;
  late StreamSubscription<int> _unreadCountSubscription;
  bool _showBlinkingSms = false;
  int _currentUnreadCount = 0;
  double _totalSales = 0.0;



  // Reactive payments data
  List<Map<String, dynamic>> _paymentsData = [];
  bool _paymentsLoading = false;
  Timer? _paymentsRefreshTimer;

  // Reactive pending payments data
  List<Map<String, dynamic>> _pendingPaymentsData = [];
  bool _pendingPaymentsLoading = false;

  // SMS sync functionality
  bool _isSmsSyncing = false;
  String _lastSyncResult = '';
  Timer? _smsSyncTimer;

  // Menu summary data
  Map<String, dynamic> _checkoutSummary = {};
  Map<String, dynamic> _itemsSummary = {};
  Map<String, dynamic> _salesSummary = {};
  bool _checkoutSummaryLoading = false;
  bool _itemsSummaryLoading = false;
  bool _salesSummaryLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize SMS service
    print('📱 [SMS] Initializing SMS service...');
    _smsService = SmsService();
    await _smsService.initialize(); // ← CRITICAL: This was missing!
    print('✅ [SMS] SMS service initialized successfully');

    // Listen for SMS arrival (for initial trigger)
    print('👂 [SMS] Setting up SMS arrival listener...');
    _smsArrivalSubscription = _smsService.onSmsArrival.listen((_) {
      print('📨 [SMS] SMS arrival detected - triggering blink animation');
      if (mounted) {
        setState(() {
          _showBlinkingSms = true;
        });
      }
    });
    print('✅ [SMS] SMS arrival listener active');

    // Listen for unread count changes (for continuous blinking)
    print('🔢 [SMS] Setting up unread count change listener...');
    _unreadCountSubscription = _smsService.onUnreadCountChanged.listen((count) {
      print('📊 [SMS] MAIN LISTENER: Unread count changed: $count messages');
      if (mounted) {
        // Use post-frame callback to ensure UI thread safety
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print('🔄 [SMS] MAIN LISTENER: Updating UI with unread count: $count');
            setState(() {
              _currentUnreadCount = count;
              _showBlinkingSms = count > 0;
              print('🎯 [SMS] MAIN LISTENER: UI state updated - _currentUnreadCount: $_currentUnreadCount, _showBlinkingSms: $_showBlinkingSms');
            });
          }
        });
      }
    });
    print('✅ [SMS] Unread count listener active');

    // Initialize UI with current count directly
    print('🔄 [SMS] Initializing UI with current unread count...');
    if (mounted) {
      setState(() {
        _currentUnreadCount = _smsService.unreadSmsCount;
        _showBlinkingSms = _currentUnreadCount > 0;
        print('🎯 [SMS] UI initialized with unread count: $_currentUnreadCount, blinking: $_showBlinkingSms');
      });
    }

    _loadAppState();
    _autoConnectSavedPrinter();
  }

  Future<void> _autoConnectSavedPrinter() async {
    try {
      final printerService = Provider.of<PrinterService>(context, listen: false);
      if (printerService is AndroidPrinterService) {
        await printerService.autoConnectSavedPrinter();
      }
    } catch (e) {
      debugPrint('Auto-connect failed: $e');
    }
  }

  @override
  void dispose() {
    _smsArrivalSubscription.cancel();
    _unreadCountSubscription.cancel();
    _paymentsRefreshTimer?.cancel();
    _smsSyncTimer?.cancel();
    super.dispose();
  }







  Future<void> _loadAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var isActivated = prefs.getBool('isActivated') ?? false;
      var licenseExpiry = prefs.getString('licenseExpiry');
      var accountId = prefs.getString('persistentAccountId');

      print('🔍 Loading app state - isActivated: $isActivated, expiry: $licenseExpiry, accountId: $accountId');

      // Clear old cached values if they appear to be from before our UTC fixes
      if (licenseExpiry != null && licenseExpiry.contains('2026-01-27')) {
        print('🧹 Detected old cached expiry date, clearing...');
        await prefs.remove('licenseExpiry');
        await prefs.remove('persistentAccountId');
        await prefs.setBool('isActivated', false);
        // Reload values after clearing
        final clearedPrefs = await SharedPreferences.getInstance();
        isActivated = clearedPrefs.getBool('isActivated') ?? false;
        licenseExpiry = clearedPrefs.getString('licenseExpiry');
        accountId = clearedPrefs.getString('persistentAccountId');
      }

      // Try to sync with BluPOS, but don't let it block app loading
      try {
        await _syncRealDataFromBluPOS();
        print('✅ Real data sync completed');

        // Reload synced values
        final syncedPrefs = await SharedPreferences.getInstance();
        final syncedIsActivated = syncedPrefs.getBool('isActivated') ?? false;
        final syncedLicenseExpiry = syncedPrefs.getString('licenseExpiry');
        final syncedAccountId = syncedPrefs.getString('persistentAccountId');

        // Update state with synced data
        isActivated = syncedIsActivated;
        licenseExpiry = syncedLicenseExpiry;
        accountId = syncedAccountId;
      } catch (e) {
        print('⚠️ BluPOS real data sync failed, using local state: $e');
      }

      // Format display values
      if (licenseExpiry != null) {
        final expiryDate = DateTime.tryParse(licenseExpiry);
        if (expiryDate != null) {
          _expiryDateDisplay = '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.year}';
        } else {
          _expiryDateDisplay = '--/--/----';
        }
      } else {
        _expiryDateDisplay = '--/--/----';
      }

      if (accountId != null && accountId.isNotEmpty) {
        final accountParts = accountId.split('_');
        if (accountParts.length > 1) {
          _accountIdDisplay = accountParts.last;
        } else {
          _accountIdDisplay = accountId;
        }
      } else {
        _accountIdDisplay = 'Not Activated';
      }

      // Determine app state
      if (!isActivated) {
        _appState = AppState.firstTime;
      } else if (licenseExpiry != null) {
        final expiryDate = DateTime.tryParse(licenseExpiry);
        if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
          _appState = AppState.expired;
        } else {
          _appState = AppState.active;
        }
      } else {
        _appState = AppState.active;
      }

      print('🎯 Final app state: $_appState');

    } catch (e) {
      print('❌ Critical error in _loadAppState: $e');
      // Fallback to first time state
      _appState = AppState.firstTime;
      _expiryDateDisplay = '--/--/----';
      _accountIdDisplay = 'Not Activated';
    } finally {
      // Always set loading to false, even if there are errors
      setState(() {
        _isLoading = false;
      });

      // Start reactive payments loading after app state is loaded
      if (_appState == AppState.active) {
        _startReactivePayments();
      }
    }
  }

  // Start reactive payments loading and timer
  void _startReactivePayments() {
    _loadPaymentsData();
    _loadPendingPaymentsData();
    _startPaymentsRefreshTimer();
    _startSmsSyncTimer();
  }

  // Load payments data reactively
  Future<void> _loadPaymentsData() async {
    if (!mounted) return;

    print('🔄 [APK] Starting refetch for CLEARED payments data...');
    final startTime = DateTime.now();

    setState(() {
      _paymentsLoading = true;
    });

    try {
      final payments = await _getRealPayments();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      print('✅ [APK] CLEARED payments refetch completed: ${payments.length} records in ${duration.inMilliseconds}ms');

      if (mounted) {
        setState(() {
          _paymentsData = payments;
          _paymentsLoading = false;
        });
      }
    } catch (e) {
      print('❌ [APK] CLEARED payments refetch failed: $e');
      if (mounted) {
        setState(() {
          _paymentsLoading = false;
        });
      }
    }
  }

  // Start timer for periodic payments refresh
  void _startPaymentsRefreshTimer() {
    _paymentsRefreshTimer?.cancel();
    _paymentsRefreshTimer = Timer.periodic(
      const Duration(seconds: 30), // Refresh every 30 seconds
      (_) {
        _loadPaymentsData();      // Refresh cleared payments
        _loadPendingPaymentsData(); // Also refresh pending payments
      },
    );
  }

  // Start timer for automatic SMS sync (option 9 from query_microserver.py)
  void _startSmsSyncTimer() {
    _smsSyncTimer?.cancel();
    _smsSyncTimer = Timer.periodic(
      const Duration(seconds: 5), // Sync SMS every 5 seconds (option 9)
      (_) => _performSmsSync(),
    );
  }

  // Perform SMS sync (equivalent to option 9: export_valid_payments from query_microserver.py)
  Future<void> _performSmsSync() async {
    if (!mounted || _isSmsSyncing) return;

    print('🔄 Exporting valid payments from shortcodes to backend...');
    final startTime = DateTime.now();

    setState(() {
      _isSmsSyncing = true;
    });

    try {
      // Step 1: Query SMS from approved shortcodes from MICROSERVER (port 8085, like query_microserver.py)
      final microserverUrl = await _getMicroserverUrl('/sms/shortcodes');
      print('🔍 Querying: GET $microserverUrl');

      final shortcodesResponse = await http.get(Uri.parse(microserverUrl)).timeout(const Duration(seconds: 30));

      if (shortcodesResponse.statusCode != 200) {
        print('❌ Failed to get shortcode SMS: ${shortcodesResponse.statusCode}');
        setState(() {
          _lastSyncResult = 'Failed to get SMS data (${DateTime.now().difference(startTime).inMilliseconds}ms)';
        });
        return;
      }

      final smsData = jsonDecode(shortcodesResponse.body);
      final messages = smsData['messages'] as List<dynamic>? ?? [];

      if (messages.isEmpty) {
        print('ℹ️ No shortcode SMS messages found');
        setState(() {
          _lastSyncResult = 'No SMS to export (${DateTime.now().difference(startTime).inMilliseconds}ms)';
        });
        return;
      }

      print('📱 Found ${messages.length} shortcode messages');

      // Step 2: Process each message (exact logic from query_microserver.py)
      int exportedCount = 0;
      for (final msg in messages) {
        try {
          // Extract payment info from message - adjust field names based on actual microserver response
          final messageText = msg['body'] as String? ?? msg['message'] as String? ?? '';

          String channel = '';
          String reference = '';

          // Extract channel from message content (Account number in the message)
          if (messageText.toLowerCase().contains('account')) {
            final accountMatch = RegExp(r'(?:merchant\s+)?[Aa]ccount\s+(\d+)').firstMatch(messageText);
            if (accountMatch != null) {
              channel = accountMatch.group(1)!;
            }
          }

          // Extract reference (multiple formats)
          // Format 1: "ref #ABC123" (57938 merchant account format)
          var refMatch = RegExp(r'ref\s*#\s*([A-Z0-9]+)', caseSensitive: false).firstMatch(messageText);
          if (refMatch != null) {
            reference = refMatch.group(1)!;
            print('   🔗 Reference extracted via \'ref #\' format: \'$reference\'');
          } else {
            // Format 2: "ABC123~" (reference before tilde, 80872 account format)
            final tildeMatch = RegExp(r'([A-Z0-9]+)~').firstMatch(messageText);
            if (tildeMatch != null) {
              reference = tildeMatch.group(1)!;
              print('   🔗 Reference extracted via \'~\' format: \'$reference\'');
            } else {
              print('   ⚠️ No reference found in message');
            }
          }

          // Debug: Print message data to see what's available
          print('🔍 Processing message ID ${msg['id']}:');
          print('   📄 Full message data: $msg');
          print('   🔍 Extracted channel: \'$channel\' (length: ${channel.length})');
          print('   🔗 Extracted reference: \'$reference\' (length: ${reference.length})');
          print('   📝 Extracted message: \'${messageText.substring(0, messageText.length > 50 ? 50 : messageText.length)}...\' (length: ${messageText.length})');

          // Validate required fields
          if (channel.isEmpty || messageText.isEmpty) {
            print('⚠️ Skipping message ${msg['id']}: missing channel or message');
            continue;
          }

          // Send to backend SMS processing endpoint (microserver version bypasses auth)
          final paymentData = {
            'channel': channel,
            'message': messageText,
            'reference': reference.isNotEmpty ? reference : null
          };

          final backendUrl = await _getBackendUrl('/api/sms/process_microserver');
          final backendResponse = await http.post(
            Uri.parse(backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(paymentData),
          ).timeout(const Duration(seconds: 10));

          if (backendResponse.statusCode == 200) {
            exportedCount++;
            print('✅ Exported payment from channel $channel');
          } else {
            print('⚠️ Failed to export payment from channel $channel: ${backendResponse.statusCode}');
            // Print backend error response for debugging
            try {
              final errorData = jsonDecode(backendResponse.body);
              print('   Backend error: ${errorData['message'] ?? 'Unknown error'}');
            } catch (e) {
              print('   Backend response: ${backendResponse.body.substring(0, backendResponse.body.length > 200 ? 200 : backendResponse.body.length)}...');
            }
          }

        } catch (e) {
          print('❌ Error processing message ${msg['id']}: $e');
        }
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      print('📊 Successfully exported $exportedCount/${messages.length} payments to backend');

      setState(() {
        _lastSyncResult = 'Success: $exportedCount/${messages.length} payments exported (${duration.inMilliseconds}ms)';
      });

      // Refresh payment data after successful sync
      await _loadPaymentsData();
      await _loadPendingPaymentsData();

    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      print('❌ Error in export_valid_payments: $e');
      setState(() {
        _lastSyncResult = 'Error: $e (${duration.inMilliseconds}ms)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSmsSyncing = false;
        });
      }
    }
  }

  // Extract exported count from microserver response
  int _extractExportedCount(String responseBody) {
    try {
      // Look for patterns like "Successfully exported X/Y payments"
      final exportedMatch = RegExp(r'Successfully exported (\d+)/(\d+) payments').firstMatch(responseBody);
      if (exportedMatch != null) {
        return int.tryParse(exportedMatch.group(1) ?? '0') ?? 0;
      }

      // Fallback: look for any number followed by "payments exported"
      final fallbackMatch = RegExp(r'(\d+)\s+payments?\s+exported').firstMatch(responseBody);
      if (fallbackMatch != null) {
        return int.tryParse(fallbackMatch.group(1) ?? '0') ?? 0;
      }

      return 0;
    } catch (e) {
      print('⚠️ [APK] Error extracting export count: $e');
      return 0;
    }
  }

  // Load pending payments data reactively
  Future<void> _loadPendingPaymentsData() async {
    if (!mounted) return;

    print('🔄 [APK] Starting refetch for PENDING payments data...');
    final startTime = DateTime.now();

    setState(() {
      _pendingPaymentsLoading = true;
    });

    try {
      final pendingPayments = await _getPendingPayments();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      print('✅ [APK] PENDING payments refetch completed: ${pendingPayments.length} records in ${duration.inMilliseconds}ms');

      if (mounted) {
        setState(() {
          _pendingPaymentsData = pendingPayments;
          _pendingPaymentsLoading = false;
        });
      }
    } catch (e) {
      print('❌ [APK] PENDING payments refetch failed: $e');
      if (mounted) {
        setState(() {
          _pendingPaymentsLoading = false;
        });
      }
    }
  }

  // Manual refresh for pull-to-refresh
  Future<void> _refreshPayments() async {
    await _loadPaymentsData();
    await _loadPendingPaymentsData();
  }

  Future<void> _syncRealDataFromBluPOS() async {
    // Sync license state first
    final bluposState = await _syncWithBluPOS();
    if (bluposState != null && bluposState['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();

      // Update license data
      final bluposAppState = bluposState['app_state'];
      final bluposExpiry = bluposState['license_expiry'];
      final bluposAccountId = bluposState['account_id'];

      if (bluposAccountId != null) {
        await prefs.setString('persistentAccountId', bluposAccountId);
      }

      if (bluposExpiry != null) {
        await prefs.setString('licenseExpiry', bluposExpiry);
      }

      if (bluposAppState == 'active') {
        await prefs.setBool('isActivated', true);
      } else if (bluposAppState == 'expired') {
        await prefs.setBool('isActivated', false);
      } else if (bluposAppState == 'first_time') {
        await prefs.setBool('isActivated', false);
        await prefs.remove('licenseExpiry');
      }

      // Reset connection failure counter on success
      await prefs.setInt('connection_failures', 0);
    } else {
      // Connection failed - increment failure counter
      final prefs = await SharedPreferences.getInstance();
      final failureCount = (prefs.getInt('connection_failures') ?? 0) + 1;
      await prefs.setInt('connection_failures', failureCount);

      print('🔴 Connection failure count: $failureCount');

      // Show connection failure warning after 3 consecutive failures
      if (failureCount >= 3 && mounted && !_isLoading) {
        print('🚨 Too many connection failures, showing warning');
        await prefs.setInt('connection_failures', 0); // Reset counter

        // Show connection failure warning on next frame to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Network connection issues detected. Please check your network settings.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    }

    // Sync balance and payments data
    await _fetchRealBalanceAndPayments();
  }

  Future<void> _fetchRealBalanceAndPayments() async {
    try {
      print('🔄 Starting real data fetch...');

      // Get the configured backend URL
      final balanceUrl = await _getBackendUrl('/get_total_sales');
      final paymentsUrl = await _getBackendUrl('/get_latest_payments');

      // Fetch real balance from BluPOS using configured backend URL
      final balanceResponse = await http.get(Uri.parse(balanceUrl));
      print('💰 Balance response status: ${balanceResponse.statusCode}');
      print('💰 Balance response body: ${balanceResponse.body}');

      if (balanceResponse.statusCode == 200) {
        final balanceData = jsonDecode(balanceResponse.body);
        print('💰 Parsed balance data: $balanceData');

        if (balanceData['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          final balanceValue = balanceData['total_sales'] ?? '0.00';
          await prefs.setString('real_balance', balanceValue.toString());
          print('💰 Stored real balance: $balanceValue');

          // Update total sales for SMS indicator
          final parsedBalanceValue = double.tryParse(balanceValue.toString()) ?? 0.0;
          if (mounted) {
            setState(() {
              _totalSales = parsedBalanceValue;
            });
          }
        } else {
          print('❌ Balance API returned error: ${balanceData['message']}');
        }
      } else {
        print('❌ Balance API failed with status: ${balanceResponse.statusCode}');
      }

      // Note: Payments are now fetched real-time, no persistence

      print('✅ Real data fetch completed');
    } catch (e) {
      print('❌ Failed to fetch real balance/payments: $e');
      print('❌ Error details: ${e.toString()}');
    }
  }



  Future<String> _getRealBalanceDisplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final realBalance = prefs.getString('real_balance');
      if (realBalance != null && realBalance.isNotEmpty) {
        final balanceValue = double.tryParse(realBalance) ?? 0.0;
        // Format with commas for thousands separator
        final formattedBalance = _formatCurrencyWithCommas(balanceValue);
        return 'KES $formattedBalance';
      }
    } catch (e) {
      print('❌ Error getting real balance: $e');
    }
    return _appState == AppState.firstTime ? 'KES 0.00' : 'KES 0.00';
  }

  // Helper method to format currency with commas
  String _formatCurrencyWithCommas(double amount) {
    final numberFormat = NumberFormat('#,##0.00', 'en_US');
    return numberFormat.format(amount);
  }

  Future<List<Map<String, dynamic>>> _getRealPayments() async {
    try {
      // Fetch real-time payments directly from the backend
      final paymentsUrl = await _getBackendUrl('/get_latest_payments');
      final paymentsResponse = await http.get(Uri.parse(paymentsUrl));

      if (paymentsResponse.statusCode == 200) {
        final paymentsData = jsonDecode(paymentsResponse.body);

        if (paymentsData['status'] == 'success' && paymentsData['payments'] != null) {
          final payments = paymentsData['payments'] as List<dynamic>;
          final paymentsList = payments.cast<Map<String, dynamic>>();

          // Sort chronologically from latest (top) to oldest (bottom)
          paymentsList.sort((a, b) {
            final dateA = a['datetime'];
            final dateB = b['datetime'];

            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1; // null dates go to bottom
            if (dateB == null) return -1;

            try {
              final parsedA = DateTime.parse(dateA);
              final parsedB = DateTime.parse(dateB);
              return parsedB.compareTo(parsedA); // Latest first
            } catch (e) {
              print('⚠️ Error parsing payment dates: $e');
              return 0;
            }
          });

          return paymentsList;
        }
      } else {
        print('❌ Payments API failed with status: ${paymentsResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching real-time payments: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getPendingPayments() async {
    try {
      // Fetch pending payments directly from the backend
      final pendingUrl = await _getBackendUrl('/api/sms/pending_payments');
      final pendingResponse = await http.get(Uri.parse(pendingUrl));

      if (pendingResponse.statusCode == 200) {
        final pendingData = jsonDecode(pendingResponse.body);

        if (pendingData['status'] == 'success' && pendingData['payments'] != null) {
          final payments = pendingData['payments'] as List<dynamic>;
          final pendingPaymentsList = payments.cast<Map<String, dynamic>>();

          // Sort by creation date, most recent first
          pendingPaymentsList.sort((a, b) {
            final dateA = a['created_at'] ?? a['date'];
            final dateB = b['created_at'] ?? b['date'];

            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;

            try {
              final parsedA = DateTime.tryParse(dateA) ?? DateTime.now();
              final parsedB = DateTime.tryParse(dateB) ?? DateTime.now();
              return parsedB.compareTo(parsedA); // Most recent first
            } catch (e) {
              print('⚠️ Error parsing pending payment dates: $e');
              return 0;
            }
          });

          return pendingPaymentsList;
        }
      } else {
        print('❌ Pending payments API failed with status: ${pendingResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching pending payments: $e');
    }
    return [];
  }

  Future<void> _loadCheckoutSummary() async {
    if (!mounted) return;

    print('🔄 Loading checkout summary data...');
    setState(() {
      _checkoutSummaryLoading = true;
    });

    try {
      final summaryUrl = await _getBackendUrl('/api/checkout_summary');
      final summaryResponse = await http.get(Uri.parse(summaryUrl));

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);

        if (summaryData['status'] == 'success' && summaryData['data'] != null) {
          if (mounted) {
            setState(() {
              _checkoutSummary = summaryData['data'];
              _checkoutSummaryLoading = false;
            });
          }
          print('✅ Checkout summary loaded: ${_checkoutSummary.length} metrics');
        } else {
          print('❌ Checkout summary API returned error: ${summaryData['message']}');
          if (mounted) {
            setState(() {
              _checkoutSummaryLoading = false;
            });
          }
        }
      } else {
        print('❌ Checkout summary API failed with status: ${summaryResponse.statusCode}');
        if (mounted) {
          setState(() {
            _checkoutSummaryLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching checkout summary: $e');
      if (mounted) {
        setState(() {
          _checkoutSummaryLoading = false;
        });
      }
    }
  }

  Future<void> _loadItemsSummary() async {
    if (!mounted) return;

    print('🔄 Loading items summary data...');
    setState(() {
      _itemsSummaryLoading = true;
    });

    try {
      final summaryUrl = await _getBackendUrl('/api/items_summary');
      final summaryResponse = await http.get(Uri.parse(summaryUrl));

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);

        if (summaryData['status'] == 'success' && summaryData['data'] != null) {
          if (mounted) {
            setState(() {
              _itemsSummary = summaryData['data'];
              _itemsSummaryLoading = false;
            });
          }
          print('✅ Items summary loaded: ${_itemsSummary.length} metrics');
        } else {
          print('❌ Items summary API returned error: ${summaryData['message']}');
          if (mounted) {
            setState(() {
              _itemsSummaryLoading = false;
            });
          }
        }
      } else {
        print('❌ Items summary API failed with status: ${summaryResponse.statusCode}');
        if (mounted) {
          setState(() {
            _itemsSummaryLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching items summary: $e');
      if (mounted) {
        setState(() {
          _itemsSummaryLoading = false;
        });
      }
    }
  }

  Future<void> _loadSalesSummary() async {
    if (!mounted) return;

    print('🔄 Loading sales summary data...');
    setState(() {
      _salesSummaryLoading = true;
    });

    try {
      final summaryUrl = await _getBackendUrl('/api/sales_report_data');
      final summaryResponse = await http.get(Uri.parse(summaryUrl));

      if (summaryResponse.statusCode == 200) {
        final summaryData = jsonDecode(summaryResponse.body);

        if (summaryData['status'] == 'success' && summaryData['data'] != null) {
          if (mounted) {
            setState(() {
              _salesSummary = summaryData['data'];
              _salesSummaryLoading = false;
            });
          }
          print('✅ Sales summary loaded: ${_salesSummary.length} metrics');
        } else {
          print('❌ Sales summary API returned error: ${summaryData['message']}');
          if (mounted) {
            setState(() {
              _salesSummaryLoading = false;
            });
          }
        }
      } else {
        print('❌ Sales summary API failed with status: ${summaryResponse.statusCode}');
        if (mounted) {
          setState(() {
            _salesSummaryLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching sales summary: $e');
      if (mounted) {
        setState(() {
          _salesSummaryLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _syncWithBluPOS() async {
    try {
      // Use configured backend URL for BluPOS sync
      final syncUrl = await _getBackendUrl('/activate');
      print('🔄 Syncing with BluPOS: $syncUrl');

      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'check_expiry'})
      );
      print('🔄 BluPOS sync response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('🔄 BluPOS sync response: $data');
        return data;
      } else {
        print('❌ BluPOS sync failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ BluPOS sync request failed: $e');
      return null;
    }
  }

  Future<void> _setActivated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActivated', true);
    // Set license expiry to 30 days from now for demo
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    await prefs.setString('licenseExpiry', expiryDate.toIso8601String());

    // Reload app state to update expiry date display
    await _loadAppState();
  }

  void _navigateToActivation({bool isReactivation = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivationPage(
          onActivationSuccess: _setActivated,
          isReactivation: isReactivation,
        ),
      ),
    );
  }

  void _navigateToCheckout() {
    // TODO: Implement checkout functionality
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checkout - Coming Soon!')),
    );
  }

  void _navigateToReports() async {
    // Load summary data for menu buttons
    await _loadCheckoutSummary();
    await _loadItemsSummary();
    await _loadSalesSummary();

    // Trigger the transition animation
    setState(() {
      _showReportsView = true;
    });
  }

  void _navigateToMainView() {
    // Trigger the reverse transition animation
    setState(() {
      _showReportsView = false;
    });
  }

  bool _showReportsView = false;

  Future<String> _getBackendUrl(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip') ?? 'localhost:8080';

    print('🔗 Saved IP from prefs: $savedIp');

    // Ensure proper URL format with port
    String baseUrl;
    if (savedIp.startsWith('http')) {
      // Already has protocol, make sure it has port
      if (!savedIp.contains(':8080') && !savedIp.contains(':5000')) {
        baseUrl = '$savedIp:8080';
        print('🔗 Added port 8080 to existing URL: $baseUrl');
      } else {
        baseUrl = savedIp;
        print('🔗 URL already has port: $baseUrl');
      }
    } else {
      // Add protocol and ensure port
      if (savedIp.contains(':')) {
        baseUrl = 'http://$savedIp';
        print('🔗 Added http:// to IP with port: $baseUrl');
      } else {
        baseUrl = 'http://$savedIp:8080';
        print('🔗 Added http:// and port 8080 to IP: $baseUrl');
      }
    }

    final fullUrl = '$baseUrl$endpoint';
    print('🔗 Final constructed URL: $fullUrl');
    return fullUrl;
  }

  Future<String> _getMicroserverUrl(String endpoint) async {
    // For microserver, always use localhost (127.0.0.1) or emulator IP (10.0.2.2)
    // NOT the discovered backend IP (192.168.0.102)
    const possibleUrls = [
      'http://localhost:8085',     // Localhost
      'http://127.0.0.1:8085',     // Explicit localhost
      'http://10.0.2.2:8085',      // Android emulator
    ];

    print('🔗 [MICROSERVER] Testing microserver connectivity...');

    // Test each URL to find the working one
    for (final baseUrl in possibleUrls) {
      try {
        final testUrl = '$baseUrl/health';
        final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          print('🔗 [MICROSERVER] Found working microserver at: $baseUrl');
          final fullUrl = '$baseUrl$endpoint';
          print('🔗 [MICROSERVER] Final constructed URL: $fullUrl');
          return fullUrl;
        }
      } catch (e) {
        print('🔗 [MICROSERVER] $baseUrl not accessible: $e');
      }
    }

    // Fallback to localhost if none work (microserver might not be running)
    final fallbackUrl = 'http://localhost:8085$endpoint';
    print('🔗 [MICROSERVER] Using fallback URL: $fallbackUrl');
    print('⚠️ [MICROSERVER] Warning: No microserver found, connection may fail');
    return fallbackUrl;
  }

  void _viewSalesReport() async {
    final pdfUrl = await _getBackendUrl('/get_sale_record_printout');
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ItemsReportPdfView(
            reportType: 'sales',
            pdfUrl: pdfUrl,
          ),
        ),
      );
    }
  }

  void _viewItemsReport() async {
    final pdfUrl = await _getBackendUrl('/get_items_report');
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ItemsReportPdfView(
            reportType: 'inventory',
            pdfUrl: pdfUrl,
          ),
        ),
      );
    }
  }




  // Build the main view with Reports, 4 payments, and Share
  Widget _buildMainView() {
    return Column(
      children: [
        // Reports Section - Single Button
        Container(
          width: double.infinity,
          height: 50 * 1.35,
          margin: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            onPressed: _navigateToReports,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF182A62),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: _isSyncing ? 8 : 2,
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Combined Payments Section - Maintain ratio: 3:1, 2:2, 1:3, or 0:3 (pending:cleared)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payments Overview',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (_pendingPaymentsLoading || _paymentsLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

              // Calculate display ratios based on available data
              Builder(
                builder: (context) {
                  final pendingCount = _pendingPaymentsData.length;
                  final clearedCount = _paymentsData.length;

                  // SANITY CHECK: Ensure no overlap between pending and cleared payments
                  final pendingIds = _pendingPaymentsData.map((p) => p['id']?.toString()).toSet();
                  final clearedIds = _paymentsData.map((p) => p['transaction_id']?.toString()).toSet();

                  // Remove any cleared payments that appear in pending (shouldn't happen but safety check)
                  final overlappingIds = pendingIds.intersection(clearedIds);
                  if (overlappingIds.isNotEmpty) {
                    print('⚠️ SANITY CHECK: Found ${overlappingIds.length} overlapping payment IDs between pending and cleared lists');
                    print('   Overlapping IDs: $overlappingIds');

                    // Filter out overlapping payments from cleared list
                    _paymentsData.removeWhere((payment) =>
                      overlappingIds.contains(payment['transaction_id']?.toString())
                    );

                    print('✅ SANITY CHECK: Removed overlapping payments from cleared list');
                  }

                  // Calculate how many to show based on ratios: 3:1, 2:2, 1:3, or 0:3
                  int showPending = 0;
                  int showCleared = 0;

                  if (pendingCount == 0) {
                    // 0:3 ratio - show up to 3 cleared payments
                    showPending = 0;
                    showCleared = _paymentsData.length > 3 ? 3 : _paymentsData.length;
                  } else if (pendingCount >= 3) {
                    // 3:1 ratio - show 3 pending, 1 cleared
                    showPending = 3;
                    showCleared = _paymentsData.isNotEmpty ? 1 : 0;
                  } else if (pendingCount == 2) {
                    // 2:2 ratio - show 2 pending, 2 cleared
                    showPending = 2;
                    showCleared = _paymentsData.length > 1 ? 2 : _paymentsData.length;
                  } else if (pendingCount == 1) {
                    // 1:3 ratio - show 1 pending, 3 cleared
                    showPending = 1;
                    showCleared = _paymentsData.length > 2 ? 3 : _paymentsData.length;
                  }

                  final totalToShow = showPending + showCleared;

                  if (totalToShow == 0 && !_pendingPaymentsLoading && !_paymentsLoading) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'No payments available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }

                  if (_pendingPaymentsLoading || _paymentsLoading) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // Build combined payments list with proper ratio
                  final paymentsToShow = <Widget>[];

                  // Add pending payments first (higher priority)
                  if (showPending > 0) {
                    paymentsToShow.addAll(_pendingPaymentsData.take(showPending).map((payment) {
                      final amount = payment['amount'] ?? '0.00';
                      final sender = payment['sender'] ?? 'Unknown';
                      final reference = payment['reference'] ?? 'N/A';
                      final paymentId = payment['id'] ?? 'N/A';
                      final datetimeDisplay = payment['datetime_bottom_right'] ?? payment['display_datetime'] ?? 'Unknown time';

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50, // Light orange background for pending
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Transaction ID and Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: $paymentId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'KES ${_formatCurrencyWithCommas(double.tryParse(amount.toString()) ?? 0.0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Bottom row: Sender, Reference, Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$sender • REF: $reference',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(alpha: 0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  datetimeDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            // Pending indicator
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '⏳ PENDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList());
                  }

                  // Add cleared payments (lower priority)
                  if (showCleared > 0) {
                    paymentsToShow.addAll(_paymentsData.take(showCleared).map((payment) {
                      final amount = payment['amount'] ?? '0.00';
                      final datetime = payment['datetime'] ?? '';
                      final salesPerson = payment['sales_person'] ?? 'Unknown';
                      final paymentType = payment['payment_type'] ?? 'Cash';
                      final transactionId = payment['transaction_id'] ?? 'N/A';

                      final adjustedDateTime = datetime.isNotEmpty
                          ? DateTime.tryParse(datetime)?.add(const Duration(hours: 3))?.toLocal()
                          : null;

                      final timeDisplay = adjustedDateTime != null
                          ? adjustedDateTime.toString().split(' ')[1].substring(0, 5)
                          : '--:--';

                      final dateDisplay = adjustedDateTime != null
                          ? adjustedDateTime.toString().split(' ')[0]
                          : '';

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Transaction ID and Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: $transactionId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'KES ${_formatCurrencyWithCommas(double.tryParse(amount) ?? 0.0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Bottom row: Clerk, Payment Type, Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$salesPerson • $paymentType',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(alpha: 0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$dateDisplay $timeDisplay',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            // Cleared indicator
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '✅ CLEARED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList());
                  }

                  return Column(children: paymentsToShow);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16), // Bottom spacing
      ],
    );
  }

  // Build the reports view with Back, Checkout, Sales, Items, and About
  Widget _buildReportsView() {
    // Define glass-like blue gradient colors
    final glassBlueStart = const Color(0xFF182A62).withOpacity(0.9);
    final glassBlueEnd = const Color(0xFF182A62).withOpacity(0.7);

    return Column(
      children: [
        // Back Button
        Container(
          width: double.infinity,
          height: 50 * 1.35,
          margin: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            onPressed: _navigateToMainView,
            style: ElevatedButton.styleFrom(
              backgroundColor: glassBlueStart,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF182A62).withOpacity(0.3),
            ),
            child: const Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Menu Interface - Center labeled with data display
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Checkout Button with data (same dimensions as pending payment cards)
              GestureDetector(
                onTap: () {}, // No navigation for checkout
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [glassBlueStart, glassBlueEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top row: ID and Amount (same as pending payments)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: CHK-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'KES ${_formatCurrencyWithCommas(_checkoutSummary['total_sales'] ?? 0.0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Center label (same as pending payment format)
                      const Center(
                        child: Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bottom row: Transactions, Balance, and SUMMARY status in same row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_checkoutSummary['total_transactions'] ?? 0} transactions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            'Bal: KES ${_formatCurrencyWithCommas(_checkoutSummary['total_balance'] ?? 0.0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // SUMMARY status in same row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SUMMARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Sales Button with summary data (same source as PDF generation)
              GestureDetector(
                onTap: () => _viewSalesReport(),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [glassBlueStart, glassBlueEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top row: ID and Amount (same as pending payments)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: SALES-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'KES ${_formatCurrencyWithCommas(_salesSummary['total_sales'] ?? 0.0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Center label (same as pending payment format)
                      const Center(
                        child: Text(
                          'Sales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bottom row: Transactions, Balance, and REPORT status in same row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_salesSummary['total_transactions'] ?? 0} transactions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            'Bal: KES ${_formatCurrencyWithCommas(_salesSummary['balance'] ?? 0.0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // REPORT status in same row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REPORT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Items Button with data (same dimensions as pending payment cards)
              GestureDetector(
                onTap: () => _viewItemsReport(),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [glassBlueStart, glassBlueEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top row: ID and Amount (same as pending payments)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'KES ${_formatCurrencyWithCommas(_itemsSummary['total_value'] ?? 0.0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Center label (same as pending payment format)
                      const Center(
                        child: Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bottom row: Stock info, Restock, and INVENTORY status in same row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_itemsSummary['total_items'] ?? 0} items • Low: ${_itemsSummary['low_stock_count'] ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            'Restock: ${_itemsSummary['restock_needed'] ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // INVENTORY status in same row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INVENTORY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // About Button (no data, plain)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('BluPOS v1.0.0 - Point of Sale System')),
                  );
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [glassBlueStart, glassBlueEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      // Top row: ID and Amount placeholder
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: ABOUT-INFO',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'SYSTEM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      // Center label
                      Center(
                        child: Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                      // Bottom row: BluPOS Information
                      Center(
                        child: Text(
                          'BluPOS Information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16), // Bottom spacing
      ],
    );
  }

  // Helper method to build clickable menu button
  Widget _buildMenuButton(
    String title,
    String subtitle,
    Color buttonColor,
    VoidCallback onPressed, {
    bool showSummary = false,
    Map<String, dynamic> summaryData = const {},
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF182A62).withOpacity(0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build corner data chip for grid layout
  Widget _buildCornerDataChip(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      constraints: const BoxConstraints(minWidth: 60),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bgColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to build metric display for clockwise layout
  Widget _buildMetricDisplay(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _appState == AppState.active
          ? Colors.green.shade200  // Richer green background for active state
          : null, // Use default theme background for other states
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20), // Conservative spacing from top

              // Yellow Card (positioned near top) - Reduced by 15% from 302px, active/expiry always at bottom
              Container(
                width: double.infinity,
                height: 257, // Reduced by 15%: 302px * 0.85 = 256.7px, rounded to 257px
                padding: const EdgeInsets.all(32.0), // Maintain padding for proper spacing
                decoration: BoxDecoration(
                  color: const Color(0xFFFEC620),
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Row: Device ID (Left), Network Time (Right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Account ID (Top Left)
                        Text(
                          _accountIdDisplay, // Display account ID from server
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        // Network Time (Top Right)
                        Text(
                          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Use flexible space to center the SMS indicator within the increased height
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Swinging SMS Indicator (always visible, swings between SMS count and sales)
                          const Text(
                            'Total Processed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Add spacing between text and SMS indicator
                          const SizedBox(height: 16),

                          // SMS indicator - now properly centered in the available space
                          SmsIndicator(
                            unreadCountStream: _smsService.onUnreadCountChanged,
                            senderType: _currentUnreadCount > 0 ? "Short Code" : "Unknown",
                            totalSales: _totalSales,
                            initialUnreadCount: _currentUnreadCount,
                          ),
                        ],
                      ),
                    ),

                    // Bottom Row: License Status and Expiry - positioned at actual bottom of card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _appState == AppState.firstTime
                              ? 'Not Activated'
                              : _appState == AppState.active
                                  ? 'Active'
                                  : 'Expired',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _appState == AppState.expired
                              ? ''  // Hide expiry date for expired state
                              : _expiryDateDisplay,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16), // Fixed spacing instead of Spacer

              // Action Sections (for active mode) or Activate Button (for first time)
              if (_appState == AppState.active)
                // Active Mode: Animated transition between main view and reports view
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Create slide animation
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: _showReportsView ? const Offset(-1.0, 0) : const Offset(1.0, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: _showReportsView
                    ? _buildReportsView()
                    : _buildMainView(),
                )
              else if (_appState == AppState.firstTime)
                // First Time: Single Activate button
                Container(
                  width: double.infinity,
                  height: 50 * 1.35, // 35% increase from 50px base height
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: _navigateToActivation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF182A62),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Activate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              )
              else if (_appState == AppState.expired)
                // Expired State: Single Reactivate button (green color to indicate renewal)
                Container(
                  width: double.infinity,
                  height: 50 * 1.35, // 35% increase from 50px base height
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: () => _navigateToActivation(isReactivation: true), // Pass reactivation flag
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600, // Green color for renewal
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Reactivate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// PDF Viewer Screen with floating print button
class PDFViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;

  const PDFViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? _localFilePath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPDF();
  }

  Future<void> _downloadAndLoadPDF() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Download PDF from the backend URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      if (response.statusCode == 200) {
        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final fileName = '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');

        // Write PDF data to file
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() {
            _localFilePath = file.path;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to download PDF (HTTP ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading PDF: $e';
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF182A62),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _downloadAndLoadPDF,
            tooltip: 'Reload PDF',
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Content
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey.shade100,
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Downloading and loading PDF...'),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error Loading PDF',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _downloadAndLoadPDF,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _localFilePath != null
                        ? PDFView(
                            filePath: _localFilePath!,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                            pageSnap: true,
                            defaultPage: 0,
                            fitPolicy: FitPolicy.BOTH,
                            preventLinkNavigation: false,
                            onRender: (_pages) {
                              print('PDF rendered with $_pages pages');
                            },
                            onError: (error) {
                              print('PDF view error: $error');
                              setState(() {
                                _error = 'Failed to display PDF: $error';
                              });
                            },
                            onPageError: (page, error) {
                              print('PDF page $page error: $error');
                            },
                            onViewCreated: (PDFViewController pdfViewController) {
                              print('PDF view created');
                            },
                          )
                        : const Center(
                            child: Text('No PDF file available'),
                          ),
          ),


        ],
      ),
    );
  }
}

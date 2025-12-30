import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:intl/intl.dart';
import 'pages/activation_page.dart';
import 'pages/wallet_page.dart';
import 'utils/api_client.dart';
import 'services/micro_server_service.dart';
import 'services/heartbeat_service.dart';
import 'services/network_discovery_service.dart';
import 'services/network_discovery_service.dart' show DiscoveredServer;
import 'services/secure_key_manager.dart';
import 'services/secure_network_discovery_service.dart';
import 'services/secure_network_discovery_service.dart' show SecureServerInfo;

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
    return MaterialApp(
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
  int _checkCounter = 0;
  bool _isSyncing = false;



  // Network discovery service
  final NetworkDiscoveryService _networkDiscovery = NetworkDiscoveryService();
  late StreamSubscription<List<DiscoveredServer>> _discoverySubscription;

  @override
  void initState() {
    super.initState();

    _startNetworkDiscovery();
    _loadAppState();
  }

  @override
  void dispose() {
    _discoverySubscription.cancel();
    _networkDiscovery.stopDiscovery();
    super.dispose();
  }



  // Start network discovery and listen for discovered servers
  void _startNetworkDiscovery() {
    try {
      print('🔍 [MAIN] Starting network discovery integration...');
      _networkDiscovery.startDiscovery();
      
      _discoverySubscription = _networkDiscovery.discoveredServers.listen((servers) {
        print('📡 [MAIN] Discovered ${servers.length} servers: ${servers.map((s) => '${s.serverName} at ${s.url}').join(', ')}');
        
        // Auto-connect to the best server if we have one and no connection failures
        if (servers.isNotEmpty) {
          print('🔄 [MAIN] Attempting auto-connect to discovered servers...');
          _attemptAutoConnect(servers);
        } else {
          print('⚠️ [MAIN] No servers discovered yet, continuing to listen...');
        }
      });
      
      print('✅ [MAIN] Network discovery integration started successfully');
      print('📡 [MAIN] Listening for UDP broadcasts on port 8888');
      print('📡 [MAIN] Multicast group: 239.255.1.1');
    } catch (e) {
      print('❌ [MAIN] Failed to start network discovery: $e');
    }
  }

  // Attempt to auto-connect to discovered servers
  Future<void> _attemptAutoConnect(List<DiscoveredServer> servers) async {
    try {
      print('🔄 [MAIN] Auto-connect triggered with ${servers.length} servers');
      
      // Get the best server (prioritizes BluPOS backend)
      final bestServer = _networkDiscovery.getBestServer();
      if (bestServer == null) {
        print('❌ [MAIN] No best server found');
        return;
      }

      print('🔄 [MAIN] Attempting auto-connect to: $bestServer');
      print('🔄 [MAIN] Server URL: ${bestServer.url}');

      // Test connection to the discovered server
      final isConnected = await _networkDiscovery.testServerConnection(bestServer);
      
      if (isConnected) {
        print('✅ [MAIN] Successfully connected to discovered server: ${bestServer.url}');
        
        // Update the backend URL in preferences
        final prefs = await SharedPreferences.getInstance();
        final newServerIp = '${bestServer.ipAddress}:${bestServer.port}';
        await prefs.setString('server_ip', newServerIp);
        print('✅ [MAIN] Updated server IP in preferences: $newServerIp');
        
        // Update API client with new URL
        await ApiClient.updateBackendUrl(bestServer.url);
        print('✅ [MAIN] Updated API client backend URL: ${bestServer.url}');
        
        // Reset connection failure counter
        await prefs.setInt('connection_failures', 0);
        print('✅ [MAIN] Reset connection failure counter');
        
        
        // Reload app state with new connection
        print('🔄 [MAIN] Reloading app state with new connection...');
        await _loadAppState();
      } else {
        print('❌ [MAIN] Failed to connect to discovered server: ${bestServer.url}');
      }
    } catch (e) {
      print('❌ [MAIN] Auto-connect failed: $e');
    }
  }

  Future<void> _checkForExternalStateChanges() async {
    _checkCounter++;

    final prefs = await SharedPreferences.getInstance();
    final currentActivated = prefs.getBool('isActivated') ?? false;
    final currentExpiry = prefs.getString('licenseExpiry');
    final currentAccountId = prefs.getString('persistentAccountId');

    // Check if state has changed externally
    bool stateChanged = false;
    AppState newState;

    if (!currentActivated && _appState != AppState.firstTime) {
      newState = AppState.firstTime;
      stateChanged = true;
    } else if (currentActivated && currentExpiry != null) {
      final expiryDate = DateTime.tryParse(currentExpiry);
      if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
        newState = AppState.expired;
      } else {
        newState = AppState.active;
      }
      if (newState != _appState) {
        stateChanged = true;
      }
    } else if (currentActivated && _appState != AppState.active) {
      newState = AppState.active;
      stateChanged = true;
    }

    // Also check if expiry date changed (even if state stays the same)
    // This handles cases where license type changes but state remains active
    String currentExpiryDisplay = '--/--/----';
    if (currentExpiry != null) {
      final expiryDate = DateTime.tryParse(currentExpiry);
      if (expiryDate != null) {
        currentExpiryDisplay = '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.year}';
      }
    }

    if (currentExpiryDisplay != _expiryDateDisplay) {
      print('📅 Expiry date changed externally: $_expiryDateDisplay → $currentExpiryDisplay');
      stateChanged = true;
    }

    // Periodically check BluPOS health and sync state (every 20 checks = ~10 seconds)
    if (_checkCounter % 20 == 0) {
      try {
        setState(() => _isSyncing = true);
        final bluposState = await _syncWithBluPOS();
        setState(() => _isSyncing = false);

        if (bluposState != null && bluposState['status'] == 'success') {
          final bluposAppState = bluposState['app_state'];
          final bluposExpiry = bluposState['license_expiry'];
          final bluposAccountId = bluposState['account_id'];

          // Check if BluPOS state differs from current state
          bool bluposStateChanged = false;

          // Update account ID if different
          if (bluposAccountId != null && bluposAccountId != currentAccountId) {
            await prefs.setString('persistentAccountId', bluposAccountId);
            print('🔄 Synced account ID with BluPOS: $bluposAccountId');
            bluposStateChanged = true;
          }

          // Update expiry if different
          if (bluposExpiry != null && bluposExpiry != currentExpiry) {
            await prefs.setString('licenseExpiry', bluposExpiry);
            print('🔄 Synced expiry date with BluPOS: $bluposExpiry');
            bluposStateChanged = true;
          }

          // Update activation state based on BluPOS
          if (bluposAppState == 'active' && !currentActivated) {
            await prefs.setBool('isActivated', true);
            print('🔄 Activated license based on BluPOS state');
            bluposStateChanged = true;
          } else if (bluposAppState == 'expired' && currentActivated) {
            await prefs.setBool('isActivated', false);
            print('🔄 Deactivated license based on BluPOS state');
            bluposStateChanged = true;
          } else if (bluposAppState == 'first_time' && currentActivated) {
            await prefs.setBool('isActivated', false);
            await prefs.remove('licenseExpiry');
            print('🔄 Reset to first-time based on BluPOS state');
            bluposStateChanged = true;
          }

          if (bluposStateChanged) {
            print('🔄 BluPOS state sync completed, reloading UI...');
            await _loadAppState();
            return; // Don't check local state changes since we just reloaded
          }
        }
      } catch (e) {
        print('❌ BluPOS sync failed: $e');
      }
    }

    // If state changed externally, reload the full state
    if (stateChanged) {
      print('🔄 External state change detected, reloading UI...');
      await _loadAppState();
    }
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
    }
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

          // Update UI immediately if we're on the main screen
          if (mounted && !_isLoading) {
            setState(() {
              // Force rebuild of balance display
            });
          }
        } else {
          print('❌ Balance API returned error: ${balanceData['message']}');
        }
      } else {
        print('❌ Balance API failed with status: ${balanceResponse.statusCode}');
      }

      // Fetch real payments from BluPOS using configured backend URL
      final paymentsResponse = await http.get(Uri.parse(paymentsUrl));
      print('💳 Payments response status: ${paymentsResponse.statusCode}');
      print('💳 Payments response body: ${paymentsResponse.body}');

      if (paymentsResponse.statusCode == 200) {
        final paymentsData = jsonDecode(paymentsResponse.body);
        print('💳 Parsed payments data: $paymentsData');

        if (paymentsData['status'] == 'success' && paymentsData['payments'] != null) {
          final prefs = await SharedPreferences.getInstance();
          final paymentsList = paymentsData['payments'] as List<dynamic>;
          await prefs.setString('real_payments', jsonEncode(paymentsList));
          print('💳 Stored ${paymentsList.length} real payments');

          // Update UI immediately if we're on the main screen
          if (mounted && !_isLoading) {
            setState(() {
              // Force rebuild of payments display
            });
          }
        } else {
          print('❌ Payments API returned error: ${paymentsData['message']}');
        }
      } else {
        print('❌ Payments API failed with status: ${paymentsResponse.statusCode}');
      }

      print('✅ Real data fetch completed');
    } catch (e) {
      print('❌ Failed to fetch real balance/payments: $e');
      print('❌ Error details: ${e.toString()}');
    }
  }

  void _updateDisplayValues(bool isActivated, String? licenseExpiry, String? accountId) {
    // Format expiry date for display
    if (licenseExpiry != null) {
      final expiryDate = DateTime.tryParse(licenseExpiry);
      if (expiryDate != null) {
        _expiryDateDisplay = '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.year}';
        print('📅 Synced expiry date: $expiryDate, display: $_expiryDateDisplay');
      } else {
        _expiryDateDisplay = '--/--/----';
        print('❌ Failed to parse synced expiry date: $licenseExpiry');
      }
    } else {
      _expiryDateDisplay = '--/--/----';
    }

    // Format account ID for display
    if (accountId != null && accountId.isNotEmpty) {
      // Extract the numerical part after 'account_' prefix
      final accountParts = accountId.split('_');
      if (accountParts.length > 1) {
        _accountIdDisplay = accountParts.last;
        print('🆔 Synced account ID display: $_accountIdDisplay');
      } else {
        _accountIdDisplay = accountId;
      }
    } else {
      _accountIdDisplay = 'Not Activated';
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
      final prefs = await SharedPreferences.getInstance();
      final realPaymentsJson = prefs.getString('real_payments');
      if (realPaymentsJson != null && realPaymentsJson.isNotEmpty) {
        final payments = jsonDecode(realPaymentsJson) as List<dynamic>;
        return payments.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('❌ Error getting real payments: $e');
    }
    return [];
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

  void _navigateToReports() {
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

  void _viewSalesReport() async {
    final pdfUrl = await _getBackendUrl('/get_sale_record_printout');
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(
            title: 'Sales Report',
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
          builder: (context) => PDFViewerScreen(
            title: 'Items Report',
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
              'Reports',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Recent Payments Section - Real data from BluPOS
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _getRealPayments(),
          builder: (context, snapshot) {
            final payments = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Recent Payments',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                // Payments List
                payments.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'No recent payments',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: payments.take(4).map((payment) {
                          final amount = payment['amount'] ?? '0.00';
                          final datetime = payment['datetime'] ?? '';
                          final salesPerson = payment['sales_person'] ?? 'Unknown';
                          final paymentType = payment['payment_type'] ?? 'Cash';
                          final transactionId = payment['transaction_id'] ?? 'N/A';

                          // Parse datetime and format display
                          final timeDisplay = datetime.isNotEmpty
                              ? DateTime.tryParse(datetime)?.toLocal().toString().split(' ')[1].substring(0, 5) ?? '--:--'
                              : '--:--';

                          final dateDisplay = datetime.isNotEmpty
                              ? DateTime.tryParse(datetime)?.toLocal().toString().split(' ')[0] ?? ''
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
                                  color: Colors.black.withOpacity(0.05),
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
                                        color: Colors.black.withOpacity(0.6),
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
                                          color: Colors.black.withOpacity(0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$dateDisplay $timeDisplay',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ],
            );
          },
        ),

        const SizedBox(height: 16), // Bottom spacing
      ],
    );
  }

  // Build the reports view with Back, Sales, Items, and Share
  Widget _buildReportsView() {
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
              backgroundColor: const Color(0xFF182A62),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

        // Sales and Items Buttons (2x2 grid)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Row 1: Sales Button
              Container(
                width: double.infinity,
                height: 50 * 1.35,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _viewSalesReport(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF182A62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Row 2: Items Button
              Container(
                width: double.infinity,
                height: 50 * 1.35,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _viewItemsReport(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF182A62),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Items',
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

        // Share Button (moved from main view to reports interface)
        Container(
          width: double.infinity,
          height: 50 * 1.35,
          margin: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            onPressed: () {
              // TODO: Device sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share - Device Sharing Coming Soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF182A62),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Share',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16), // Bottom spacing
      ],
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

              // Yellow Card (positioned near top)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEC620),
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                    const SizedBox(height: 16),

                    // Total Processed Amount (Center)
                    const Text(
                      'Total Processed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    FutureBuilder<String>(
                      future: _getRealBalanceDisplay(),
                      builder: (context, snapshot) {
                        final balance = snapshot.data ?? (_appState == AppState.firstTime ? 'KES 0.00' : 'KES 0.00');
                        return Text(
                          balance,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),



                    const SizedBox(height: 16),

                    // Bottom Row: License Status and Expiry (hide expiry for expired state)
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

  Future<void> _printPDF() async {
    if (_localFilePath == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🖨️ Preparing PDF for printing...')),
      );

      // Use printing package to print the PDF
      final file = File(_localFilePath!);
      final bytes = await file.readAsBytes();

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ PDF sent to printer')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Print failed: $e')),
      );
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

          // Floating Print Button
          if (!_isLoading && _error == null && _localFilePath != null)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                onPressed: _printPDF,
                backgroundColor: const Color(0xFF182A62),
                foregroundColor: Colors.white,
                child: const Icon(Icons.print),
                tooltip: 'Print PDF',
              ),
            ),
        ],
      ),
    );
  }
}

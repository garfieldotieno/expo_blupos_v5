import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/activation_page.dart';
import 'pages/reports_page.dart';
import 'pages/wallet_page.dart';
import 'services/micro_server_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start micro-server
  try {
    await MicroServerService.startServer();
  } catch (e) {
    print('⚠️  Failed to start micro-server: $e');
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

class _HomePageState extends State<HomePage> {
  AppState _appState = AppState.firstTime;
  bool _isLoading = true;
  String _expiryDateDisplay = '--/--/----';

  @override
  void initState() {
    super.initState();
    _loadAppState();
    // Check for external state changes every 2 seconds
    _startPeriodicStateCheck();
  }

  @override
  void dispose() {
    _stopPeriodicStateCheck();
    super.dispose();
  }

  void _startPeriodicStateCheck() {
    // Check for state changes every 500ms for instant reactivity
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkForExternalStateChanges();
        _startPeriodicStateCheck(); // Continue the cycle
      }
    });
  }

  void _stopPeriodicStateCheck() {
    // Timer will stop when widget is disposed
  }

  Future<void> _checkForExternalStateChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final currentActivated = prefs.getBool('isActivated') ?? false;
    final currentExpiry = prefs.getString('licenseExpiry');

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

    // If state changed externally, reload the full state
    if (stateChanged) {
      print('🔄 External state change detected, reloading UI...');
      await _loadAppState();
    }
  }

  Future<void> _loadAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActivated = prefs.getBool('isActivated') ?? false;
    final licenseExpiry = prefs.getString('licenseExpiry');

    print('🔍 Loading app state - isActivated: $isActivated, expiry: $licenseExpiry');

    // Format expiry date for display
    if (licenseExpiry != null) {
      final expiryDate = DateTime.tryParse(licenseExpiry);
      if (expiryDate != null) {
        _expiryDateDisplay = '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.year}';
        print('📅 Parsed expiry date: $expiryDate, display: $_expiryDateDisplay');
      } else {
        _expiryDateDisplay = '--/--/----';
        print('❌ Failed to parse expiry date: $licenseExpiry');
      }
    } else {
      _expiryDateDisplay = '--/--/----';
    }

    setState(() {
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
      _isLoading = false;
    });
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ReportsPage(),
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
                    // Top Row: Device ID (Left) and Network Time (Right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Device ID (Top Left)
                        Text(
                          MicroServerService.currentDeviceId.split('_').last, // Extract numerical part
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
                    Text(
                      _appState == AppState.firstTime
                          ? 'KES 0.00'
                          : 'KES 12,345.67',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

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
                // Active Mode: Reports (alone) → Sample Payments → [Activate, Share] group
                Column(
                  children: [
                    // Reports Section - Single Button
                    Container(
                      width: double.infinity,
                      height: 50 * 1.35,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton(
                        onPressed: () => _navigateToReports(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF182A62),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

                    // Recent Payments Section - Scrollable container for payments
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300), // Max height to prevent overflow
                      margin: const EdgeInsets.only(bottom: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Sample Payment 1
                            Container(
                              width: double.infinity,
                              height: 50 * 1.35, // Same height as buttons
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '10:30 AM',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  Text(
                                    'KES 2,500.00',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Sample Payment 2
                            Container(
                              width: double.infinity,
                              height: 50 * 1.35, // Same height as buttons
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '11:45 AM',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  Text(
                                    'KES 1,200.00',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Sample Payment 3
                            Container(
                              width: double.infinity,
                              height: 50 * 1.35, // Same height as buttons
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '2:15 PM',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  Text(
                                    'KES 3,400.00',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Sample Payment 4
                            Container(
                              width: double.infinity,
                              height: 50 * 1.35, // Same height as buttons
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '4:30 PM',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  Text(
                                    'KES 850.00',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Management Actions - Share button only
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

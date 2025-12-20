import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _balance = 0.0;
  bool _isRefreshing = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String? _deviceUid;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    // For demo purposes, use a placeholder device UID
    // In real implementation, this would be retrieved from secure storage after activation
    _deviceUid = 'DEMO_DEVICE_UID_${DateTime.now().millisecondsSinceEpoch}';

    await _loadBalance();
    await _loadTransactions();
  }

  Future<void> _loadBalance() async {
    if (_deviceUid == null) return;

    try {
      final result = await WalletService.getBalance(_deviceUid!);
      if (result['success']) {
        setState(() {
          _balance = result['balance'];
          _isLoading = false;
        });
      } else {
        // Fallback to demo balance if API fails
        setState(() {
          _balance = 54750.25;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to demo balance
      setState(() {
        _balance = 54750.25;
        _isLoading = false;
      });
      print('Error loading balance: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_deviceUid == null) return;

    try {
      final result = await WalletService.getTransactions(
        deviceUid: _deviceUid!,
        page: 1,
        limit: 10,
      );

      if (result['success']) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(result['transactions']);
        });
      } else {
        // Fallback to demo transactions if API fails
        _loadDemoTransactions();
      }
    } catch (e) {
      // Fallback to demo transactions
      _loadDemoTransactions();
      print('Error loading transactions: $e');
    }
  }

  void _loadDemoTransactions() {
    _transactions = [
      {
        'id': 'TXN001',
        'type': 'credit',
        'amount': 2500.00,
        'description': 'Payment received - M-Pesa',
        'date': '2025-01-15 14:30',
        'status': 'completed'
      },
      {
        'id': 'TXN002',
        'type': 'debit',
        'amount': -150.75,
        'description': 'ATM Withdrawal',
        'date': '2025-01-15 10:15',
        'status': 'completed'
      },
      {
        'id': 'TXN003',
        'type': 'credit',
        'amount': 890.50,
        'description': 'Transfer from Account',
        'date': '2025-01-14 16:45',
        'status': 'completed'
      },
      {
        'id': 'TXN004',
        'type': 'debit',
        'amount': -75.25,
        'description': 'POS Purchase - Supermarket',
        'date': '2025-01-14 12:20',
        'status': 'completed'
      },
      {
        'id': 'TXN005',
        'type': 'credit',
        'amount': 1200.00,
        'description': 'Salary deposit',
        'date': '2025-01-13 09:00',
        'status': 'completed'
      },
    ];
  }

  Future<void> _refreshBalance() async {
    setState(() {
      _isRefreshing = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Mock balance update
    setState(() {
      _balance += 100.50; // Simulate small balance change
      _isRefreshing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Balance refreshed')),
    );
  }

  Future<void> _loadMoreTransactions() async {
    // Load additional transactions from API or demo data
    if (_deviceUid != null) {
      try {
        final result = await WalletService.getTransactions(
          deviceUid: _deviceUid!,
          page: (_transactions.length ~/ 10) + 1,
          limit: 10,
        );

        if (result['success']) {
          setState(() {
            _transactions.addAll(List<Map<String, dynamic>>.from(result['transactions']));
          });
        } else {
          // Fallback to demo additional transactions
          _loadDemoAdditionalTransactions();
        }
      } catch (e) {
        // Fallback to demo additional transactions
        _loadDemoAdditionalTransactions();
      }
    } else {
      _loadDemoAdditionalTransactions();
    }
  }

  void _loadDemoAdditionalTransactions() {
    setState(() {
      _transactions.addAll([
        {
          'id': 'TXN${_transactions.length + 1}',
          'type': 'debit',
          'amount': -25.00,
          'description': 'Coffee purchase',
          'date': '2025-01-12 08:30',
          'status': 'completed'
        },
        {
          'id': 'TXN${_transactions.length + 2}',
          'type': 'credit',
          'amount': 500.00,
          'description': 'Refund - Online purchase',
          'date': '2025-01-11 15:20',
          'status': 'completed'
        },
      ]);
    });
  }

  void _onTransactionTapped(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Transaction Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${transaction['id']}'),
              Text('Description: ${transaction['description']}'),
              Text('Amount: KES ${transaction['amount'].abs().toStringAsFixed(2)}'),
              Text('Date: ${transaction['date']}'),
              Text('Status: ${transaction['status']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isRefreshing ? Colors.grey : const Color(0xFF182A62),
            ),
            onPressed: _isRefreshing ? null : _refreshBalance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Credit Card Style Balance Display
          Container(
            margin: const EdgeInsets.all(16),
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFFEC620), // Yellow background
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BluPOS Wallet',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.black.withOpacity(0.7),
                        size: 24,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES ${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '**** **** **** 1234',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text(
                            'VISA',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Transaction History
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: _loadMoreTransactions,
                        child: const Text(
                          'Load More',
                          style: TextStyle(color: Color(0xFF182A62)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      final isCredit = transaction['type'] == 'credit';
                      final amount = transaction['amount'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCredit
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isCredit ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            transaction['description'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            transaction['date'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Text(
                            '${isCredit ? '+' : ''}KES ${amount.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isCredit ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => _onTransactionTapped(transaction),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

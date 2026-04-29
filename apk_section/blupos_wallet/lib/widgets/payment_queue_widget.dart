import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sms_reconciliation_service.dart';

/// Payment Queue Widget for APK Interface
/// Displays queued SMS payments for clerk selection and reconciliation
class PaymentQueueWidget extends StatelessWidget {
  const PaymentQueueWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final smsService = Provider.of<SMSReconciliationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Queue'),
        backgroundColor: Colors.blue[800],
        actions: [
          Switch(
            value: smsService.isAutoModeEnabled,
            onChanged: (bool value) {
              if (value) {
                smsService.enableAutoMode();
              } else {
                smsService.disableAutoMode();
              }
            },
            activeColor: Colors.white,
            inactiveThumbColor: Colors.grey[400],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                'Auto Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _buildPaymentQueueBody(context, smsService),
    );
  }

  Widget _buildPaymentQueueBody(BuildContext context, SMSReconciliationService smsService) {
    if (smsService.paymentQueue.isEmpty) {
      return _buildEmptyQueueView(context, smsService);
    }

    return Column(
      children: [
        _buildQueueHeader(smsService),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: smsService.paymentQueue.length,
            itemBuilder: (context, index) {
              final payment = smsService.paymentQueue[index];
              return _buildPaymentCard(context, payment, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyQueueView(BuildContext context, SMSReconciliationService smsService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          const Text(
            'No Payments in Queue',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Waiting for SMS payment notifications...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Refresh queue
              smsService.getPaymentQueue();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Refresh Queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader(SMSReconciliationService smsService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Queue: ${smsService.paymentQueue.length} Payment(s)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Row(
            children: [
              Icon(
                smsService.isListening ? Icons.circle : Icons.circle_outlined,
                color: smsService.isListening ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                smsService.isListening ? 'Listening' : 'Not Listening',
                style: TextStyle(
                  fontSize: 14,
                  color: smsService.isListening ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Map<String, dynamic> payment, int index) {
    final paymentData = payment['payment_data'] ?? {};
    final pendingCheckout = payment['pending_checkout'] ?? {};
    
    final amount = paymentData['amount'] ?? 0.0;
    final sender = paymentData['sender'] ?? 'Unknown';
    final account = paymentData['account'] ?? 'Unknown';
    final datetime = paymentData['datetime'] ?? 'Unknown';
    final remainingBalance = pendingCheckout['remaining_balance'] ?? 0.0;
    final balanceAfterPayment = pendingCheckout['balance_after_payment'] ?? 0.0;

    // Determine payment status and colors
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (balanceAfterPayment < 0) {
      statusColor = Colors.green;
      statusText = 'Overpayment';
      statusIcon = Icons.arrow_upward;
    } else if (balanceAfterPayment > 0) {
      statusColor = Colors.orange;
      statusText = 'Partial Payment';
      statusIcon = Icons.arrow_right;
    } else {
      statusColor = Colors.blue;
      statusText = 'Exact Match';
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () {
          _showPaymentDetailsDialog(context, payment);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.blue[800]),
                      const SizedBox(width: 8),
                      Text(
                        'KES ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Queue #${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),

              // Payment Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From: $sender',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Account: $account',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Time: $datetime',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Balance Information
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Current Balance:',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'KES ${remainingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'After Payment:',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'KES ${balanceAfterPayment.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: balanceAfterPayment < 0 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _showPaymentDetailsDialog(context, payment);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Select Payment'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      _confirmPayment(context, payment['id'], false);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetailsDialog(BuildContext context, Map<String, dynamic> payment) {
    final paymentData = payment['payment_data'] ?? {};
    final pendingCheckout = payment['pending_checkout'] ?? {};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Amount', 'KES ${paymentData['amount']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailRow('Sender', paymentData['sender'] ?? 'Unknown'),
                _buildDetailRow('Account', paymentData['account'] ?? 'Unknown'),
                _buildDetailRow('Reference', paymentData['reference'] ?? 'N/A'),
                _buildDetailRow('Date/Time', paymentData['datetime'] ?? 'Unknown'),
                const Divider(),
                _buildDetailRow('Current Balance', 'KES ${pendingCheckout['remaining_balance']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailRow('Payment Amount', 'KES ${paymentData['amount']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailRow(
                  'New Balance',
                  pendingCheckout['balance_after_payment'] != null
                    ? (pendingCheckout['balance_after_payment'] < 0 
                        ? 'KES ${pendingCheckout['balance_after_payment'].abs().toStringAsFixed(2)} (Overpayment)' 
                        : 'KES ${pendingCheckout['balance_after_payment'].toStringAsFixed(2)}')
                    : 'Unknown'
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmPayment(context, payment['id'], true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Confirm Match'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment(BuildContext context, String paymentId, bool clerkConfirmation) {
    final smsService = Provider.of<SMSReconciliationService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: clerkConfirmation
            ? const Text('Are you sure this payment matches the current checkout?')
            : const Text('Are you sure you want to reject this payment?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final result = await smsService.confirmPayment(paymentId, clerkConfirmation);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Payment processed'),
                    backgroundColor: result['status'] == 'success' ? Colors.green : Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: clerkConfirmation ? Colors.green : Colors.red,
              ),
              child: Text(clerkConfirmation ? 'Confirm' : 'Reject'),
            ),
          ],
        );
      },
    );
  }
}

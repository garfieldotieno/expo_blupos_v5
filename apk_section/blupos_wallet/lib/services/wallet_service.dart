import '../utils/api_client.dart';

class WalletService {
  // Get wallet balance
  static Future<Map<String, dynamic>> getBalance(String deviceUid) async {
    try {
      final response = await ApiClient.get('/api/wallet/balance?device_uid=$deviceUid');
      return {
        'success': true,
        'balance': response['balance'] ?? 0.0,
        'currency': response['currency'] ?? 'KES',
        'last_updated': response['last_updated'],
        'message': 'Balance retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'balance': 0.0,
        'message': 'Failed to retrieve balance',
      };
    }
  }

  // Get transaction history
  static Future<Map<String, dynamic>> getTransactions({
    required String deviceUid,
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
    String? transactionType,
  }) async {
    try {
      final queryParams = <String, String>{
        'device_uid': deviceUid,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (transactionType != null) queryParams['type'] = transactionType;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      final response = await ApiClient.get('/api/wallet/transactions?$queryString');

      return {
        'success': true,
        'transactions': response['transactions'] ?? [],
        'total_count': response['total_count'] ?? 0,
        'current_page': response['current_page'] ?? page,
        'total_pages': response['total_pages'] ?? 1,
        'message': 'Transactions retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'transactions': [],
        'message': 'Failed to retrieve transactions',
      };
    }
  }

  // Add manual transaction
  static Future<Map<String, dynamic>> addManualTransaction({
    required String deviceUid,
    required String transactionType, // 'credit' or 'debit'
    required double amount,
    required String description,
    String? reference,
    String? category,
  }) async {
    final transactionData = {
      'device_uid': deviceUid,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'reference': reference,
      'category': category,
      'source': 'manual_entry',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiClient.post('/api/wallet/transaction', transactionData);
      return {
        'success': true,
        'transaction_id': response['transaction_id'],
        'balance_after': response['balance_after'],
        'message': 'Transaction added successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to add transaction',
      };
    }
  }

  // Sync SMS transactions
  static Future<Map<String, dynamic>> syncSmsTransactions({
    required String deviceUid,
    required List<Map<String, dynamic>> smsTransactions,
  }) async {
    final syncData = {
      'device_uid': deviceUid,
      'sms_transactions': smsTransactions,
      'sync_timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiClient.post('/api/apk/sync', syncData);
      return {
        'success': true,
        'synced_count': response['synced_count'] ?? 0,
        'failed_count': response['failed_count'] ?? 0,
        'balance_updated': response['balance_updated'] ?? false,
        'message': 'SMS transactions synced successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to sync SMS transactions',
      };
    }
  }

  // Get transaction summary
  static Future<Map<String, dynamic>> getTransactionSummary({
    required String deviceUid,
    String period = 'month', // 'week', 'month', 'year'
  }) async {
    try {
      final response = await ApiClient.get('/api/wallet/summary?device_uid=$deviceUid&period=$period');
      return {
        'success': true,
        'total_credits': response['total_credits'] ?? 0.0,
        'total_debits': response['total_debits'] ?? 0.0,
        'net_flow': response['net_flow'] ?? 0.0,
        'transaction_count': response['transaction_count'] ?? 0,
        'period': period,
        'message': 'Summary retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve summary',
      };
    }
  }

  // Delete transaction (if allowed)
  static Future<Map<String, dynamic>> deleteTransaction({
    required String deviceUid,
    required String transactionId,
  }) async {
    try {
      final response = await ApiClient.delete('/api/wallet/transaction/$transactionId?device_uid=$deviceUid');
      return {
        'success': true,
        'message': 'Transaction deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete transaction',
      };
    }
  }

  // Update transaction details
  static Future<Map<String, dynamic>> updateTransaction({
    required String deviceUid,
    required String transactionId,
    String? description,
    String? category,
    String? reference,
  }) async {
    final updateData = <String, dynamic>{
      'device_uid': deviceUid,
    };

    if (description != null) updateData['description'] = description;
    if (category != null) updateData['category'] = category;
    if (reference != null) updateData['reference'] = reference;

    try {
      final response = await ApiClient.put('/api/wallet/transaction/$transactionId', updateData);
      return {
        'success': true,
        'message': 'Transaction updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update transaction',
      };
    }
  }

  // Get wallet statistics
  static Future<Map<String, dynamic>> getWalletStats(String deviceUid) async {
    try {
      final response = await ApiClient.get('/api/wallet/stats?device_uid=$deviceUid');
      return {
        'success': true,
        'stats': response['stats'] ?? {},
        'message': 'Wallet statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve wallet statistics',
      };
    }
  }

  // Export wallet data
  static Future<Map<String, dynamic>> exportWalletData({
    required String deviceUid,
    String format = 'json', // 'json', 'csv', 'pdf'
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'device_uid': deviceUid,
        'format': format,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      final response = await ApiClient.get('/api/wallet/export?$queryString');

      return {
        'success': true,
        'download_url': response['download_url'],
        'file_name': response['file_name'],
        'message': 'Export initiated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to export wallet data',
      };
    }
  }
}

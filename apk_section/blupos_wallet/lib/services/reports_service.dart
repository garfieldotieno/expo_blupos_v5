import '../utils/api_client.dart';

class ReportsService {
  // Get transaction reports
  static Future<Map<String, dynamic>> getReports({
    required String deviceUid,
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
    String? reportType, // 'transactions', 'balance', 'sms_history'
  }) async {
    try {
      final queryParams = <String, String>{
        'device_uid': deviceUid,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (reportType != null) queryParams['type'] = reportType;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      final response = await ApiClient.get('/api/reports?$queryString');

      return {
        'success': true,
        'reports': response['reports'] ?? [],
        'total_count': response['total_count'] ?? 0,
        'current_page': response['current_page'] ?? page,
        'total_pages': response['total_pages'] ?? 1,
        'summary': response['summary'] ?? {},
        'message': 'Reports retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'reports': [],
        'message': 'Failed to retrieve reports',
      };
    }
  }

  // Generate transaction report
  static Future<Map<String, dynamic>> generateTransactionReport({
    required String deviceUid,
    required String startDate,
    required String endDate,
    String? transactionType,
    bool includeSms = false,
  }) async {
    final reportData = {
      'device_uid': deviceUid,
      'report_type': 'transactions',
      'start_date': startDate,
      'end_date': endDate,
      'transaction_type': transactionType,
      'include_sms': includeSms,
      'generated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiClient.post('/api/reports/generate', reportData);
      return {
        'success': true,
        'report_id': response['report_id'],
        'total_transactions': response['total_transactions'] ?? 0,
        'total_amount': response['total_amount'] ?? 0.0,
        'date_range': response['date_range'],
        'message': 'Transaction report generated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to generate transaction report',
      };
    }
  }

  // Get balance report
  static Future<Map<String, dynamic>> getBalanceReport({
    required String deviceUid,
    String period = 'month', // 'week', 'month', 'quarter', 'year'
  }) async {
    try {
      final response = await ApiClient.get('/api/reports/balance?device_uid=$deviceUid&period=$period');
      return {
        'success': true,
        'balance_history': response['balance_history'] ?? [],
        'opening_balance': response['opening_balance'] ?? 0.0,
        'closing_balance': response['closing_balance'] ?? 0.0,
        'net_change': response['net_change'] ?? 0.0,
        'period': period,
        'message': 'Balance report retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve balance report',
      };
    }
  }

  // Get SMS parsing report
  static Future<Map<String, dynamic>> getSmsReport({
    required String deviceUid,
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'device_uid': deviceUid,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      final response = await ApiClient.get('/api/sms/transactions?$queryString');

      return {
        'success': true,
        'sms_transactions': response['sms_transactions'] ?? [],
        'total_count': response['total_count'] ?? 0,
        'parsed_count': response['parsed_count'] ?? 0,
        'unparsed_count': response['unparsed_count'] ?? 0,
        'current_page': response['current_page'] ?? page,
        'total_pages': response['total_pages'] ?? 1,
        'message': 'SMS report retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve SMS report',
      };
    }
  }

  // Export report
  static Future<Map<String, dynamic>> exportReport({
    required String deviceUid,
    required String reportId,
    String format = 'pdf', // 'pdf', 'csv', 'json'
    String? startDate,
    String? endDate,
  }) async {
    final exportData = {
      'device_uid': deviceUid,
      'report_id': reportId,
      'format': format,
      'start_date': startDate,
      'end_date': endDate,
    };

    try {
      final response = await ApiClient.post('/api/reports/export', exportData);
      return {
        'success': true,
        'download_url': response['download_url'],
        'file_name': response['file_name'],
        'file_size': response['file_size'],
        'expires_at': response['expires_at'],
        'message': 'Report export initiated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to export report',
      };
    }
  }

  // Get report statistics
  static Future<Map<String, dynamic>> getReportStats({
    required String deviceUid,
    String period = 'month',
  }) async {
    try {
      final response = await ApiClient.get('/api/reports/stats?device_uid=$deviceUid&period=$period');
      return {
        'success': true,
        'stats': response['stats'] ?? {},
        'period': period,
        'message': 'Report statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve report statistics',
      };
    }
  }

  // Delete report
  static Future<Map<String, dynamic>> deleteReport({
    required String deviceUid,
    required String reportId,
  }) async {
    try {
      final response = await ApiClient.delete('/api/reports/$reportId?device_uid=$deviceUid');
      return {
        'success': true,
        'message': 'Report deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete report',
      };
    }
  }

  // Get saved reports list
  static Future<Map<String, dynamic>> getSavedReports({
    required String deviceUid,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await ApiClient.get('/api/reports/saved?device_uid=$deviceUid&page=$page&limit=$limit');
      return {
        'success': true,
        'reports': response['reports'] ?? [],
        'total_count': response['total_count'] ?? 0,
        'current_page': response['current_page'] ?? page,
        'total_pages': response['total_pages'] ?? 1,
        'message': 'Saved reports retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve saved reports',
      };
    }
  }

  // Schedule automatic report generation
  static Future<Map<String, dynamic>> scheduleReport({
    required String deviceUid,
    required String reportType,
    required String frequency, // 'daily', 'weekly', 'monthly'
    String? email,
    Map<String, dynamic>? filters,
  }) async {
    final scheduleData = {
      'device_uid': deviceUid,
      'report_type': reportType,
      'frequency': frequency,
      'email': email,
      'filters': filters,
      'enabled': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await ApiClient.post('/api/reports/schedule', scheduleData);
      return {
        'success': true,
        'schedule_id': response['schedule_id'],
        'next_run': response['next_run'],
        'message': 'Report schedule created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to schedule report',
      };
    }
  }

  // Get scheduled reports
  static Future<Map<String, dynamic>> getScheduledReports(String deviceUid) async {
    try {
      final response = await ApiClient.get('/api/reports/schedules?device_uid=$deviceUid');
      return {
        'success': true,
        'schedules': response['schedules'] ?? [],
        'message': 'Scheduled reports retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve scheduled reports',
      };
    }
  }
}

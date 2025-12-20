import 'package:flutter/material.dart';
import '../services/reports_service.dart';
import '../services/activation_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isGenerating = false;
  String _reportStatus = 'Ready to generate reports';
  List<Map<String, dynamic>> _reports = [];
  String? _deviceUid;

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
  }

  Future<void> _loadDeviceStatus() async {
    // For demo purposes, we'll use a placeholder device UID
    // In real implementation, this would be stored securely after activation
    _deviceUid = 'DEMO_DEVICE_UID_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _onGenerateReportPressed() async {
    if (_deviceUid == null) {
      setState(() {
        _reportStatus = 'Device not activated. Please activate first.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _reportStatus = 'Generating reports...';
    });

    try {
      // Generate date range (last 7 days)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final result = await ReportsService.generateTransactionReport(
        deviceUid: _deviceUid!,
        startDate: startDate.toIso8601String().split('T')[0],
        endDate: endDate.toIso8601String().split('T')[0],
        includeSms: true,
      );

      if (result['success']) {
        // Fetch the generated reports
        await _loadReports();

        setState(() {
          _isGenerating = false;
          _reportStatus = 'Report generated successfully! Found ${result['total_transactions']} transactions totaling KES ${result['total_amount'].toStringAsFixed(2)}';
        });
      } else {
        setState(() {
          _isGenerating = false;
          _reportStatus = 'Report generation failed: ${result['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _reportStatus = 'Error generating report: ${e.toString()}';
      });
    }
  }

  Future<void> _loadReports() async {
    if (_deviceUid == null) return;

    try {
      final result = await ReportsService.getReports(
        deviceUid: _deviceUid!,
        page: 1,
        limit: 10,
      );

      if (result['success']) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(result['reports']);
        });
      }
    } catch (e) {
      // Handle error silently for now
      print('Error loading reports: $e');
    }
  }

  Future<void> _exportReport() async {
    // TODO: Implement PDF/CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon!')),
    );
  }

  void _filterReports() {
    // TODO: Implement date/status filtering
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filter functionality coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF182A62)),
            onPressed: _filterReports,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF182A62)),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 280,
                height: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.analytics,
                      size: 48,
                      color: Color(0xFF182A62),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transaction Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _reports.isEmpty
                          ? 'Generate reports to view transaction analytics'
                          : '${_reports.length} reports available',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _reportStatus,
                      style: TextStyle(
                        color: _isGenerating ? Colors.orange : Colors.black54,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 280,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _onGenerateReportPressed,
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Generate Report'),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_reports.isNotEmpty) ...[
              const Text(
                'Recent Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('Date: ${report['date']}'),
                        subtitle: Text(
                          '${report['transactions']} transactions • KES ${report['total'].toStringAsFixed(2)}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report['status'],
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          // TODO: Show detailed report view
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Detailed view for ${report['date']}'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

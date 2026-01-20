import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printer_service.dart';

/// Sales data model for the horizontal card
class SaleData {
  final String id;
  final String clerk;
  final double total;
  final DateTime timestamp;
  final List<SaleItem> items;

  const SaleData({
    required this.id,
    required this.clerk,
    required this.total,
    required this.timestamp,
    this.items = const [],
  });
}

/// Individual sale item
class SaleItem {
  final String name;
  final int quantity;
  final double price;

  const SaleItem({
    required this.name,
    required this.quantity,
    required this.price,
  });
}

/// Horizontal card widget for displaying sales with print functionality
class SalesHorizontalCard extends StatelessWidget {
  final SaleData saleData;
  final PrinterService printerService;

  const SalesHorizontalCard({
    Key? key,
    required this.saleData,
    required this.printerService,
  }) : super(key: key);

  void _printReceipt(BuildContext context) async {
    try {
      // Self-Contained Device Management workflow
      final devices = await printerService.discoverDevices();

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No printers found'))
        );
        return;
      }

      final selectedDevice = devices.first; // Auto-select first available
      final connected = await printerService.pairAndConnectToDevice(selectedDevice);

      if (connected) {
        // Convert sale data to map for printing
        final saleMap = {
          'id': saleData.id,
          'total': saleData.total,
          'items': saleData.items.map((item) => {
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
          }).toList(),
        };

        await printerService.printThermalReceipt(saleMap);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt printed for Sale #${saleData.id}!'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to printer'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: ${e.toString()}'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          // Could navigate to sale details
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Printer icon to the left of sales data
              IconButton(
                icon: Icon(
                  Icons.print,
                  color: printerService.isConnected ? Colors.blue : Colors.grey,
                ),
                tooltip: printerService.isConnected
                  ? 'Print Receipt'
                  : 'Printer Not Connected',
                onPressed: printerService.isConnected
                  ? () => _printReceipt(context)
                  : null,
              ),
              const SizedBox(width: 12),

              // Sales information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale #${saleData.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: KES ${saleData.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Clerk: ${saleData.clerk}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${saleData.timestamp.day}/${saleData.timestamp.month}/${saleData.timestamp.year} ${saleData.timestamp.hour}:${saleData.timestamp.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Items count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${saleData.items.length} items',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

/// Alternative implementation using Provider for automatic service injection
class SalesHorizontalCardWithProvider extends StatelessWidget {
  final SaleData saleData;

  const SalesHorizontalCardWithProvider({
    Key? key,
    required this.saleData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterService>(
      builder: (context, printerService, child) {
        return SalesHorizontalCard(
          saleData: saleData,
          printerService: printerService,
        );
      },
    );
  }
}

/// List view widget that displays multiple sales with print functionality
class SalesListView extends StatelessWidget {
  final List<SaleData> sales;

  const SalesListView({
    Key? key,
    required this.sales,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        return SalesHorizontalCardWithProvider(
          saleData: sales[index],
        );
      },
    );
  }
}

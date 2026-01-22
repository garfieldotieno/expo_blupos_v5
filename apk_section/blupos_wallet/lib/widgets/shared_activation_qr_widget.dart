import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SharedActivationQRWidget extends StatelessWidget {
  final String qrCodeData;
  final String title;
  final String amount;
  final String description;
  final bool isReactivation;
  final VoidCallback onScanPressed;

  const SharedActivationQRWidget({
    super.key,
    required this.qrCodeData,
    required this.title,
    required this.amount,
    required this.description,
    required this.isReactivation,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF182A62),
            ),
          ),
          const SizedBox(height: 8),

          // Amount
          if (amount.isNotEmpty && amount != '0')
            Text(
              'Amount: KES $amount',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (amount.isNotEmpty && amount != '0')
            const SizedBox(height: 16),

          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: qrCodeData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onScanPressed,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(isReactivation ? 'Scan Payment Code' : 'Scan Activation Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF182A62),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Warning for re-activation
          if (isReactivation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Only full payment amounts accepted - no partial payments',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

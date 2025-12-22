import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade400, // Even lighter pink background (another 20% reduction)
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20), // Conservative spacing from top (matches activation page)

              // Back Button (pushed up, matches activation page button style)
              Container(
                width: double.infinity,
                height: 50 * 1.35, // 35% increase from 50px base height (matches activation page)
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
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
              const SizedBox(height: 32),

              // Middle Group: [Checkout, Item Listing, Item Analysis] - Three buttons
              Column(
                children: [
                  // Checkout Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to checkout reports
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Checkout Reports - Coming Soon!')),
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
                        'Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Item Listing Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to item listing reports
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Item Listing Reports - Coming Soon!')),
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
                        'Item Listing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Item Analysis Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35,
                    margin: const EdgeInsets.only(bottom: 32), // Extra spacing before bottom group
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to item analysis reports
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Item Analysis Reports - Coming Soon!')),
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
                        'Item Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(), // Pushes bottom button to bottom

              // Bottom Group: Print Button
              Container(
                width: double.infinity,
                height: 50 * 1.35,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Print reports functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Print Reports - Coming Soon!')),
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
                    'Print',
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

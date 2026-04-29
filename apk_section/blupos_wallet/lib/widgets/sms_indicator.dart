import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class SmsIndicator extends StatefulWidget {
  final Stream<int> unreadCountStream;
  final String senderType;
  final double totalSales;
  final int initialUnreadCount;

  const SmsIndicator({
    super.key,
    required this.unreadCountStream,
    required this.senderType,
    required this.totalSales,
    required this.initialUnreadCount,
  });

  @override
  State<SmsIndicator> createState() => _SmsIndicatorState();
}

class _SmsIndicatorState extends State<SmsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _switchTimer;
  late StreamSubscription<int> _countSubscription;
  late int _currentSmsCount;
  bool _showSmsCount = true; // Start with SMS count

  @override
  void initState() {
    super.initState();

    _currentSmsCount = widget.initialUnreadCount;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start the gentle swinging animation immediately
    print('🎬 [SMS-INDICATOR] Starting animation immediately on render');
    _startSwingingAnimation();

    // Listen to unread count changes
    print('📡 [SMS-INDICATOR] Subscribing to unread count stream...');
    _countSubscription = widget.unreadCountStream.listen((count) {
      print('📊 [SMS-INDICATOR] Received unread count update: $count messages');
      if (mounted) {
        setState(() {
          _currentSmsCount = count;
          // Animation controller always runs for swinging effect
          // Scaling animation only applies when there are unread messages
        });
      }
    });
    print('✅ [SMS-INDICATOR] Successfully subscribed to unread count stream');
  }

  @override
  void didUpdateWidget(SmsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCountStream != oldWidget.unreadCountStream) {
      print('🔄 [SMS-INDICATOR] Stream changed, resubscribing...');
      _countSubscription.cancel();
      _countSubscription = widget.unreadCountStream.listen((count) {
        print('📊 [SMS-INDICATOR] Received unread count update on new stream: $count messages');
        if (mounted) {
          setState(() {
            _currentSmsCount = count;
            // Animation controller always runs for swinging effect
            // Scaling animation only applies when there are unread messages
          });
        }
      });
      print('✅ [SMS-INDICATOR] Successfully resubscribed to new stream');
    }
  }

  void _startSwingingAnimation() {
    _switchTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _showSmsCount = !_showSmsCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _countSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Color _getIndicatorColor(String senderType) {
    if (_showSmsCount && _currentSmsCount > 0) {
      // Color based on sender type when showing SMS count
      switch (senderType) {
        case "SMS Sender ID":
          return Colors.red.shade600; // Red for potential scam
        case "Short Code":
          return Colors.blue.shade600; // Blue for legitimate short codes
        case "Saved Contact":
          return Colors.green.shade600; // Green for trusted
        case "Not Saved Contact":
          return Colors.orange.shade600; // Orange for unknown
        default:
          return Colors.blue.shade600; // Blue for default
      }
    } else {
      // Green for sales amount
      return Colors.green.shade600;
    }
  }

  IconData _getIndicatorIcon() {
    if (_showSmsCount) {
      // Always use SMS icon when showing SMS count
      return Icons.sms;
    } else {
      // Money icon for sales amount (without dollar sign)
      return Icons.account_balance_wallet;
    }
  }

  String _getDisplayText() {
    if (_showSmsCount) {
      return _currentSmsCount.toString();
    } else {
      // Format total sales with commas and KES prefix
      return 'KES ${_formatNumberWithCommas(widget.totalSales)}';
    }
  }

  String _formatNumberWithCommas(double number) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    return numberFormat.format(number);
  }

  String _getDisplayLabel() {
    if (_showSmsCount && _currentSmsCount > 0) {
      return widget.senderType;
    } else {
      return ''; // No label for sales amount
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show if there's either SMS or sales data
    final shouldShow = _currentSmsCount > 0 || widget.totalSales > 0;
    if (!shouldShow) {
      return Container(); // Don't show if no data
    }

    final color = _getIndicatorColor(widget.senderType);
    final icon = _getIndicatorIcon();
    final displayText = _getDisplayText();
    final displayLabel = _getDisplayLabel();

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        // Only apply scaling animation when showing SMS count
        final scale = (_showSmsCount && _currentSmsCount > 0) ? _scaleAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  displayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

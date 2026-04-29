import 'dart:async';
import 'package:flutter/material.dart';

class BlinkingSmsIcon extends StatefulWidget {
  final Stream<int> unreadCountStream;
  final String senderType;

  const BlinkingSmsIcon({
    super.key,
    required this.unreadCountStream,
    required this.senderType,
  });

  @override
  State<BlinkingSmsIcon> createState() => _BlinkingSmsIconState();
}

class _BlinkingSmsIconState extends State<BlinkingSmsIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late StreamSubscription<int> _countSubscription;
  int _currentUnreadCount = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Listen to unread count changes
    _countSubscription = widget.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _currentUnreadCount = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countSubscription.cancel();
    super.dispose();
  }

  Color _getIconColor(String senderType) {
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
        return const Color(0xFF182A62); // Blue for default
    }
  }

  IconData _getIconData(String senderType) {
    switch (senderType) {
      case "SMS Sender ID":
        return Icons.warning_amber;
      case "Short Code":
        return Icons.call_end;
      case "Saved Contact":
        return Icons.check_circle;
      case "Not Saved Contact":
        return Icons.help_outline;
      default:
        return Icons.sms;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getIconColor(widget.senderType);
    final icon = _getIconData(widget.senderType);

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  '($_currentUnreadCount)',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.senderType,
                  style: const TextStyle(
                    color: Colors.black87,
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

import 'package:intl/intl.dart';

class FormatUtils {
  static final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "en_US");

  /// Formats a number as currency with commas and 2 decimal places
  /// Example: 1250.50 -> "1,250.50"
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Formats a number as currency with KES prefix
  /// Example: 1250.50 -> "KES 1,250.50"
  static String formatCurrencyKES(double amount) {
    return "KES ${formatCurrency(amount)}";
  }

  /// Formats a number as currency with sign and KES prefix
  /// Example: 1250.50 -> "+KES 1,250.50"
  /// Example: -1250.50 -> "-KES 1,250.50"
  static String formatCurrencyWithSign(double amount) {
    String sign = amount >= 0 ? '+' : '';
    return "$sign${formatCurrencyKES(amount.abs())}";
  }
}

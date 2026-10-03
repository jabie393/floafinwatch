import 'package:intl/intl.dart';

class DateFormatter {
  static String formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    try {
      final formatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
      return '${formatter.format(local)} WIB';
    } catch (_) {
      final formatter = DateFormat('dd MMM yyyy, HH:mm');
      return '${formatter.format(local)} WIB';
    }
  }

  /// Formats date and time into standard 'dd MMM yyyy, HH:mm' format
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(local);
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    try {
      final formatter = DateFormat('dd MMM yyyy', 'id_ID');
      return formatter.format(local);
    } catch (_) {
      final formatter = DateFormat('dd MMM yyyy');
      return formatter.format(local);
    }
  }

  static String formatShortDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    try {
      final formatter = DateFormat('dd MMM', 'id_ID');
      return formatter.format(local);
    } catch (_) {
      final formatter = DateFormat('dd MMM');
      return formatter.format(local);
    }
  }
}

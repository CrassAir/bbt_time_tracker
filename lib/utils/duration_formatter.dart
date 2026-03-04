import 'dart:math';

/// Утилиты для форматирования Duration
class DurationFormatter {
  /// Форматировать длительность в человекочитаемый вид
  /// 
  /// Примеры:
  /// - 1h 30m (часы есть)
  /// - 15m 30s (минуты есть, часов нет)
  /// - 45s (только секунды)
  static String format(Duration d, {bool showSeconds = true}) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    
    if (h > 0) {
      return '${h}ч ${m}м';
    }
    if (m > 0 && showSeconds) {
      return '${m}м ${s}с';
    }
    if (m > 0) {
      return '${m}м';
    }
    return '${s}с';
  }

  /// Короткий формат для компактного отображения
  /// 
  /// Примеры:
  /// - 1ч 30м
  /// - 15м
  /// - 30с
  static String formatShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    
    if (h > 0) {
      return '${h}ч ${m}м';
    }
    if (m > 0) {
      return '${m}м';
    }
    return '${s}с';
  }

  /// Форматировать с точностью до минут (округление)
  static String formatRounded(Duration d) {
    final totalMinutes = d.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    }
    return '${minutes}м';
  }

  /// Форматировать для HH:MM (для полей ввода)
  static String toHourMinute(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Парсить из HH:MM или H:MM
  static Duration? fromHourMinute(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    
    final hours = int.tryParse(parts[0].trim()) ?? 0;
    final minutes = int.tryParse(parts[1].trim()) ?? 0;
    
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      return null;
    }
    
    return Duration(hours: hours, minutes: minutes);
  }

  /// Форматировать для Telegram (с emoji)
  static String formatForTelegram(Duration d, {bool verbose = false}) {
    if (verbose) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      
      final parts = <String>[];
      if (h > 0) parts.add('$h ч');
      if (m > 0) parts.add('$m м');
      if (s > 0 && h == 0) parts.add('$s с');
      
      return parts.join(' ');
    } else {
      return format(d);
    }
  }
}

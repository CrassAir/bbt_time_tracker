import 'dart:math';

extension DurIntExt on int {
  Duration get ms => Duration(milliseconds: this);

  Duration get sec => Duration(seconds: this);

  Duration get days => Duration(days: this);
}

extension CustomExtension on double? {
  String toSF({int count = 2, String? ifNullOrZero, String suffix = ''}) {
    if (this == null) return ifNullOrZero ?? '';
    if (this == 0.0) return ifNullOrZero ?? '0';

    final multiplier = pow(10, count);
    final floored = (this! * multiplier).floor() / multiplier;

    List<String> val = floored.toStringAsFixed(count).split('.');
    if (int.parse(val[1]) == 0) {
      return int.parse(val[0]).toString() + suffix;
    }

    var newVal = floored.toStringAsFixed(count);
    while (newVal[newVal.length - 1] == '0') {
      newVal = newVal.substring(0, newVal.length - 1);
    }
    return newVal + suffix;
  }
}

extension DurationFormat on num {
  String get toMinutesSeconds {
    int totalSeconds = toInt();
    int minutes = (totalSeconds / 60).floor();
    int seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  String get toHoursMinutesSeconds {
    int totalSeconds = toInt();
    int hours = (totalSeconds ~/ 3600).abs();
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${totalSeconds < 0 ? '- ' : ''}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get toHoursMinutes {
    int totalSeconds = toInt();
    int hours = (totalSeconds ~/ 3600).abs();
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes min';
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }
}

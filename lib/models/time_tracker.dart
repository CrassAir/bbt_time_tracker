class TimerModel {
  String name;
  Duration duration;
  DateTime createdAt = DateTime.now();
  DateTime? startDateTime;
  DateTime? endDateTime;
  Duration? timeFree;
  Duration? creditDur;
  String? project;
  Uri? url;

  TimerModel({required this.name, required this.duration, this.startDateTime, this.endDateTime, this.project}) {
    var tmpName = name.split(': ');
    if (tmpName.length > 1) {
      url = Uri.tryParse('https://tracker.yandex.ru/${tmpName.first}');
    }
  }

  bool get isRunning {
    return startDateTime != null && endDateTime == null;
  }
}

import 'package:objectbox/objectbox.dart';

@Entity()
class TimerModel {
  @Id()
  int id = 0;

  String name;
  String? project;

  @Transient()
  late Duration estimate;
  @Transient()
  Duration? durationLeft;
  @Transient()
  Uri? url;

  @Property(type: PropertyType.dateUtc)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.dateUtc)
  DateTime? startDateTime;

  @Property(type: PropertyType.dateUtc)
  DateTime? endDateTime;

  TimerModel({required this.name, this.startDateTime, this.endDateTime, this.project}) {
    var tmpName = name.split(': ');
    if (tmpName.length > 1) {
      url = Uri.parse('https://tracker.yandex.ru/${tmpName.first}');
    }
  }

  @Transient()
  bool get isRunning {
    return startDateTime != null && endDateTime == null;
  }

  int get durationMil => estimate.inMilliseconds;

  set durationMil(int value) => estimate = Duration(milliseconds: value);

  int get durationLeftMil => durationLeft?.inMilliseconds ?? 0;

  set durationLeftMil(int value) => durationLeft = Duration(milliseconds: value);

  String? get urlStr => url?.toString();

  set urlStr(String? value) => url = value != null ? Uri.parse(value) : null;
}

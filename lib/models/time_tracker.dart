import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class TimerModel {
  @Id()
  int id = 0;

  String name;
  String? project;
  String? branchName;

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

  bool isComplete = false;

  TimerModel({required this.name, this.startDateTime, this.project}) {
    var tmpName = name.split(': ');
    if (tmpName.length > 1) {
      url = Uri.parse('https://tracker.yandex.ru/${tmpName.first}');
    }
  }

  @Transient()
  bool get isRunning {
    return startDateTime != null && !isComplete;
  }

  int get durationMil => estimate.inMilliseconds;

  set durationMil(int value) => estimate = Duration(milliseconds: value);

  int get durationLeftMil => durationLeft?.inMilliseconds ?? 0;

  set durationLeftMil(int value) => durationLeft = Duration(milliseconds: value);

  String? get urlStr => url?.toString();

  set urlStr(String? value) => url = value != null ? Uri.parse(value) : null;
}

extension TimerModelExport on TimerModel {
  static List<TimerModel> getAll() {
    return objectbox.store.box<TimerModel>().getAll();
  }

  Map<String, dynamic> toExportMap() {
    return {
      'Status': isRunning ? 'Running' : (isComplete ? 'Completed' : 'Pending'),
      'Name': name,
      'Created': DateFormat('dd.MM.yyyy').format(createdAt.toLocal()),
      'Start': startDateTime != null ? DateFormat('dd.MM.yyyy HH:mm').format(startDateTime!.toLocal()) : '-',
      'End': isComplete && startDateTime != null
          ? DateFormat('dd.MM.yyyy HH:mm').format(startDateTime!.add(durationLeft ?? Duration.zero).toLocal())
          : '-',
      'Estimate': estimate.inSeconds.toHoursMinutesSeconds,
      'Duration Left': (durationLeft ?? Duration.zero).inSeconds.toHoursMinutesSeconds,
      'Branch name': branchName ?? '-',
      'URL': urlStr ?? '-',
    };
  }
}

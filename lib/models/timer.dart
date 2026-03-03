import 'package:objectbox/objectbox.dart';

@Entity()
class Timer {
  @Id()
  int id = 0;

  int number = 0;  // Порядковый номер задачи
  String name = '';
  String? description;  // Описание задачи (необязательное)
  String? project;
  String? branchName;
  String? url;

  @Property(type: PropertyType.dateUtc)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.dateUtc)
  DateTime? startDateTime;

  @Property(type: PropertyType.dateUtc)
  DateTime? endDateTime;

  bool isComplete = false;

  int estimateMilliseconds = 0;
  int durationLeftMilliseconds = 0;

  Timer({
    required String name,
    this.project,
    this.branchName,
    this.url,
    this.description,
    DateTime? startDateTime,
  }) : name = name, startDateTime = startDateTime;

  Duration get estimate => Duration(milliseconds: estimateMilliseconds);
  set estimate(Duration value) => estimateMilliseconds = value.inMilliseconds;

  Duration? get durationLeft =>
      durationLeftMilliseconds > 0 ? Duration(milliseconds: durationLeftMilliseconds) : null;
  set durationLeft(Duration? value) =>
      durationLeftMilliseconds = value?.inMilliseconds ?? 0;

  bool get isRunning => startDateTime != null && !isComplete;

  /// Оставшееся время (сколько ещё нужно работать)
  Duration get timeLeft {
    final elapsed = durationLeft ?? Duration.zero;
    final remaining = estimate - elapsed;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  /// Превышение времени (если потратили больше чем планировали)
  Duration get overTime {
    final elapsed = durationLeft ?? Duration.zero;
    final over = elapsed - estimate;
    return over > Duration.zero ? over : Duration.zero;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Timer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

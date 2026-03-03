import 'package:objectbox/objectbox.dart';

@Entity()
class WorkDay {
  @Id()
  int id = 0;

  int debtOfTimeMilliseconds = 0;
  int freeTimeMilliseconds = 0;
  int prevWorkTimeMilliseconds = 0;

  @Property(type: PropertyType.date)
  DateTime createToDate = DateTime.now().add(const Duration(days: 1));

  @Property(type: PropertyType.date)
  DateTime? startWorkDateTime;

  @Property(type: PropertyType.date)
  DateTime? endWorkDateTime;

  Duration get debtOfTime => Duration(milliseconds: debtOfTimeMilliseconds);
  set debtOfTime(Duration value) =>
      debtOfTimeMilliseconds = value.inMilliseconds;

  Duration get freeTime => Duration(milliseconds: freeTimeMilliseconds);
  set freeTime(Duration value) => freeTimeMilliseconds = value.inMilliseconds;

  Duration get prevWorkTime => Duration(milliseconds: prevWorkTimeMilliseconds);
  set prevWorkTime(Duration value) =>
      prevWorkTimeMilliseconds = value.inMilliseconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkDay && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class WorkDayModel {
  @Id()
  int id = 0;
  @Transient()
  Duration debtOfTime = Duration.zero;

  @Transient()
  Duration freeTime = Duration.zero;

  @Transient()
  Duration prevWorkTime = Duration.zero;

  @Property(type: PropertyType.date)
  DateTime createToDate = DateTime.now().add(Duration(days: 1)).startOfDay!;

  @Property(type: PropertyType.date)
  DateTime? startWorkDateTime;

  @Property(type: PropertyType.date)
  DateTime? endWorkDateTime;

  int get debtOfTimeMil => debtOfTime.inMilliseconds;

  set debtOfTimeMil(int value) => debtOfTime = Duration(milliseconds: value);

  int get freeTimeMil => freeTime.inMilliseconds;

  set freeTimeMil(int value) => freeTime = Duration(milliseconds: value);

  int get prevWorkTimeMil => prevWorkTime.inMilliseconds;

  set prevWorkTimeMil(int value) => prevWorkTime = Duration(milliseconds: value);
}

import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../objectbox.g.dart';
import '../models/timer.dart';
import '../models/work_day.dart';
import '../utils/date_ext.dart';

class ObjectBoxService {
  static final ObjectBoxService _instance = ObjectBoxService._internal();
  factory ObjectBoxService() => _instance;
  ObjectBoxService._internal();

  late Store store;
  late Box<Timer> timerBox;
  late Box<WorkDay> workDayBox;

  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();

    store = await openStore(
      directory: docsDir.path,
    );

    timerBox = store.box<Timer>();
    workDayBox = store.box<WorkDay>();
  }

  // Timer operations
  List<Timer> getAllTimers() => timerBox.getAll();

  Future<int> putTimer(Timer timer) async => timerBox.put(timer);

  void removeTimer(Timer timer) => timerBox.remove(timer.id);

  void removeAllTimers() => timerBox.removeAll();

  // WorkDay operations
  List<WorkDay> getAllWorkDays() => workDayBox.getAll();

  WorkDay? getCurrentWorkDay() {
    final today = DateTime.now();
    final todayYear = today.year;
    final todayMonth = today.month;
    final todayDay = today.day;

    final allWorkDays = workDayBox.getAll();
    for (final wd in allWorkDays) {
      final createToDate = wd.createToDate;
      // Сравниваем по году, месяцу и дню
      if (createToDate.year == todayYear &&
          createToDate.month == todayMonth &&
          createToDate.day == todayDay) {
        return wd;
      }
    }
    return null;
  }

  /// Получить предыдущий рабочий день
  WorkDay? getPreviousWorkDay(DateTime date) {
    final allWorkDays = workDayBox.getAll();
    final dateStartOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final result = allWorkDays
      .where((d) {
        final dStartOfDay = DateTime(d.createToDate.year, d.createToDate.month, d.createToDate.day, 0, 0, 0);
        return dStartOfDay.isBefore(dateStartOfDay);
      })
      .toList()
      ..sort((a, b) => b.createToDate.compareTo(a.createToDate));

    return result.firstOrNull;
  }

  /// Получить рабочий день по дате
  WorkDay? getWorkDayByDate(DateTime date) {
    final dateStartOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dateEndOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final allWorkDays = workDayBox.getAll();
    for (final wd in allWorkDays) {
      final createToDate = wd.createToDate;
      if (createToDate.isAtSameMomentAs(dateStartOfDay) ||
          (createToDate.isAfter(dateStartOfDay) && createToDate.isBefore(dateEndOfDay))) {
        return wd;
      }
    }
    return null;
  }

  Future<int> putWorkDay(WorkDay workDay) async => workDayBox.put(workDay);

  void removeWorkDay(WorkDay workDay) => workDayBox.remove(workDay.id);

  void dispose() {
    store.close();
  }
}
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../objectbox.g.dart';
import '../models/timer.dart';
import '../models/work_day.dart';

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
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final allWorkDays = workDayBox.getAll();
    for (final wd in allWorkDays) {
      if (wd.createToDate.isAfter(startOfDay) && wd.createToDate.isBefore(endOfDay)) {
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
import 'package:flutter/foundation.dart';
import '../models/timer.dart';
import '../models/work_day.dart';
import '../utils/date_ext.dart';
import '../utils/global_timer.dart';
import 'objectbox_service.dart';

class TimeTrackerService extends ChangeNotifier {
  final ObjectBoxService _objectBox = ObjectBoxService();
  List<Timer> _timers = [];

  List<Timer> get timers => _timers;
  WorkDay? get currentWorkDay => _objectBox.getCurrentWorkDay();

  // Вычисляемые поля для отображения в круговом прогрессе
  int get todaySpentSeconds {
    int spent = 0;
    final today = DateTime.now().startOfDay;
    for (final t in timers) {
      // Для завершённых задач берём estimate (как в старой версии)
      if (t.isComplete && t.endDateTime?.startOfDay == today) {
        spent += t.estimate.inSeconds;
      } else {
        spent += t.durationLeft?.inSeconds ?? 0;
      }
    }
    // Вычитаем время, перенесённое с предыдущих дней
    spent -= currentWorkDay?.prevWorkTime.inSeconds ?? 0;
    return spent;
  }

  Duration get todayWorkDuration {
    if (currentWorkDay?.startWorkDateTime == null) return Duration.zero;
    final now = DateTime.now();
    return now.difference(currentWorkDay!.startWorkDateTime!);
  }

  int get todayLeftSeconds {
    if (currentWorkDay?.startWorkDateTime == null) return 0;
    if (currentWorkDay?.endWorkDateTime != null) {
      return currentWorkDay!.endWorkDateTime!
          .difference(currentWorkDay!.startWorkDateTime!)
          .inSeconds;
    }
    return DateTime.now()
        .difference(currentWorkDay!.startWorkDateTime!)
        .inSeconds;
  }

  bool get isOffDay {
    if (currentWorkDay?.startWorkDateTime == null) return false;
    final end = currentWorkDay!.startWorkDateTime!
        .add(const Duration(hours: 8));
    return DateTime.now().isAfter(end);
  }

  int get freeSeconds {
    final left = todayLeftSeconds;
    final spent = todaySpentSeconds;
    if (spent > left) return 0;
    return left - spent;
  }

  int get debtSeconds {
    final left = todayLeftSeconds;
    final spent = todaySpentSeconds;
    if (spent <= left) return 0;
    return spent - left;
  }

  // Для автостарта дня
  static const int workDayDurationSeconds = 28800; // 8 часов
  static const int startHour = 11; // старт в 11:00

  // Подписка на глобальный таймер
  VoidCallback? _timerListener;
  VoidCallback? _dayListener;

  Future<void> load() async {
    // Загружаем таймеры из ObjectBox
    _timers = _objectBox.getAllTimers();
    _subscribeToGlobalTimer();
    notifyListeners();
  }

  /// Перезагрузить данные из ObjectBox (для IPC синхронизации)
  void reload() {
    _timers = _objectBox.getAllTimers();
    notifyListeners();
  }

  void _subscribeToGlobalTimer() {
    if (_timerListener != null) return;

    _timerListener = _onTimerTick;
    GlobalTimer().addListener(_timerListener!);

    _dayListener = _onDayTick;
    GlobalTimer().dayListener = _dayListener;
  }

  void _unsubscribeFromGlobalTimer() {
    if (_timerListener != null) {
      GlobalTimer().removeListener(_timerListener!);
      _timerListener = null;
    }
    GlobalTimer().dayListener = null;
  }

  int _tickCounter = 0;

  void _onTimerTick() {
    // Увеличиваем durationLeft у всех запущенных таймеров
    bool changed = false;
    for (final t in timers) {
      if (t.isRunning) {
        t.durationLeftMilliseconds += 1000;
        changed = true;
      }
    }
    if (changed) {
      _tickCounter++;
      // Сохраняем в БД каждые 10 секунд (как в старой версии)
      if (_tickCounter % 10 == 0) {
        for (final t in timers.where((t) => t.isRunning)) {
          _objectBox.putTimer(t);
        }
      }
      notifyListeners();
    }
  }

  void _onDayTick() {
    _checkAutoStartStop();
    _checkDayRollover();
    // Обновляем UI (leftSeconds изменилось)
    notifyListeners();
  }

  void _checkAutoStartStop() {
    final now = DateTime.now();
    final todayStart = now.startOfDay!.add(Duration(hours: startHour));
    final todayEnd = todayStart.add(Duration(seconds: workDayDurationSeconds));

    // Автостарт в 11:00, если день не начат
    if (now.isAfter(todayStart) &&
        now.isBefore(todayEnd) &&
        currentWorkDay?.startWorkDateTime == null) {
      _startWorkDay(startDateTime: todayStart);
      GlobalTimer().playStartUpSound(); // исправлено
    }

    // Автостоп через 8 часов после старта
    if (currentWorkDay?.startWorkDateTime != null &&
        currentWorkDay?.endWorkDateTime == null &&
        now.isAfter(currentWorkDay!.startWorkDateTime!
            .add(Duration(seconds: workDayDurationSeconds)))) {
      _endWorkDay(isSoft: true);
    }
  }

  void _checkDayRollover() {
    final now = DateTime.now();
    final today = now.startOfDay!;
    if (currentWorkDay?.createToDate.startOfDay != today) {
      // Перешли на новый день
      if (currentWorkDay?.endWorkDateTime == null) {
        _endWorkDay(isSoft: true);
      }
      // Создаём новый WorkDay для сегодня
      final newWorkDay = WorkDay()
        ..createToDate = today;
      _objectBox.putWorkDay(newWorkDay);
      notifyListeners();
    }
  }

  Future<Timer> addTimer({
    required String name,
    required Duration estimate,
    String? project,
    String? description,
  }) async {
    // Авто-инкремент номера задачи
    final maxNumber = timers.fold<int>(0, (max, t) => t.number > max ? t.number : max);
    
    final timer = Timer(
      name: name,
      project: project,
      description: description,
    );
    timer.number = maxNumber + 1;
    timer.estimate = estimate;
    timer.createdAt = DateTime.now();
    await _objectBox.putTimer(timer);
    _timers.add(timer);
    notifyListeners();
    return timer;
  }

  Future<void> startTimer(Timer timer) async {
    // Останавливаем все остальные запущенные таймеры
    for (final t in timers.where((t) => t.isRunning && t.id != timer.id)) {
      await stopTimer(t);
    }

    timer.startDateTime = DateTime.now();
    timer.isComplete = false;
    // durationLeft не сбрасываем, если уже был накоплен (при возобновлении)
    await _objectBox.putTimer(timer);
    notifyListeners();
  }

  Future<void> stopTimer(Timer timer) async {
    timer.endDateTime = DateTime.now();
    timer.isComplete = true;
    await _objectBox.putTimer(timer);
    notifyListeners();
  }

  Future<void> completeTimer(Timer timer) async {
    // Завершить досрочно (как FINISH в старой версии)
    if (timer.isRunning) {
      timer.endDateTime = DateTime.now();
      timer.isComplete = true;
    }
    await _objectBox.putTimer(timer);
    notifyListeners();
  }

  Future<void> resumeTimer(Timer timer) async {
    if (timer.isComplete) {
      timer.isComplete = false;
      timer.endDateTime = null;
      await _objectBox.putTimer(timer);
      notifyListeners();
    }
  }

  Future<void> updateTimer(Timer timer,
      {String? name, Duration? estimate, String? project, String? description}) async {
    if (name != null) timer.name = name;
    if (estimate != null) timer.estimate = estimate;
    if (project != null) timer.project = project;
    if (description != null) timer.description = description;
    await _objectBox.putTimer(timer);
    notifyListeners();
  }

  Future<void> deleteTimer(Timer timer) async {
    // Удаляем, при необходимости корректируем prevWorkTime дня (как в старой версии)
    if (timer.isRunning && currentWorkDay?.endWorkDateTime != null) {
      // Если день уже закончен, вычитаем время удалённого таймера из prevWorkTime
      final day = currentWorkDay;
      if (day != null) {
        day.prevWorkTimeMilliseconds -= timer.durationLeftMilliseconds; // исправлено
        _objectBox.putWorkDay(day);
      }
    }
    _timers.remove(timer);
    _objectBox.removeTimer(timer);
    notifyListeners();
  }

  void _startWorkDay({DateTime? startDateTime}) {
    final day = currentWorkDay ?? WorkDay();
    day.startWorkDateTime ??= startDateTime ?? DateTime.now();
    day.endWorkDateTime = null;
    _objectBox.putWorkDay(day);
    // Подписка уже есть
    notifyListeners();
  }

  void _endWorkDay({bool isSoft = false}) {
    final day = currentWorkDay;
    if (day == null) return;
    if (day.endWorkDateTime != null) return; // уже завершён

    day.endWorkDateTime = DateTime.now();
    _objectBox.putWorkDay(day);

    if (isSoft) {
      GlobalTimer().playTimeUpSound(); // исправлено
    }

    // Обновляем prevWorkTime для следующего дня (как в старой версии)
    final tomorrow = DateTime.now().startOfDay!.add(const Duration(days: 1));
    final nextDay = WorkDay()
      ..createToDate = tomorrow
      ..prevWorkTimeMilliseconds = (todaySpentSeconds - (isOffDay ? workDayDurationSeconds : todayLeftSeconds)) * 1000;
    _objectBox.putWorkDay(nextDay);

    notifyListeners();
  }

  void startWorkDay() => _startWorkDay();
  void resumeWorkDay() => _startWorkDay(); // resume аналогичен старту
  void endWorkDay() => _endWorkDay();

  @override
  void dispose() {
    _unsubscribeFromGlobalTimer();
    super.dispose();
  }
}
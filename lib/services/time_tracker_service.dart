import 'package:flutter/foundation.dart';
import '../models/timer.dart';
import '../models/work_day.dart';
import '../models/bot_settings.dart';
import '../utils/date_ext.dart';
import '../utils/global_timer.dart';
import 'objectbox_service.dart';

class TimeTrackerService extends ChangeNotifier {
  final ObjectBoxService _objectBox = ObjectBoxService();
  late BotSettings _settings;
  List<Timer> _timers = [];

  List<Timer> get timers => _timers;
  WorkDay? get currentWorkDay => _objectBox.getCurrentWorkDay();

  // Подписка на глобальный таймер
  VoidCallback? _timerListener;
  VoidCallback? _dayListener;

  Future<void> load() async {
    // Загружаем настройки
    _settings = await BotSettings.load();
    
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

  // === ВЫЧИСЛЯЕМЫЕ ПОЛЯ — БЕРЁМ ИЗ WORKDAY ===

  /// Время работы дня (от нажатия Start day)
  int get todayWorkSeconds => todayWorkDuration.inSeconds;

  /// Оставшееся время рабочего дня (8 часов - время работы)
  int get todayRemainingSeconds {
    final maxSeconds = _settings.workDayDurationHours * 3600;
    final remaining = maxSeconds - todayWorkSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Сумма estimate всех задач дня
  int get todayTasksEstimateSeconds {
    final day = currentWorkDay;
    if (day == null) return 0;
    return (day.totalEstimateMilliseconds + day.prevWorkTimeMilliseconds) ~/ 1000;
  }

  /// Сумма фактически затраченного времени на задачи
  int get todayTasksSpentSeconds {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final todayTasks = _timers.where((t) =>
      t.startDateTime != null &&
      t.startDateTime!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
      t.startDateTime!.isBefore(todayEnd.add(const Duration(seconds: 1)))
    );
    
    return todayTasks.fold<int>(0, (sum, t) => sum + (t.durationLeftMilliseconds ~/ 1000));
  }

  /// Свободное время = сэкономленное на задачах + перенос с прошлого дня
  int get freeSeconds {
    // Если задачи еще не начаты или нет estimate
    if (todayTasksEstimateSeconds <= 0) return 0;
    
    // Экономия = estimate - spent (только если положительная)
    final savedOnTasks = todayTasksEstimateSeconds - todayTasksSpentSeconds;
    if (savedOnTasks > 0) {
      return savedOnTasks;
    }
    return 0;
  }

  /// Задолженность времени = время работы дня - (estimate задач + free time)
  int get debtSeconds {
    // Если есть свободное время от задач, используем его
    final savedOnTasks = todayTasksEstimateSeconds - todayTasksSpentSeconds;
    
    if (savedOnTasks > 0) {
      // Есть экономия на задачах - сначала уменьшаем её временем работы
      final remainingFree = savedOnTasks - todayWorkSeconds;
      if (remainingFree > 0) {
        return 0; // Еще есть свободное время
      }
      // Свободное время закончилось, начинается задолженность
      return -remainingFree;
    } else {
      // Задачи превысили estimate - сразу считаем задолженность
      final overTime = -savedOnTasks; // Превышение estimate
      final workOverEstimate = todayWorkSeconds - (todayTasksEstimateSeconds + overTime);
      return workOverEstimate > 0 ? workOverEstimate : 0;
    }
  }

  Duration get debtOfTime => currentWorkDay?.debtOfTime ?? Duration.zero;
  Duration get freeTime => currentWorkDay?.freeTime ?? Duration.zero;
  Duration get todayBalance => currentWorkDay?.balance ?? Duration.zero;
  
  Duration get todayWorkDuration {
    final day = currentWorkDay;
    if (day?.startWorkDateTime == null) return Duration.zero;
    final now = DateTime.now();
    return now.difference(day!.startWorkDateTime!);
  }
  
  bool get isOffDay {
    if (currentWorkDay?.startWorkDateTime == null) return false;
    final end = currentWorkDay!.startWorkDateTime!
        .add(Duration(hours: _settings.workDayDurationHours));
    return DateTime.now().isAfter(end);
  }

  int _tickCounter = 0;
  bool _dayStartSoundPlayed = false;
  bool _dayEndSoundPlayed = false;

  void _onTimerTick() {
    // Увеличиваем durationLeft у всех запущенных таймеров
    bool changed = false;
    for (final t in timers) {
      if (t.isRunning) {
        t.durationLeftMilliseconds += 1000;
        changed = true;
      }
    }
    
    // Всегда уведомляем слушателей для обновления UI (таймер дня, прогресс)
    _tickCounter++;
    
    // Сохраняем в БД каждые 10 секунд
    if (changed && _tickCounter % 10 == 0) {
      for (final t in timers.where((t) => t.isRunning)) {
        _objectBox.putTimer(t);
      }
    }
    
    // Проверяем окончание задачи (<60 сек)
    if (changed) {
      _checkTaskEndingSoon();
    }
    
    notifyListeners();
  }

  void _onDayTick() {
    _checkAutoStartStop();
    _checkDayRollover();
    notifyListeners();
  }

  void _checkAutoStartStop() {
    if (!_settings.autoStartDay || !_settings.autoStopDay) return;

    final now = DateTime.now();
    final startHour = _settings.workDayStartHour;
    final durationHours = _settings.workDayDurationHours;

    final todayStart = now.startOfDay!.add(Duration(hours: startHour));
    final todayEnd = todayStart.add(Duration(hours: durationHours));

    // Автостарт в указанное время, если день не начат
    if (now.isAfter(todayStart) &&
        now.isBefore(todayEnd) &&
        currentWorkDay?.startWorkDateTime == null &&
        !_dayStartSoundPlayed) {
      _startWorkDay(startDateTime: todayStart);
      _playDayStartSound();
      _dayStartSoundPlayed = true;
    }

    // Автостоп через указанное количество часов после старта
    if (currentWorkDay?.startWorkDateTime != null &&
        currentWorkDay?.endWorkDateTime == null &&
        now.isAfter(currentWorkDay!.startWorkDateTime!
            .add(Duration(hours: durationHours))) &&
        !_dayEndSoundPlayed) {
      _endWorkDay(isSoft: true);
      _playDayEndSound();
      _dayEndSoundPlayed = true;
    }
  }

  /// Проверка окончания задачи (<60 секунд)
  void _checkTaskEndingSoon() {
    final threshold = Duration(seconds: _settings.taskEndingSoonSeconds);
    
    for (final timer in timers) {
      if (!timer.isRunning) continue;
      if (timer.isComplete) continue;
      
      final timeLeft = timer.timeLeft;
      if (timeLeft <= threshold && timeLeft > Duration.zero) {
        _playTaskEndingSoonSound();
      }
    }
  }

  /// Воспроизведение звука старта дня
  void _playDayStartSound() {
    if (_settings.dayStartSoundPath != null) {
      GlobalTimer().playCustomSound(_settings.dayStartSoundPath!);
    } else {
      GlobalTimer().playStartUpSound();
    }
  }

  /// Воспроизведение звука завершения дня
  void _playDayEndSound() {
    if (_settings.dayEndSoundPath != null) {
      GlobalTimer().playCustomSound(_settings.dayEndSoundPath!);
    } else {
      GlobalTimer().playTimeUpSound();
    }
  }

  /// Воспроизведение звука окончания задачи
  void _playTaskEndingSoonSound() {
    if (_settings.taskEndingSoonSoundPath != null) {
      GlobalTimer().playCustomSound(_settings.taskEndingSoonSoundPath!);
    } else {
      GlobalTimer().playTimeUpSound();
    }
  }

  void _checkDayRollover() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 0, 0, 0);

    // Проверяем, перешли ли на новый день
    final currentDay = currentWorkDay;
    final currentDayDate = currentDay?.createToDate != null 
        ? DateTime(currentDay!.createToDate.year, currentDay.createToDate.month, currentDay.createToDate.day, 0, 0, 0)
        : null;
    
    if (currentDayDate != today) {
      // === 1. ЗАВЕРШАЕМ ПРЕДЫДУЩИЙ ДЕНЬ ===
      if (currentDay?.endWorkDateTime == null) {
        _endWorkDay(isSoft: true); // Мягкое завершение (без звука)
      }

      // === 2. ПОЛУЧАЕМ ПРЕДЫДУЩИЙ ДЕНЬ ===
      final previousDay = _objectBox.getPreviousWorkDay(today);

      // === 3. СОЗДАЁМ НОВЫЙ ДЕНЬ С ПЕРЕНОСОМ ===
      final newWorkDay = WorkDay()
        ..createToDate = today
        ..prevWorkTimeMilliseconds = previousDay?.carriedOverMilliseconds ?? 0;

      _objectBox.putWorkDay(newWorkDay);

      // === 4. СБРАСЫВАЕМ ФЛАГИ ЗВУКОВ ===
      _dayStartSoundPlayed = false;
      _dayEndSoundPlayed = false;

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
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day, 0, 0, 0);
    
    var day = currentWorkDay;
    if (day == null) {
      day = WorkDay()
        ..createToDate = todayStart
        ..startWorkDateTime = startDateTime ?? DateTime.now()
        ..endWorkDateTime = null;
    } else {
      day.startWorkDateTime = startDateTime ?? DateTime.now();
      day.endWorkDateTime = null;
    }
    
    _objectBox.putWorkDay(day);
    notifyListeners();
  }

  void _endWorkDay({bool isSoft = false}) {
    final day = currentWorkDay;
    if (day == null) return;
    if (day.endWorkDateTime != null) return; // уже завершён

    day.endWorkDateTime = DateTime.now();

    // === 1. СОБИРАЕМ ВСЕ ЗАДАЧИ ДНЯ ===
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final todayTasks = _timers.where((t) =>
      t.startDateTime != null &&
      t.startDateTime!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
      t.startDateTime!.isBefore(todayEnd.add(const Duration(seconds: 1)))
    );

    // === 2. СУММИРУЕМ ESTIMATE И SPENT ===
    day.totalEstimateMilliseconds = todayTasks
      .fold(0, (sum, t) => sum + t.estimateMilliseconds);

    day.totalSpentMilliseconds = todayTasks
      .fold(0, (sum, t) => sum + t.durationLeftMilliseconds);

    // === 3. СЧИТАЕМ ПЕРЕНОС НА СЛЕДУЮЩИЙ ДЕНЬ ===
    // Перенос = spent - estimate (только если положительный)
    final carriedOver = day.totalSpent - day.totalEstimate;
    final nextDayCarried = carriedOver > Duration.zero ? carriedOver : Duration.zero;

    // === 4. СЧИТАЕМ БАЛАНС ДНЯ ===
    final totalAvailable = day.totalEstimate + day.prevWorkTime;
    final balance = day.totalSpent - totalAvailable;

    if (balance > Duration.zero) {
      day.debtOfTimeMilliseconds = balance.inMilliseconds;
      day.freeTimeMilliseconds = 0;
    } else if (balance < Duration.zero) {
      day.freeTimeMilliseconds = -balance.inMilliseconds;
      day.debtOfTimeMilliseconds = 0;
    }

    // === 5. СОЗДАЁМ СЛЕДУЮЩИЙ ДЕНЬ С ПЕРЕНОСОМ ===
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final nextDay = WorkDay()
      ..createToDate = tomorrow
      ..prevWorkTimeMilliseconds = nextDayCarried.inMilliseconds;

    // === 6. СОХРАНЯЕМ ===
    _objectBox.putWorkDay(day);
    _objectBox.putWorkDay(nextDay);

    if (!isSoft) {
      GlobalTimer().playTimeUpSound();
    }

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
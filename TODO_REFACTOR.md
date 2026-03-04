# TODO: Рефакторинг модели WorkDay и логики отчётов

**Версия:** 3.0 (с авто-стартом/стопом и звуками)  
**Дата:** 4 марта 2026 г.

---

## 🎯 Цель

Переработать модель рабочего дня для учёта времени из задач (estimate/durationLeft), корректного переноса времени при незавершённых задачах и улучшения отчётов.

**Ключевая концепция:**
- ✅ **Свободное время** — мотивация закончить задачи быстрее estimate
- ✅ **Задолженность** — предупреждение о превышении времени
- ✅ **Перенос времени** — незавершённые задачи переносят затраченное время на следующий день
- ✅ **Прозрачность** — в контексте дней видно свободное время или задолженность
- ✅ **Авто-старт/стоп** — день начинается в 11:00 и заканчивается через 8 часов
- ✅ **Звуковые уведомления** — старт дня, завершение дня, окончание задачи (<60 сек)

---

## 📋 Задачи

### 1. Обновить модель WorkDay ✅

**Файл:** `lib/models/work_day.dart`

**Проблема текущей версии:**
- ❌ Нет связи с задачами
- ❌ Нет учёта estimate/spent задач
- ❌ Нет переноса времени между днями

**Новая структура:**

```dart
@Entity()
class WorkDay {
  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime createToDate = DateTime.now().add(const Duration(days: 1));

  @Property(type: PropertyType.date)
  DateTime? startWorkDateTime;

  @Property(type: PropertyType.date)
  DateTime? endWorkDateTime;

  // === ВРЕМЯ ИЗ ЗАДАЧ ===
  int totalEstimateMilliseconds = 0;      // Сумма estimate ВСЕХ задач дня
  int totalSpentMilliseconds = 0;         // Сумма spent ВСЕХ задач дня
  int carriedOverMilliseconds = 0;        // Перенос на следующий день (spent - estimate)

  // === БАЛАНС ===
  int prevWorkTimeMilliseconds = 0;       // Получено с предыдущего дня
  int debtOfTimeMilliseconds = 0;         // Задолженность (если spent > estimate)
  int freeTimeMilliseconds = 0;           // Свободное время (если spent < estimate)

  // === Вычисляемые поля ===
  Duration get totalEstimate => Duration(milliseconds: totalEstimateMilliseconds);
  Duration get totalSpent => Duration(milliseconds: totalSpentMilliseconds);
  Duration get carriedOver => Duration(milliseconds: carriedOverMilliseconds);
  Duration get prevWorkTime => Duration(milliseconds: prevWorkTimeMilliseconds);
  Duration get debtOfTime => Duration(milliseconds: debtOfTimeMilliseconds);
  Duration get freeTime => Duration(milliseconds: freeTimeMilliseconds);

  /// === БАЛАНС ДНЯ ===
  /// Формула: (totalSpent + prevWorkTime) - totalEstimate
  /// 
  /// Если > 0: задолженность (перерасход)
  /// Если < 0: свободное время (экономия)
  /// Если = 0: баланс
  Duration get balance {
    final totalAvailable = totalEstimate + prevWorkTime;
    final difference = totalSpent - totalAvailable;
    
    if (difference > Duration.zero) {
      // Задолженность: потратили больше чем планировали
      return difference;
    } else if (difference < Duration.zero) {
      // Свободное время: потратили меньше чем планировали
      return difference; // Отрицательное значение = свободное время
    }
    return Duration.zero;
  }

  /// Задолженность в миллисекундах (положительное значение)
  int get debtMilliseconds {
    final balance = this.balance.inMilliseconds;
    return balance > 0 ? balance : 0;
  }

  /// Свободное время в миллисекундах (положительное значение)
  int get freeMilliseconds {
    final balance = this.balance.inMilliseconds;
    return balance < 0 ? -balance : 0;
  }
}
```

**Важные изменения:**
- ✅ `totalEstimate` — сумма estimate ВСЕХ задач (не только завершённых)
- ✅ `totalSpent` — сумма spent ВСЕХ задач (включая активные)
- ✅ `carriedOver` — разница (spent - estimate) если положительная
- ✅ `balance` — показывает задолженность (>0) или свободное время (<0)

---

### 2. Обновить логику остановки дня ✅

**Файл:** `lib/services/time_tracker_service.dart`

**Проблема текущей версии:**
- ❌ Не учитывает estimate задач
- ❌ Переносит только переработку
- ❌ Не обновляет totalEstimate/totalSpent

**НОВАЯ ЛОГИКА:**

```dart
void _endWorkDay({bool isSoft = false}) {
  final day = currentWorkDay;
  if (day == null) return;

  day.endWorkDateTime = DateTime.now();

  // === 1. СОБИРАЕМ ВСЕ ЗАДАЧИ ДНЯ ===
  final today = DateTime.now().startOfDay;
  final todayTasks = timers.where((t) =>
    t.startDateTime != null && 
    t.startDateTime!.startOfDay == today
  );

  // === 2. СУММИРУЕМ ESTIMATE И SPENT ===
  day.totalEstimateMilliseconds = todayTasks
    .fold(0, (sum, t) => sum + t.estimate.inMilliseconds);
  
  day.totalSpentMilliseconds = todayTasks
    .fold(0, (sum, t) => sum + (t.durationLeft?.inMilliseconds ?? 0));

  // === 3. СЧИТАЕМ ПЕРЕНОС НА СЛЕДУЮЩИЙ ДЕНЬ ===
  // Перенос = spent - estimate (только если положительный)
  // Это время, которое УЖЕ потрачено на незавершённые задачи
  final carriedOver = day.totalSpent - day.totalEstimate;
  final nextDayCarried = carriedOver > 0 ? carriedOver : Duration.zero;

  // === 4. СЧИТАЕМ БАЛАНС ДНЯ ===
  // Баланс = (spent + prevWorkTime) - estimate
  final totalAvailable = day.totalEstimate + day.prevWorkTime;
  final balance = day.totalSpent - totalAvailable;

  if (balance > Duration.zero) {
    // Задолженность: потратили больше чем доступно
    day.debtOfTimeMilliseconds = balance.inMilliseconds;
    day.freeTimeMilliseconds = 0;
  } else if (balance < Duration.zero) {
    // Свободное время: потратили меньше чем доступно
    day.freeTimeMilliseconds = -balance.inMilliseconds;
    day.debtOfTimeMilliseconds = 0;
  } else {
    // Баланс
    day.debtOfTimeMilliseconds = 0;
    day.freeTimeMilliseconds = 0;
  }

  // === 5. СОЗДАЁМ СЛЕДУЮЩИЙ ДЕНЬ С ПЕРЕНОСОМ ===
  final tomorrow = DateTime.now().startOfDay.add(const Duration(days: 1));
  final nextDay = WorkDay()
    ..createToDate = tomorrow
    ..prevWorkTimeMilliseconds = nextDayCarried.inMilliseconds;

  // === 6. СОХРАНЯЕМ ===
  _objectBox.putWorkDay(day);
  _objectBox.putWorkDay(nextDay);

  if (isSoft) {
    GlobalTimer().playTimeUpSound();
  }

  notifyListeners();
}
```

**Ключевые изменения:**
- ✅ Суммируем estimate/spent ВСЕХ задач дня (не только завершённых)
- ✅ Перенос = spent - estimate (время, уже потраченное на незавершённые задачи)
- ✅ Баланс = (spent + prevWorkTime) - estimate
- ✅ Создаём следующий день с `prevWorkTime = carriedOver`

---

### 3. Обновить логику нового дня ✅

**Файл:** `lib/services/time_tracker_service.dart`

**Проблема текущей версии:**
- ❌ Не получает предыдущий день
- ❌ Не переносит carriedOver

**НОВАЯ ЛОГИКА:**

```dart
void _checkDayRollover() {
  final now = DateTime.now();
  final today = now.startOfDay;

  // Проверяем, перешли ли на новый день
  if (currentWorkDay?.createToDate.startOfDay != today) {
    // === 1. ЗАВЕРШАЕМ ПРЕДЫДУЩИЙ ДЕНЬ ===
    if (currentWorkDay?.endWorkDateTime == null) {
      _endWorkDay(isSoft: true); // Мягкое завершение (без звука)
    }

    // === 2. ПОЛУЧАЕМ ПРЕДЫДУЩИЙ ДЕНЬ ===
    final previousDay = _objectBox.getPreviousWorkDay(today);

    // === 3. СОЗДАЁМ НОВЫЙ ДЕНЬ С ПЕРЕНОСОМ ===
    final newWorkDay = WorkDay()
      ..createToDate = today
      ..prevWorkTimeMilliseconds = previousDay?.carriedOverMilliseconds ?? 0;

    _objectBox.putWorkDay(newWorkDay);
    notifyListeners();
  }
}
```

**Важно:**
- ✅ `carriedOver` из предыдущего дня → `prevWorkTime` нового дня
- ✅ Это время УЖЕ потрачено на незавершённые задачи

---

### 4. Обновить вычисляемые поля сервиса ✅

**Файл:** `lib/services/time_tracker_service.dart`

**Проблема текущей версии:**
- ❌ `todaySpentSeconds` не учитывает prevWorkTime
- ❌ `todayLeftSeconds` использует фиксированные 8 часов
- ❌ `freeSeconds`/`debtSeconds` не используют WorkDay

**НОВАЯ ЛОГИКА:**

```dart
// === ПРОВЕРЕНО: БЕРЁМ ИЗ WORKDAY ===
int get todaySpentSeconds {
  return currentWorkDay?.totalSpentMilliseconds.inSeconds ?? 0;
}

int get todayEstimateSeconds {
  final day = currentWorkDay;
  if (day == null) return 0;
  // Estimate + время с предыдущего дня
  return (day.totalEstimate + day.prevWorkTime).inSeconds;
}

int get todayLeftSeconds {
  // Время, которое должно быть затрачено (estimate + перенос)
  return todayEstimateSeconds;
}

// === ПРОВЕРЕНО: БАЛАНС ===
int get freeSeconds {
  final spent = todaySpentSeconds;
  final estimate = todayEstimateSeconds;
  
  // Если потратили меньше чем доступно — есть свободное время
  if (spent < estimate) {
    return estimate - spent;
  }
  return 0;
}

int get debtSeconds {
  final spent = todaySpentSeconds;
  final estimate = todayEstimateSeconds;
  
  // Если потратили больше чем доступно — есть задолженность
  if (spent > estimate) {
    return spent - estimate;
  }
  return 0;
}

// === ДЛЯ ОТОБРАЖЕНИЯ В UI ===
Duration get todayBalance {
  final day = currentWorkDay;
  if (day == null) return Duration.zero;
  
  final totalAvailable = day.totalEstimate + day.prevWorkTime;
  final difference = day.totalSpent - totalAvailable;
  
  return difference; // >0: долг, <0: свободное время
}
```

**Проверка логики:**
- ✅ `todaySpentSeconds` = totalSpent из WorkDay
- ✅ `todayEstimateSeconds` = totalEstimate + prevWorkTime
- ✅ `freeSeconds` = estimate - spent (если spent < estimate)
- ✅ `debtSeconds` = spent - estimate (если spent > estimate)

---

### 5. Переработать экспорт отчётов ✅

**Файл:** `lib/services/export_service.dart`

**Проблема текущей версии:**
- ❌ Фильтрация по `endDateTime` (не учитывает активные задачи)
- ❌ Нет баланса по задачам

**НОВАЯ ЛОГИКА:**

```dart
static Future<String> exportToExcel(
  List<Timer> timers, {
  required DateTime from,
  required DateTime to,
}) async {
  // === 1. ФИЛЬТРУЕМ ПО ДАТЕ СТАРТА ===
  // Задачи, которые были начаты в период
  final filtered = timers.where((t) {
    final start = t.startDateTime;
    if (start == null) return false;
    return start.isAfter(from.startOfDay.subtract(const Duration(days: 1))) &&
           start.isBefore(to.endOfDay);
  }).toList();

  // === 2. ГРУППИРУЕМ ПО ДНЯМ ===
  final byDay = <String, List<Timer>>{};
  for (final timer in filtered) {
    final dayKey = timer.startDateTime!.toIso8601String().split('T').first;
    byDay.putIfAbsent(dayKey, () => []).add(timer);
  }

  // === 3. СОЗДАЁМ EXCEL ===
  final excel = Excel.createExcel();
  final sheet = excel['Отчёт'];
  
  // Заголовки
  sheet.appendRow([
    'Дата',
    'Задача',
    'Статус',
    'Estimate',
    'Spent',
    'Баланс',
    'Проект',
  ]);

  // === 4. ЗАПИСЫВАЕМ ЗАДАЧИ ===
  for (final entry in byDay.entries) {
    final day = entry.key;
    for (final timer in entry.value) {
      final balance = timer.estimate - (timer.durationLeft ?? Duration.zero);
      final balanceText = balance > Duration.zero 
        ? '+${_formatDuration(balance)}'  // Свободное время
        : '${_formatDuration(balance)}';  // Задолженность
      
      sheet.appendRow([
        day,
        timer.name,
        timer.isComplete ? '✅' : '⏳',
        _formatDuration(timer.estimate),
        _formatDuration(timer.durationLeft ?? Duration.zero),
        balanceText,
        timer.project ?? '',
      ]);
    }
  }

  // === 5. ИТОГИ ===
  final totalEstimate = filtered.fold<Duration>(
    Duration.zero,
    (sum, t) => sum + t.estimate
  );
  final totalSpent = filtered.fold<Duration>(
    Duration.zero,
    (sum, t) => sum + (t.durationLeft ?? Duration.zero)
  );
  final totalBalance = totalEstimate - totalSpent;

  sheet.appendRow([]);
  sheet.appendRow([
    'ИТОГО',
    '',
    '',
    _formatDuration(totalEstimate),
    _formatDuration(totalSpent),
    totalBalance > Duration.zero 
      ? '+${_formatDuration(totalBalance)}' 
      : _formatDuration(totalBalance),
    '',
  ]);

  // ... сохранение файла ...
}
```

---

### 6. Добавить методы в ObjectBoxService ✅

**Файл:** `lib/services/objectbox_service.dart`

```dart
/// Получить текущий рабочий день
WorkDay? getCurrentWorkDay() {
  final today = DateTime.now().startOfDay;
  final days = workDayBox.query().build();
  final result = days.where((d) => 
    d.createToDate.startOfDay == today
  ).firstOrNull;
  return result;
}

/// Получить предыдущий рабочий день
WorkDay? getPreviousWorkDay(DateTime date) {
  final days = workDayBox.query().build();
  final result = days.where((d) => 
    d.createToDate.startOfDay.isBefore(date.startOfDay)
  ).toList()
    ..sort((a, b) => b.createToDate.compareTo(a.createToDate));
  
  return result.firstOrNull;
}

/// Сохранить рабочий день
void putWorkDay(WorkDay day) {
  workDayBox.put(day);
}
```

---

### 7. Обновить Telegram бот ✅

**Файл:** `lib/services/telegram_bot_service.dart`

**Добавить команду `/day`:**

```dart
_bot!.command('day', (ctx) async {
  final day = timeTracker.currentWorkDay;
  if (day == null) {
    await ctx.reply('ℹ️ Рабочий день ещё не начат');
    return;
  }

  final balance = day.balance;
  final balanceText = balance > Duration.zero
    ? '❌ Задолженность: ${_formatDuration(balance)}'
    : balance < Duration.zero
      ? '✅ Свободное время: ${_formatDuration(-balance)}'
      : '⚖️ Баланс';

  await ctx.reply(
    '📊 *Рабочий день*\n\n'
    '📅 Дата: ${day.createToDate.toLocal().toString().split(' ').first}\n'
    '⏱ Estimate: ${_formatDuration(day.totalEstimate)}\n'
    '🕐 Spent: ${_formatDuration(day.totalSpent)}\n'
    '📥 С прошлого дня: ${_formatDuration(day.prevWorkTime)}\n'
    '📤 Перенос на завтра: ${_formatDuration(day.carriedOver)}\n\n'
    '*$balanceText*',
    parseMode: ParseMode.markdown,
  );
});
```

---

### 8. Обновить UI компоненты ✅

**Файл:** `lib/screens/dashboard_screen.dart`

**Обновить отображение:**

```dart
// Вместо:
Text('${_formatDuration(Duration(seconds: widget.timeTrackerService.freeSeconds))}')

// Использовать:
Text('${_formatDuration(Duration(seconds: widget.timeTrackerService.freeSeconds))}')

// Добавить отображение переноса:
if (widget.timeTrackerService.currentWorkDay?.carriedOver > Duration.zero) ...[
  Text(
    '📤 Перенос на завтра: ${_formatDuration(widget.timeTrackerService.currentWorkDay!.carriedOver)}',
    style: TextStyle(color: Colors.orange.shade400),
  ),
]
```

---

---

## 🔧 Технические детали

### 9. Обновить BotSettings — настройки рабочего дня и звуки ✅

**Файл:** `lib/models/bot_settings.dart`

**Добавить поля:**

```dart
class BotSettings {
  // ... существующие поля ...
  
  // === НАСТРОЙКИ РАБОЧЕГО ДНЯ ===
  int workDayStartHour = 11;              // Время старта (по умолчанию 11:00)
  int workDayDurationHours = 8;           // Продолжительность (по умолчанию 8 часов)
  bool autoStartDay = true;               // Авто-старт дня
  bool autoStopDay = true;                // Авто-стоп дня
  
  // === ЗВУКОВЫЕ УВЕДОМЛЕНИЯ ===
  String? dayStartSoundPath;              // Путь к MP3: старт дня
  String? dayEndSoundPath;                // Путь к MP3: завершение дня
  String? taskEndingSoonSoundPath;        // Путь к MP3: окончание задачи (<60 сек)
  int taskEndingSoonSeconds = 60;         // За сколько секунд предупреждать
  
  // === СЕРИАЛИЗАЦИЯ ===
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    // ... существующие поля ...
    
    // Настройки рабочего дня
    await prefs.setInt('work_day_start_hour', workDayStartHour);
    await prefs.setInt('work_day_duration_hours', workDayDurationHours);
    await prefs.setBool('auto_start_day', autoStartDay);
    await prefs.setBool('auto_stop_day', autoStopDay);
    
    // Звуковые уведомления
    if (dayStartSoundPath != null) {
      await prefs.setString('day_start_sound', dayStartSoundPath!);
    }
    if (dayEndSoundPath != null) {
      await prefs.setString('day_end_sound', dayEndSoundPath!);
    }
    if (taskEndingSoonSoundPath != null) {
      await prefs.setString('task_ending_soon_sound', taskEndingSoonSoundPath!);
    }
    await prefs.setInt('task_ending_soon_seconds', taskEndingSoonSeconds);
  }
  
  static Future<BotSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BotSettings(
      // ... существующие поля ...
      
      // Настройки рабочего дня
      workDayStartHour: prefs.getInt('work_day_start_hour') ?? 11,
      workDayDurationHours: prefs.getInt('work_day_duration_hours') ?? 8,
      autoStartDay: prefs.getBool('auto_start_day') ?? true,
      autoStopDay: prefs.getBool('auto_stop_day') ?? true,
      
      // Звуковые уведомления
      dayStartSoundPath: prefs.getString('day_start_sound'),
      dayEndSoundPath: prefs.getString('day_end_sound'),
      taskEndingSoonSoundPath: prefs.getString('task_ending_soon_sound'),
      taskEndingSoonSeconds: prefs.getInt('task_ending_soon_seconds') ?? 60,
    );
  }
}
```

---

### 10. Обновить логику авто-старта/стопа дня ✅

**Файл:** `lib/services/time_tracker_service.dart`

**Добавить проверку авто-старта:**

```dart
void _subscribeToGlobalTimer() {
  if (_timerListener != null) return;
  
  _timerListener = () {
    _checkDayRollover();
    _checkAutoStartDay();      // ← НОВОЕ: авто-старт
    _checkAutoStopDay();       // ← НОВОЕ: авто-стоп
    _checkTaskEndingSoon();    // ← НОВОЕ: окончание задачи
    notifyListeners();
  };
  
  GlobalTimer().addListener(_timerListener!);
}

/// Проверка авто-старта дня (в 11:00)
void _checkAutoStartDay() {
  if (!_settings.autoStartDay) return;
  if (currentWorkDay?.startWorkDateTime != null) return; // Уже начат
  
  final now = DateTime.now();
  final startHour = _settings.workDayStartHour;
  
  // Если текущий час == час старта и день ещё не начат
  if (now.hour == startHour && now.minute == 0) {
    _log.info('Auto-starting work day at $startHour:00');
    startWorkDay();
    _playDayStartSound();
  }
}

/// Проверка авто-стопа дня (через 8 часов после старта)
void _checkAutoStopDay() {
  if (!_settings.autoStopDay) return;
  if (currentWorkDay?.startWorkDateTime == null) return;
  if (currentWorkDay?.endWorkDateTime != null) return; // Уже завершён
  
  final now = DateTime.now();
  final start = currentWorkDay!.startWorkDateTime!;
  final duration = _settings.workDayDurationHours;
  
  // Если прошло 8 часов с начала дня
  if (now.difference(start).inHours >= duration) {
    _log.info('Auto-stopping work day after $duration hours');
    _endWorkDay(isSoft: true);
    _playDayEndSound();
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
      // Задача скоро закончится
      _playTaskEndingSoonSound();
    }
  }
}

/// Воспроизведение звука старта дня
void _playDayStartSound() {
  if (_settings.dayStartSoundPath != null) {
    GlobalTimer().playCustomSound(_settings.dayStartSoundPath!);
  } else {
    GlobalTimer().playTimeUpSound(); // Звук по умолчанию
  }
}

/// Воспроизведение звука завершения дня
void _playDayEndSound() {
  if (_settings.dayEndSoundPath != null) {
    GlobalTimer().playCustomSound(_settings.dayEndSoundPath!);
  } else {
    GlobalTimer().playTimeUpSound(); // Звук по умолчанию
  }
}

/// Воспроизведение звука окончания задачи
void _playTaskEndingSoonSound() {
  if (_settings.taskEndingSoonSoundPath != null) {
    GlobalTimer().playCustomSound(_settings.taskEndingSoonSoundPath!);
  } else {
    GlobalTimer().playTimeUpSound(); // Звук по умолчанию
  }
}
```

---

### 11. Обновить SettingsScreen — настройки дня и звуки ✅

**Файл:** `lib/screens/settings_screen.dart`

**Добавить секции:**

```dart
// === НАСТРОЙКИ РАБОЧЕГО ДНЯ ===
_SettingsSection(
  title: 'Рабочий день',
  children: [
    SwitchListTile(
      title: const Text('Авто-старт дня'),
      subtitle: const Text('Начинать день автоматически в указанное время'),
      value: _settings.autoStartDay,
      onChanged: (value) {
        setState(() => _settings.autoStartDay = value);
      },
    ),
    SwitchListTile(
      title: const Text('Авто-стоп дня'),
      subtitle: const Text('Завершать день автоматически через 8 часов'),
      value: _settings.autoStopDay,
      onChanged: (value) {
        setState(() => _settings.autoStopDay = value);
      },
    ),
    ListTile(
      title: const Text('Время старта'),
      subtitle: Text('${_settings.workDayStartHour}:00'),
      trailing: DropdownButton<int>(
        value: _settings.workDayStartHour,
        items: List.generate(12, (i) => i + 8) // 8:00 - 19:00
            .map((h) => DropdownMenuItem(value: h, child: Text('$h:00')))
            .toList(),
        onChanged: (value) {
          setState(() => _settings.workDayStartHour = value!);
        },
      ),
    ),
    ListTile(
      title: const Text('Продолжительность'),
      subtitle: Text('${_settings.workDayDurationHours} часов'),
      trailing: DropdownButton<int>(
        value: _settings.workDayDurationHours,
        items: [4, 6, 8, 10, 12]
            .map((h) => DropdownMenuItem(value: h, child: Text('$h ч')))
            .toList(),
        onChanged: (value) {
          setState(() => _settings.workDayDurationHours = value!);
        },
      ),
    ),
  ],
),

// === ЗВУКОВЫЕ УВЕДОМЛЕНИЯ ===
_SettingsSection(
  title: 'Звуковые уведомления',
  children: [
    ListTile(
      title: const Text('Старт дня'),
      subtitle: Text(_settings.dayStartSoundPath ?? 'Звук по умолчанию'),
      trailing: IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: false,
          );
          if (result != null) {
            setState(() {
              _settings.dayStartSoundPath = result.files.single.path;
            });
          }
        },
      ),
    ),
    ListTile(
      title: const Text('Завершение дня'),
      subtitle: Text(_settings.dayEndSoundPath ?? 'Звук по умолчанию'),
      trailing: IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: false,
          );
          if (result != null) {
            setState(() {
              _settings.dayEndSoundPath = result.files.single.path;
            });
          }
        },
      ),
    ),
    ListTile(
      title: const Text('Окончание задачи'),
      subtitle: Text(_settings.taskEndingSoonSoundPath ?? 'Звук по умолчанию'),
      trailing: IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: false,
          );
          if (result != null) {
            setState(() {
              _settings.taskEndingSoonSoundPath = result.files.single.path;
            });
          }
        },
      ),
    ),
    ListTile(
      title: const Text('Предупреждать за'),
      subtitle: Text('${_settings.taskEndingSoonSeconds} сек'),
      trailing: DropdownButton<int>(
        value: _settings.taskEndingSoonSeconds,
        items: [30, 60, 120, 300]
            .map((s) => DropdownMenuItem(value: s, child: Text('$s сек')))
            .toList(),
        onChanged: (value) {
          setState(() => _settings.taskEndingSoonSeconds = value!);
        },
      ),
    ),
  ],
),
```

---

### 12. Обновить GlobalTimer — поддержка custom звуков ✅

**Файл:** `lib/utils/global_timer.dart`

**Добавить метод:**

```dart
/// Воспроизвести пользовательский звук
Future<void> playCustomSound(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      _log.warn('Sound file not found: $filePath');
      playTimeUpSound(); // Fallback
      return;
    }
    
    // Используем audioplayers для воспроизведения
    final player = AudioPlayer();
    await player.play(DeviceFileSource(filePath));
  } catch (e) {
    _log.error('Error playing custom sound: $e');
    playTimeUpSound(); // Fallback
  }
}
```

---

## 🔧 Технические детали

### Миграция данных

```dart
// В objectbox_service.dart
@override
void init() {
  store = openDatabase();
  
  // Обновляем версию схемы
  // ObjectBox автоматически обновит схему при изменении @Entity
}
```

### Тестирование

**Сценарий 1: Завершение дня с незавершённой задачей**
```
Дано:
- Задача: estimate = 1h, spent = 30m (не завершена)
- День завершается

Ожидаемо:
- totalEstimate = 1h
- totalSpent = 30m
- carriedOver = 30m (перенос на завтра)
- balance = 0 (нет задолженности)
```

**Сценарий 2: Завершение дня с перерасходом**
```
Дано:
- Задача: estimate = 1h, spent = 1h 30m (не завершена)
- День завершается

Ожидаемо:
- totalEstimate = 1h
- totalSpent = 1h 30m
- carriedOver = 1h 30m (перенос на завтра)
- balance = 30m (задолженность)
```

**Сценарий 3: Новый день с переносом**
```
Дано:
- Предыдущий день: carriedOver = 30m
- Новый день начинается

Ожидаемо:
- prevWorkTime = 30m
- totalEstimate = 0 (пока нет задач)
- balance = -30m (свободное время = 30m)
```

---

## 📊 Приоритеты

1. **Высокий:** Обновление модели WorkDay (задача 1)
2. **Высокий:** Логика остановки дня с переносом (задача 2)
3. **Высокий:** Логика нового дня (задача 3)
4. **Высокий:** Вычисляемые поля сервиса (задача 4)
5. **Высокий:** Настройки рабочего дня и звуки (задача 9)
6. **Высокий:** Авто-старт/стоп дня (задача 10)
7. **Средний:** ObjectBox методы (задача 6)
8. **Средний:** GlobalTimer custom sounds (задача 12)
9. **Низкий:** Экспорт отчётов (задача 5)
10. **Низкий:** SettingsScreen настройки (задача 11)
11. **Низкий:** Telegram бот и UI (задачи 7-8)

---

## ✅ Проверка логики

### Формулы:

**Баланс дня:**
```
balance = (totalSpent + prevWorkTime) - totalEstimate

Если balance > 0: задолженность (перерасход)
Если balance < 0: свободное время (экономия)
Если balance = 0: баланс
```

**Перенос на следующий день:**
```
carriedOver = totalSpent - totalEstimate
Если carriedOver > 0: переносим затраченное время
Если carriedOver <= 0: нет переноса
```

**Свободное время:**
```
freeTime = estimate - spent
Если spent < estimate: есть свободное время
Если spent >= estimate: нет свободного времени
```

**Задолженность:**
```
debt = spent - estimate
Если spent > estimate: есть задолженность
Если spent <= estimate: нет задолженности
```

---

## ✅ Definition of Done

- [ ] Модель WorkDay обновлена (добавлены totalEstimate, totalSpent, carriedOver)
- [ ] Остановка дня суммирует estimate/spent всех задач
- [ ] Перенос времени = spent - estimate (если > 0)
- [ ] Новый день получает prevWorkTime из предыдущего
- [ ] balance показывает задолженность (>0) или свободное время (<0)
- [ ] freeSeconds/debtSeconds вычисляются из баланса
- [ ] Экспорт фильтрует по дате старта
- [ ] UI отображает перенос и баланс
- [ ] Telegram бот показывает баланс дня
- [ ] BotSettings имеет настройки рабочего дня (старт, длительность, авто-старт/стоп)
- [ ] BotSettings имеет настройки звуков (старт дня, завершение дня, окончание задачи)
- [ ] Авто-старт дня в указанное время (по умолчанию 11:00)
- [ ] Авто-стоп дня через указанную длительность (по умолчанию 8 часов)
- [ ] Звуковое уведомление при старте дня
- [ ] Звуковое уведомление при завершении дня
- [ ] Звуковое уведомление при окончании задачи (<60 сек)
- [ ] SettingsScreen имеет настройки рабочего дня и звуков
- [ ] GlobalTimer поддерживает воспроизведение custom MP3 файлов

---

## 📝 Примеры использования

### Пример 1: Быстрое завершение задачи (мотивация)

```
Задача: estimate = 2h
Фактически: spent = 1h 30m

Результат:
- balance = -30m (свободное время)
- carriedOver = 0 (нет переноса)
- ✅ Успех: закончил быстрее на 30 минут
```

### Пример 2: Превышение времени (предупреждение)

```
Задача: estimate = 2h
Фактически: spent = 3h

Результат:
- balance = +1h (задолженность)
- carriedOver = 1h (перенос на завтра)
- ⚠️ Предупреждение: перерасход 1 час
```

### Пример 3: Несколько задач за день

```
Задача 1: estimate = 2h, spent = 2h ✅
Задача 2: estimate = 1h, spent = 30m ⏳
Задача 3: estimate = 1h, spent = 0m (не начата)

Результат:
- totalEstimate = 4h
- totalSpent = 2h 30m
- balance = -1h 30m (свободное время)
- carriedOver = 0 (spent < estimate)
- ✅ Есть запас времени на завершение Задачи 2
```

---

**Статус:** ✅ Готово к реализации

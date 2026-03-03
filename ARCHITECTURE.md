# Архитектура приложения

## Общая схема

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Dashboard  │  │   History   │  │   Settings  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Projects   │  │  Chat Log   │  │Time Tracker │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Services Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │TimeTracker   │  │  Telegram    │  │   Qwen CLI   │          │
│  │  Service     │  │    Bot       │  │   Service    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Project    │  │    Export    │  │    Tray      │          │
│  │  Service     │  │   Service    │  │   Service    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       Data Layer                                 │
│  ┌────────────────────────────────────────────────────┐         │
│  │           ObjectBox Database (Box<T>)              │         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │         │
│  │  │  Timer   │  │ WorkDay  │  │ Project  │        │         │
│  │  └──────────┘  └──────────┘  └──────────┘        │         │
│  └────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

## Компоненты

### UI Layer

#### DashboardScreen
- Главный экран приложения
- Отображает:
  - Круговой прогресс рабочего дня
  - Статистику (сегодня, таймеры, проект)
  - Форму добавления задачи
  - Список активных таймеров
  - Кнопки управления ботом
  - Quick Actions (History, Projects)

#### TimeTrackerScreen
- Управление таймерами
- Добавление/редактирование задач
- Запуск/пауза/завершение

#### HistoryScreen
- История всех таймеров
- Фильтрация по дате
- Экспорт в Excel

#### ProjectsScreen
- Список проектов
- Активный проект (с сессией Qwen)
- Переключение между проектами

#### ChatLogScreen
- История сообщений бота
- Отправка команд в Qwen

#### SettingsScreen
- Настройки Telegram бота
- Настройки Qwen CLI
- Настройки приложения

### Services Layer

#### TimeTrackerService
```dart
class TimeTrackerService extends ChangeNotifier {
  List<Timer> timers;
  WorkDay? currentWorkDay;
  
  Future<Timer> addTimer(...);
  Future<void> startTimer(Timer timer);
  Future<void> stopTimer(Timer timer);
  Future<void> completeTimer(Timer timer);
  void startWorkDay();
  void endWorkDay();
}
```

#### TelegramBotService
```dart
class TelegramBotService extends ChangeNotifier {
  Set<String> allowedUserIds;
  bool isRunning;
  
  Future<void> start(String token);
  Future<void> stop();
  Future<void> sendMessage(String text);
}
```

#### QwenCodeService
```dart
class QwenCodeService extends ChangeNotifier {
  String? currentSessionId;
  bool isRunning;
  
  Future<void> configure(...);
  Future<void> startSession();
  Future<void> killSession();
}
```

#### ObjectBoxService
```dart
class ObjectBoxService {
  Store store;
  Box<Timer> timerBox;
  Box<WorkDay> workDayBox;
  Box<Project> projectBox;
  
  Future<int> putTimer(Timer timer);
  void removeTimer(Timer timer);
  List<Timer> getAllTimers();
}
```

### Data Layer

#### Timer (Entity)
```dart
@Entity()
class Timer {
  @Id() int id;
  String name;
  String? project;
  String? branchName;
  String? url;
  DateTime createdAt;
  DateTime? startDateTime;
  DateTime? endDateTime;
  bool isComplete;
  int estimateMilliseconds;
  int durationLeftMilliseconds;
}
```

#### WorkDay (Entity)
```dart
@Entity()
class WorkDay {
  @Id() int id;
  int debtOfTimeMilliseconds;
  int freeTimeMilliseconds;
  int prevWorkTimeMilliseconds;
  DateTime createToDate;
  DateTime? startWorkDateTime;
  DateTime? endWorkDateTime;
}
```

#### Project (Entity)
```dart
@Entity()
class Project {
  @Id() int id;
  String name;
  String? workingDirectory;
  String? sessionId;
  bool isActive;
}
```

## Глобальный таймер

```dart
class GlobalTimer extends ChangeNotifier {
  Timer? _timer;  // Тикает каждую секунду
  
  void initialize() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      dayListener?.call();      // Для MultiLevelCircularProgress
      notifyListeners();         // Для TimerItem
    });
  }
}
```

### Поток обновления

```
GlobalTimer (1 сек)
    ↓
    ├─→ dayListener → MultiLevelCircularProgress.calcTime()
    │                    ├─→ _leftSeconds (время дня)
    │                    └─→ _spentSeconds (сумма таймеров)
    │
    └─→ notifyListeners() → TimerItem.setState()
                             └─→ durationLeft += 1 сек
```

## Логика расчётов

### Рабочий день
```
_totalSeconds = 28800 (8 часов)
_leftSeconds = DateTime.now() - startWorkDateTime
_curSeconds = isOffDay ? _totalSeconds : _leftSeconds
```

### Таймеры
```
_spentSeconds = Σ estimate (завершённые) + Σ durationLeft (активные)
               - prevWorkTime (из предыдущих дней)
```

### Свободное время
```
Free time = _curSeconds - _spentSeconds  (если _spentSeconds < _curSeconds)
Lack of time = _spentSeconds - _curSeconds (если _spentSeconds >= _curSeconds)
```

## Взаимодействие с Telegram

```
Telegram API
    ↓
Televerse (Bot Service)
    ↓
Allowed User IDs проверка
    ↓
Commands:
  /start → botService.start()
  /stop → botService.stop()
  /status → qwenService.currentSessionId
  /chat → qwenService.sendMessage()
```

## Интеграция с Qwen CLI

```
QwenCodeService
    ↓
Process.run (CLI executable)
    ↓
Working Directory
    ↓
Session ID (сохраняется в Project)
```

## Системный трей

```
TrayService
    ↓
System Tray Icon
    ↓
Context Menu:
  - Start Bot
  - Stop Bot
  - Show Window
  - Quit
```

## Экспорт в Excel

```
ExportService.openExcel(List<Timer>)
    ↓
Excel.createExcel()
    ↓
Sheet.appendRow(timer.toExportMap())
    ↓
File.writeAsBytes()
    ↓
OpenFile.open(path)
```

## Безопасность

### Telegram
- Token хранится в SharedPreferences
- Allowed User IDs проверяются перед выполнением команд

### ObjectBox
- Локальное хранение без шифрования
- Изолированное хранилище приложения

## Производительность

### Оптимизация
- Сохранение таймеров каждые 10 секунд
- Обновление UI только для запущенных таймеров
- ObjectBox индексы для частых запросов

### Потребление памяти
- ~300-400 MB в рабочем режиме
- ObjectBox store закрывается при выходе

## Расширяемость

### Добавление новой модели
1. Создать класс с `@Entity()`
2. Запустить `build_runner`
3. Добавить Box в ObjectBoxService

### Добавление нового экрана
1. Создать StatefulWidget в screens/
2. Добавить в SidebarItem enum
3. Добавить case в AppShell._buildScreen()

### Добавление сервиса
1. Создать класс в services/
2. Инициализировать в AppShell.initState()
3. Вызвать dispose() в AppShell.dispose()

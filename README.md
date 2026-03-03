# Qwen Time Tracker

**Единое приложение для отслеживания времени + Telegram бот с интеграцией Qwen CLI**

Приложение объединяет функциональность двух проектов:
- **bbt_time_tracker** — трекер времени с круговым прогрессом рабочего дня
- **remote_qwen** — Telegram бот для управления Qwen CLI

---

## 📋 Возможности

### Трекер времени
- ✅ **Учёт рабочего дня** — 8-часовой рабочий день с визуальным прогрессом
- ✅ **Таймеры задач** — запуск/пауза/завершение задач с подсчётом времени
- ✅ **Оценка времени** — указывайте планируемое время задачи (estimate)
- ✅ **Прогресс-бар** — визуальное отображение выполнения задачи
- ✅ **Свободное/Превышенное время** — показывает разницу между планом и фактом
- ✅ **История** — сохранение всех таймеров в базе данных ObjectBox
- ✅ **Excel экспорт** — выгрузка отчёта в Excel

### Telegram бот
- ✅ **Управление Qwen CLI** — запуск/остановка бота из Telegram
- ✅ **Интеграция с проектами** — привязка сессий к проектам
- ✅ **Чат-лог** — просмотр истории сообщений бота
- ✅ **Настройки** — настройка токена, разрешённых пользователей, автозапуска

### Дополнительно
- ✅ **Мульти-оконный режим** — работа в системном трее
- ✅ **Аудио-уведомления** — звук начала/окончания рабочего дня
- ✅ **Автостарт дня** — автоматический старт в 11:00
- ✅ **Тёмная тема** — современный дизайн в стиле Cyberpunk

---

## 🏗️ Архитектура

```
lib/
├── models/           # Модели данных
│   ├── timer.dart    # Таймер задач (Entity ObjectBox)
│   ├── work_day.dart # Рабочий день (Entity ObjectBox)
│   ├── project.dart  # Проект с сессией Qwen
│   ├── chat_message.dart
│   └── bot_settings.dart
├── services/         # Бизнес-логика
│   ├── objectbox_service.dart      # База данных ObjectBox
│   ├── time_tracker_service.dart   # Логика таймеров
│   ├── telegram_bot_service.dart   # Telegram бот
│   ├── qwen_code_service.dart      # Qwen CLI интеграция
│   ├── project_service.dart        # Управление проектами
│   ├── export_service.dart         # Excel экспорт
│   └── tray_service.dart           # Системный трей
├── screens/          # Экраны приложения
│   ├── dashboard_screen.dart       # Главная (таймеры + статистика)
│   ├── history_screen.dart         # История таймеров
│   ├── chat_log_screen.dart        # Чат бота
│   ├── projects_screen.dart        # Проекты
│   └── settings_screen.dart        # Настройки
├── widgets/          # UI компоненты
│   ├── day_progress.dart           # Круговой прогресс дня
│   ├── timer_item.dart             # Карточка таймера
│   ├── blinking_card.dart          # Мигающая карточка
│   └── sidebar.dart                # Боковое меню
└── utils/            # Утилиты
    ├── global_timer.dart           # Глобальный таймер (1 сек)
    ├── number.dart                 # Форматирование времени
    └── date_ext.dart               # Расширения DateTime
```

---

## 🚀 Установка

### Требования
- Flutter SDK >= 3.8.0
- Windows 10/11
- Qwen CLI (опционально, для бота)

### Шаги установки

1. **Клонирование репозитория**
   ```bash
   cd C:\Users\Nikitir\Desktop\Projects\qwen_time_tracker
   ```

2. **Установка зависимостей**
   ```bash
   flutter pub get
   ```

3. **Генерация ObjectBox моделей**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Запуск приложения**
   ```bash
   flutter run -d windows
   ```

5. **Сборка релизной версии**
   ```bash
   flutter build windows --release
   ```

---

## ⚙️ Настройка

### Telegram бот
1. Откройте **Settings** в приложении
2. Укажите **Telegram Bot Token** (получите у @BotFather)
3. Добавьте **Allowed User IDs** (ваш Telegram ID через запятую)
4. Включите **Auto Start Bot** (опционально)

### Qwen CLI
1. Укажите путь к **Qwen CLI executable**
2. Укажите **Working Directory** (папка проекта)
3. Опционально: включите **YOLO Mode**

### Рабочий день
- **Старт дня** — кнопка "Start Day" на Dashboard
- **Авто-старт** — в 11:00 (если включено)
- **Длительность** — 8 часов (28800 секунд)
- **Звуки** — `assets/mp3/good_morning_vietnam.mp3` (старт), `assets/mp3/japanese_attention.mp3` (окончание)

---

## 📊 Как это работает

### Логика таймера
```
durationLeft — прошедшее время (увеличивается каждую секунду)
estimate     — запланированное время
timeLeft     — оставшееся время (estimate - durationLeft)
overTime     — превышение (durationLeft - estimate)
```

### Расчёт свободного времени
```
_leftSeconds  — время с начала рабочего дня
_spentSeconds — сумма estimate завершённых + durationLeft активных задач

Free time     = _curSeconds - _spentSeconds (если _spentSeconds < _curSeconds)
Lack of time  = _spentSeconds - _curSeconds (если _spentSeconds >= _curSeconds)
```

### Сохранение данных
- **Таймеры** — ObjectBox Box<Timer>
- **Рабочие дни** — ObjectBox Box<WorkDay>
- **Проекты** — ObjectBox Box<Project>
- **Сохранение** — каждые 10 секунд для активных таймеров

---

## 🎯 Структура базы данных (ObjectBox)

### Timer
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
  int durationLeftMilliseconds;  // Прошедшее время
}
```

### WorkDay
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

### Project
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

---

## 🔧 Команды разработки

```bash
# Анализ кода
flutter analyze

# Запуск с отладкой
flutter run -d windows

# Сборка релиза
flutter build windows --release

# Генерация ObjectBox
flutter pub run build_runner build --delete-conflicting-outputs

# Очистка
flutter clean

# Тесты
flutter test
```

---

## 📦 Зависимости

### Основные
- `objectbox` + `objectbox_flutter_libs` — база данных
- `televerse` — Telegram Bot API
- `audioplayers` — аудио уведомления
- `window_manager` — управление окном
- `tray_manager` — системный трей

### UI
- `flutter_form_builder` + `form_builder_validators` — формы
- `flutter_swipe_action_cell` — swipe действия
- `reorderable_tabbar` — перетаскиваемые табы

### Утилиты
- `excel` + `open_file` — экспорт в Excel
- `share_plus` — partage файлов
- `url_launcher` + `linkable` — ссылки
- `file_picker` — выбор файлов
- `process_run` — запуск процессов (Qwen CLI)

---

## 🐛 Известные проблемы

- Аудио-предупреждения могут срабатывать с задержкой
- При быстром переключении между таймерами возможна рассинхронизация UI
- Excel экспорт может не работать без установленного Microsoft Office

---

## 📝 Changelog

### v1.0.0
- ✅ Объединение bbt_time_tracker и remote_qwen
- ✅ ObjectBox база данных для таймеров
- ✅ Глобальный таймер (обновление каждую секунду)
- ✅ Круговой прогресс рабочего дня
- ✅ Прогресс-бары для таймеров
- ✅ Telegram бот с управлением Qwen CLI
- ✅ Экспорт в Excel
- ✅ Иконка приложения

---

## 👥 Авторы

- Разработчик: [Ваше имя]
- На основе проектов **bbt_time_tracker** и **remote_qwen**

---

## 📄 Лицензия

MIT License — свободное использование с указанием авторства.

---

## 🔗 Ссылки

- [Flutter Documentation](https://docs.flutter.dev/)
- [ObjectBox Documentation](https://docs.objectbox.io/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

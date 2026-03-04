/// Константы приложения Qwen Time Tracker
class AppConstants {
  AppConstants._();

  // ═══════════════════════════════════════════════════════════════
  // TELEGRAM BOT
  // ═══════════════════════════════════════════════════════════════
  
  /// Лимит сообщений в минуту от одного пользователя
  static const int telegramRateLimitPerMinute = 10;
  
  /// Минимальный интервал между редактированиями сообщения (Telegram rate limit)
  static const Duration telegramEditInterval = Duration(milliseconds: 1500);
  
  /// Максимальная длина preview сообщения
  static const int telegramPreviewMaxLength = 4000;
  
  /// Максимальная длина сообщения Telegram
  static const int telegramMaxMessageLength = 4096;

  // ═══════════════════════════════════════════════════════════════
  // TIMER / TASKS
  // ═══════════════════════════════════════════════════════════════
  
  /// Estimate по умолчанию для новой задачи
  static const Duration defaultTaskEstimate = Duration(minutes: 15);
  
  /// Минимальный estimate задачи (1 минута)
  static const Duration minTaskEstimate = Duration(minutes: 1);
  
  /// Максимальный estimate задачи (24 часа)
  static const Duration maxTaskEstimate = Duration(hours: 24);

  // ═══════════════════════════════════════════════════════════════
  // WORK DAY
  // ═══════════════════════════════════════════════════════════════
  
  /// Время напоминания о завершении дня (19:00)
  static const Duration workDayReminderTime = Duration(hours: 19);
  
  /// Стандартная длительность рабочего дня (8 часов)
  static const Duration standardWorkDay = Duration(hours: 8);

  // ═══════════════════════════════════════════════════════════════
  // QWEN CODE
  // ═══════════════════════════════════════════════════════════════
  
  /// Максимальная длина ответа Qwen
  static const int qwenResponseMaxLen = 3500;
  
  /// Таймаут ожидания ответа от Qwen (5 минут)
  static const Duration qwenResponseTimeout = Duration(minutes: 5);
  
  /// Интервал авто-сохранения сессии (10 минут)
  static const Duration qwenSessionAutoSaveInterval = Duration(minutes: 10);

  // ═══════════════════════════════════════════════════════════════
  // UI / UX
  // ═══════════════════════════════════════════════════════════════
  
  /// Стандартная анимация (мс)
  static const Duration defaultAnimationDuration = Duration(milliseconds: 200);
  
  /// Длительность показа SnackBar
  static const Duration defaultSnackBarDuration = Duration(seconds: 3);
  
  /// Длительность показа ошибки
  static const Duration errorSnackBarDuration = Duration(seconds: 5);
  
  /// Размер шрифта по умолчанию
  static const double defaultFontSize = 14.0;
  
  /// Размер шрифта для заголовков
  static const double titleFontSize = 18.0;
  
  /// Размер шрифта для кнопок
  static const double buttonFontSize = 16.0;

  // ═══════════════════════════════════════════════════════════════
  // FILE / PATHS
  // ═══════════════════════════════════════════════════════════════
  
  /// Директория конфигурации Qwen Code
  static const String qwenConfigDir = r'C:\Users\Nikitir\.qwen';
  
  /// Имя файла настроек Qwen Code
  static const String qwenSettingsFile = 'settings.json';
  
  /// Расширение для экспорта Excel
  static const String excelFileExtension = 'xlsx';

  // ═══════════════════════════════════════════════════════════════
  // IPC / CLI
  // ═══════════════════════════════════════════════════════════════
  
  /// Таймаут ожидания ответа от IPC (секунды)
  static const Duration ipcResponseTimeout = Duration(seconds: 5);
  
  /// Имя IPC канала
  static const String ipcChannelName = 'qwen_time_tracker_ipc';

  // ═══════════════════════════════════════════════════════════════
  // LOGGING
  // ═══════════════════════════════════════════════════════════════
  
  /// Максимальный размер лог-файла (10 MB)
  static const int maxLogFileSize = 10 * 1024 * 1024;
  
  /// Количество хранимых лог-файлов
  static const int maxLogFileCount = 5;

  // ═══════════════════════════════════════════════════════════════
  // VALIDATION
  // ═══════════════════════════════════════════════════════════════
  
  /// Минимальная длина имени задачи
  static const int minTaskNameLength = 1;
  
  /// Максимальная длина имени задачи
  static const int maxTaskNameLength = 100;
  
  /// Максимальная длина описания задачи
  static const int maxTaskDescriptionLength = 500;
  
  /// Максимальная длина имени проекта
  static const int maxProjectNameLength = 50;
}

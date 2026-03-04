import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class BotSettings {
  String telegramBotToken;
  List<int> allowedUserIds;
  String qwenCliPath;
  String workingDirectory;
  bool autoStartBot;
  bool launchAtLogin;
  bool useYoloMode;

  // Настройки уведомлений
  bool notifyOnTimerComplete;
  bool notifyOnDayEnd;
  bool notifyOnOvertime;
  int endDayReminderHour;

  // Настройки нейросетей
  String ollamaModel;  // Название модели Ollama
  bool autoStartLocalModel;  // Автозапуск локальной модели при старте
  bool autoStartOllama;  // Автозапуск Ollama сервера при старте

  // === НАСТРОЙКИ РАБОЧЕГО ДНЯ ===
  int workDayStartHour;           // Время старта (по умолчанию 11:00)
  int workDayDurationHours;       // Продолжительность (по умолчанию 8 часов)
  bool autoStartDay;              // Авто-старт дня
  bool autoStopDay;               // Авто-стоп дня

  // === ЗВУКОВЫЕ УВЕДОМЛЕНИЯ ===
  String? dayStartSoundPath;              // Путь к MP3: старт дня
  String? dayEndSoundPath;                // Путь к MP3: завершение дня
  String? taskEndingSoonSoundPath;        // Путь к MP3: окончание задачи (<60 сек)
  int taskEndingSoonSeconds;              // За сколько секунд предупреждать

  BotSettings({
    this.telegramBotToken = '',
    List<int>? allowedUserIds,
    this.qwenCliPath = '',
    String? workingDirectory,
    this.autoStartBot = false,
    this.launchAtLogin = false,
    this.useYoloMode = true,
    this.notifyOnTimerComplete = true,
    this.notifyOnDayEnd = true,
    this.notifyOnOvertime = true,
    this.endDayReminderHour = 19,
    this.ollamaModel = 'qwen2.5-coder:7b-instruct-q4_K_M',
    this.autoStartLocalModel = false,
    this.autoStartOllama = false,
    this.workDayStartHour = 11,
    this.workDayDurationHours = 8,
    this.autoStartDay = true,
    this.autoStopDay = true,
    this.dayStartSoundPath,
    this.dayEndSoundPath,
    this.taskEndingSoonSoundPath,
    this.taskEndingSoonSeconds = 60,
  })  : allowedUserIds = allowedUserIds ?? [],
        workingDirectory = workingDirectory ?? _defaultWorkingDir;

  static String get _defaultWorkingDir {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
  }

  bool get isConfigured =>
      telegramBotToken.isNotEmpty && allowedUserIds.isNotEmpty;

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('telegram_bot_token', telegramBotToken);
    await prefs.setStringList(
      'allowed_user_ids',
      allowedUserIds.map((id) => id.toString()).toList(),
    );
    await prefs.setString('qwen_cli_path', qwenCliPath);
    await prefs.setString('working_directory', workingDirectory);
    await prefs.setBool('auto_start_bot', autoStartBot);
    await prefs.setBool('launch_at_login', launchAtLogin);
    await prefs.setBool('use_yolo_mode', useYoloMode);
    // Настройки уведомлений
    await prefs.setBool('notify_on_timer_complete', notifyOnTimerComplete);
    await prefs.setBool('notify_on_day_end', notifyOnDayEnd);
    await prefs.setBool('notify_on_overtime', notifyOnOvertime);
    await prefs.setInt('end_day_reminder_hour', endDayReminderHour);
    // Настройки нейросетей
    await prefs.setString('ollama_model', ollamaModel);
    await prefs.setBool('auto_start_local_model', autoStartLocalModel);
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
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    return BotSettings(
      telegramBotToken: prefs.getString('telegram_bot_token') ?? '',
      allowedUserIds: (prefs.getStringList('allowed_user_ids') ?? [])
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList(),
      qwenCliPath: prefs.getString('qwen_cli_path') ?? '',
      workingDirectory: prefs.getString('working_directory') ?? home,
      autoStartBot: prefs.getBool('auto_start_bot') ?? false,
      launchAtLogin: prefs.getBool('launch_at_login') ?? false,
      useYoloMode: prefs.getBool('use_yolo_mode') ?? true,
      // Настройки уведомлений
      notifyOnTimerComplete: prefs.getBool('notify_on_timer_complete') ?? true,
      notifyOnDayEnd: prefs.getBool('notify_on_day_end') ?? true,
      notifyOnOvertime: prefs.getBool('notify_on_overtime') ?? true,
      endDayReminderHour: prefs.getInt('end_day_reminder_hour') ?? 19,
      // Настройки нейросетей
      ollamaModel: prefs.getString('ollama_model') ?? 'qwen2.5-coder:7b-instruct-q4_K_M',
      autoStartLocalModel: prefs.getBool('auto_start_local_model') ?? false,
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

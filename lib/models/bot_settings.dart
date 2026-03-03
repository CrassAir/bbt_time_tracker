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
    );
  }
}

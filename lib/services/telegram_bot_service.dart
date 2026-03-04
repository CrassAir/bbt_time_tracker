import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:televerse/televerse.dart';
import 'package:televerse/telegram.dart';
import '../models/chat_message.dart';
import '../models/bot_settings.dart';
import '../utils/duration_formatter.dart';
import 'qwen_code_service.dart';
import 'log_service.dart';
import 'project_service.dart';
import 'time_tracker_service.dart';

class TelegramBotService extends ChangeNotifier {
  Bot? _bot;
  final QwenCodeService qwen;
  final ProjectService? projectService;
  final TimeTrackerService? timeTrackerService;
  Set<int> allowedUserIds;
  bool _isRunning = false;
  int _messageCount = 0;
  final List<ChatMessage> _messages = [];
  final _log = LogService();
  late final io.Directory _mediaDir;
  BotSettings? _settings;

  TelegramBotService({
    required this.qwen,
    this.projectService,
    this.timeTrackerService,
    Set<int>? allowedUserIds,
  }) : allowedUserIds = allowedUserIds ?? {};

  /// Загрузка настроек
  Future<void> loadSettings() async {
    _settings = await BotSettings.load();
  }

  /// Отправить уведомление о завершении таймера
  Future<void> sendTimerCompleteNotification(String taskName, Duration estimate, Duration actual) async {
    if (_settings == null || !_settings!.notifyOnTimerComplete) return;
    if (_bot == null) return;

    final users = _settings!.allowedUserIds;
    for (final userId in users) {
      try {
        await _bot!.api.sendMessage(
          ChatID(userId),
          '⏱ *Таймер завершён*\n\n'
          '📝 Задача: $taskName\n'
          '⏱ План: ${DurationFormatter.format(estimate)}\n'
          '🕐 Факт: ${DurationFormatter.format(actual)}\n'
          '${actual > estimate ? '❌ Превышение: ${DurationFormatter.format(actual - estimate)}' : '✅ Уложились в время!'}',
          parseMode: ParseMode.markdown,
        );
      } catch (e) {
        _log.error('Failed to send timer complete notification: $e');
      }
    }
  }

  /// Отправить уведомление о завершении рабочего дня
  Future<void> sendDayEndNotification(Duration duration, int completedTasks) async {
    if (_settings == null || !_settings!.notifyOnDayEnd) return;
    if (_bot == null) return;

    final users = _settings!.allowedUserIds;
    for (final userId in users) {
      try {
        await _bot!.api.sendMessage(
          ChatID(userId),
          '🏁 *Рабочий день завершён*\n\n'
          '🕐 Длительность: ${DurationFormatter.format(duration)}\n'
          '✅ Завершено задач: $completedTasks\n\n'
          'Хорошего отдыха! 🌙',
          parseMode: ParseMode.markdown,
        );
      } catch (e) {
        _log.error('Failed to send day end notification: $e');
      }
    }
  }

  /// Отправить уведомление о превышении времени задачи
  Future<void> sendOvertimeNotification(String taskName, Duration estimate, Duration actual) async {
    if (_settings == null || !_settings!.notifyOnOvertime) return;
    if (_bot == null) return;

    final users = _settings!.allowedUserIds;
    for (final userId in users) {
      try {
        await _bot!.api.sendMessage(
          ChatID(userId),
          '⚠️ *Превышение времени*\n\n'
          '📝 Задача: $taskName\n'
          '⏱ План: ${DurationFormatter.format(estimate)}\n'
          '🕐 Факт: ${DurationFormatter.format(actual)}\n'
          '❌ Превышение: ${DurationFormatter.format(actual - estimate)}',
          parseMode: ParseMode.markdown,
        );
      } catch (e) {
        _log.error('Failed to send overtime notification: $e');
      }
    }
  }

  /// Отправить напоминание о завершении дня
  Future<void> sendEndDayReminder(List<String> activeTasks) async {
    if (_settings == null || !_settings!.notifyOnDayEnd) return;
    if (_bot == null) return;

    final users = _settings!.allowedUserIds;
    for (final userId in users) {
      try {
        final tasksText = activeTasks.isEmpty 
            ? 'Нет активных задач'
            : activeTasks.map((t) => '• $t').join('\n');
        
        await _bot!.api.sendMessage(
          ChatID(userId),
          '🌆 *Время завершать рабочий день!*\n\n'
          'Сейчас ${_settings!.endDayReminderHour}:00\n\n'
          'Активные задачи:\n${tasksText}\n\n'
          'Завершите задачи и закройте рабочий день. 🏁',
          parseMode: ParseMode.markdown,
        );
      } catch (e) {
        _log.error('Failed to send end day reminder: $e');
      }
    }
  }

  /// Rate limit: max messages per user per minute.
  static const int _rateLimitPerMinute = 10;
  final Map<int, List<DateTime>> _userMessageTimes = {};

  bool get isRunning => _isRunning;
  int get messageCount => _messageCount;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void updateMessage(String id, {String? response, MessageStatus? status}) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      if (response != null) _messages[idx].response = response;
      if (status != null) _messages[idx].status = status;
      notifyListeners();
    }
  }

  /// Send a reply, trying HTML parse mode first, falling back to plain text.
  Future<void> _sendReply(Context ctx, String text) async {
    final htmlText = _markdownToTelegramHtml(text);
    try {
      await ctx.reply(htmlText, parseMode: ParseMode.html);
    } catch (_) {
      try {
        await ctx.reply(text);
      } catch (e) {
        _log.error('Failed to send reply: $e');
      }
    }
  }

  /// Convert Qwen's markdown to Telegram-safe HTML.
  String _markdownToTelegramHtml(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*', dotAll: true),
      (m) => '<b>${_escapeHtml(m.group(1)!)}</b>',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*]+?)\*(?!\*)'),
      (m) => '<i>${_escapeHtml(m.group(1)!)}</i>',
    );

    result = result.replaceAllMapped(
      RegExp(r'```\w*\n?(.*?)```', dotAll: true),
      (m) => '<pre>${_escapeHtml(m.group(1)!)}</pre>',
    );

    result = result.replaceAllMapped(
      RegExp(r'`([^`]+?)`'),
      (m) => '<code>${_escapeHtml(m.group(1)!)}</code>',
    );

    result = _escapeHtmlOutsideTags(result);
    return result;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _escapeHtmlOutsideTags(String text) {
    final tagPattern = RegExp(r'</?(?:b|i|pre|code)>');
    final parts = <String>[];
    var lastEnd = 0;
    for (final match in tagPattern.allMatches(text)) {
      final between = text.substring(lastEnd, match.start);
      parts.add(between.replaceAll('&', '&amp;').replaceAll(RegExp(r'<(?!/?(b|i|pre|code)>)'), '&lt;').replaceAll(RegExp(r'(?<!<(?:/?(?:b|i|pre|code)))>'), '&gt;'));
      parts.add(match.group(0)!);
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      parts.add(remaining.replaceAll('&', '&amp;').replaceAll(RegExp(r'<(?!/?(b|i|pre|code)>)'), '&lt;'));
    }
    return parts.join();
  }

  /// Download a Telegram file to local disk.
  Future<String?> _downloadFile(String fileId, String extension) async {
    try {
      if (!await _mediaDir.exists()) {
        await _mediaDir.create(recursive: true);
      }

      final tgFile = await _bot!.api.getFile(fileId);
      final filePath = tgFile.filePath;
      if (filePath == null) return null;

      final localPath = p.join(
        _mediaDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.$extension',
      );

      final token = _bot!.token;
      final url = 'https://api.telegram.org/file/bot$token/$filePath';

      final result = await io.Process.run(
        'curl', ['-sL', '-o', localPath, url],
        runInShell: true,
      );

      if (result.exitCode == 0 && await io.File(localPath).exists()) {
        _log.info('Downloaded file to $localPath');
        return localPath;
      }
    } catch (e) {
      _log.error('Failed to download file: $e');
    }
    return null;
  }

  /// Known paths where whisper may be installed.
  static const _whisperSearchPaths = [
    'whisper',                                       // in PATH
    'mlx_whisper',                                   // in PATH
    '/opt/homebrew/bin/whisper',                      // brew
    '/usr/local/bin/whisper',                         // brew (Intel)
  ];

  /// Resolve whisper binary — check PATH, then well-known pip locations.
  Future<String?> _findWhisperBin() async {
    // First check standard paths
    for (final cmd in _whisperSearchPaths) {
      final check = await io.Process.run('which', [cmd], runInShell: true);
      if (check.exitCode == 0) return (check.stdout as String).trim();
    }
    // Check pip --user bin for all python versions
    final home = io.Platform.environment['HOME'] ?? '/tmp';
    final userBinDir = io.Directory(p.join(home, 'Library', 'Python'));
    if (await userBinDir.exists()) {
      await for (final entity in userBinDir.list()) {
        if (entity is io.Directory) {
          final whisperPath = p.join(entity.path, 'bin', 'whisper');
          if (await io.File(whisperPath).exists()) return whisperPath;
        }
      }
    }
    return null;
  }

  /// Transcribe a voice message using whisper.
  Future<String?> _transcribeVoice(String oggPath) async {
    final wavPath = oggPath.replaceAll('.ogg', '.wav');

    // Convert ogg → wav (ffmpeg preferred, afconvert fallback)
    var convertResult = await io.Process.run(
      'ffmpeg', ['-i', oggPath, '-ar', '16000', '-ac', '1', wavPath, '-y'],
      runInShell: true,
    );

    if (convertResult.exitCode != 0) {
      convertResult = await io.Process.run(
        'afconvert', ['-f', 'WAVE', '-d', 'LEI16@16000', oggPath, wavPath],
        runInShell: true,
      );
    }

    if (convertResult.exitCode != 0) {
      _log.error('Cannot convert audio: ffmpeg and afconvert both failed');
      return null;
    }

    // Find whisper binary
    final whisperBin = await _findWhisperBin();
    if (whisperBin == null) {
      _log.error('No whisper installation found. '
          'Install: pip3 install --user openai-whisper');
      return null;
    }

    _log.info('Using whisper: $whisperBin');
    final outputDir = p.dirname(wavPath);

    final result = await io.Process.run(
      whisperBin,
      [
        wavPath,
        '--model', 'small',
        '--language', 'ru',
        '--output_format', 'txt',
        '--output_dir', outputDir,
      ],
      runInShell: true,
      environment: io.Platform.environment,
    );

    if (result.exitCode == 0) {
      final txtPath = wavPath.replaceAll('.wav', '.txt');
      if (await io.File(txtPath).exists()) {
        final text = (await io.File(txtPath).readAsString()).trim();
        _log.info('Transcription (${text.length} chars): '
            '${text.substring(0, text.length.clamp(0, 100))}');
        // Cleanup temp files
        try {
          await io.File(wavPath).delete();
          await io.File(txtPath).delete();
        } catch (_) {}
        return text;
      }
      return (result.stdout as String).trim();
    }

    _log.error('Whisper failed (code ${result.exitCode}): '
        '${(result.stderr as String).substring(0, (result.stderr as String).length.clamp(0, 300))}');
    return null;
  }

  Future<void> start(String token) async {
    if (_isRunning) return;

    _log.info('Starting Telegram bot');

    // Загружаем настройки
    await loadSettings();

    try {
      _bot = Bot(token);
      _log.info('Bot instance created');
    } catch (e, st) {
      _log.error('Failed to create Bot: $e\n$st');
      rethrow;
    }

    _messageCount = 0;

    // Register bot commands (non-blocking to avoid startup crash)
    _log.info('Registering bot commands (async)...');
    _bot!.api.setMyCommands([
      BotCommand(command: 'start', description: 'Приветствие и статус'),
      BotCommand(command: 'projects', description: 'Список проектов'),
      BotCommand(command: 'newproject', description: 'Создать проект'),
      BotCommand(command: 'switch', description: 'Переключить проект'),
      BotCommand(command: 'newsession', description: 'Новая сессия'),
      BotCommand(command: 'model', description: 'Переключить модель'),
      BotCommand(command: 'ollama', description: 'Управление Ollama'),
      BotCommand(command: 'compact', description: 'Сжать контекст'),
      BotCommand(command: 'status', description: 'Статус системы'),
      BotCommand(command: 'quota', description: 'Проверить квоту API'),
      BotCommand(command: 'commands', description: 'Команды Qwen Code'),
      BotCommand(command: 'help', description: 'Все команды'),
    ]).then((_) {
      _log.info('Bot commands registered');
    }).catchError((e) {
      _log.error('Failed to set bot commands: $e');
    });

    // ─── Callback Query Handler (for inline buttons) ───
    _bot!.onCallbackQuery((ctx) async {
      final data = ctx.callbackQuery?.data;
      if (data == null) return;

      if (data.startsWith('stop_')) {
        final msgId = data.substring(5);
        handleStopCallback(msgId);
        await ctx.answerCallbackQuery(text: 'Останавливаю...');
      }
    });

    // ─── /start ───
    _bot!.command('start', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('Access denied');
        return;
      }
      final proj = projectService?.activeProject;
      final projInfo = proj != null
          ? 'Project: ${proj.name}\nDir: ${proj.workingDirectory}'
          : 'No active project';

      await ctx.reply(
        'Qwen Code Bot\n\n'
        '${qwen.isRunning ? "Running" : "Stopped"}\n'
        '$projInfo\n\n'
        '/projects — Проекты\n'
        '/switch <N> — Переключить проект\n'
        '/newsession — Новая сессия\n'
        '/compact — Сжать контекст\n'
        '/status — Статус\n'
        '/quota — Квота API\n'
        '/commands — Команды Qwen Code\n'
        '/help — Все команды',
      );
    });

    // ─── /projects ───
    _bot!.command('projects', (ctx) async {
      if (!_isAllowed(ctx)) return;
      final ps = projectService;
      if (ps == null) {
        await ctx.reply('ProjectService не подключён');
        return;
      }
      final projects = ps.projects;
      if (projects.isEmpty) {
        await ctx.reply('Нет проектов. Добавьте проект в macOS приложении.');
        return;
      }
      final buf = StringBuffer('Проекты:\n\n');
      for (var i = 0; i < projects.length; i++) {
        final proj = projects[i];
        final active = proj.id == ps.activeProjectId ? ' [ACTIVE]' : '';
        buf.writeln('${i + 1}. ${proj.name}$active');
        buf.writeln('   ${proj.workingDirectory}');
        if (proj.sessionId != null) {
          final len = proj.sessionId!.length < 12 ? proj.sessionId!.length : 12;
          buf.writeln('   Session: ${proj.sessionId!.substring(0, len)}');
        }
        buf.writeln();
      }
      buf.writeln('Переключить: /switch <номер>');
      buf.writeln('Создать: /newproject <имя> <путь>');
      await ctx.reply(buf.toString());
    });

    // ─── /newproject <name> <path> ───
    _bot!.command('newproject', (ctx) async {
      if (!_isAllowed(ctx)) return;
      final ps = projectService;
      if (ps == null) {
        await ctx.reply('ProjectService не подключён');
        return;
      }
      final text = ctx.message?.text ?? '';
      // /newproject MyApp /Users/pavelm/projects/myapp
      final match = RegExp(r'^/newproject\s+(\S+)\s+(.+)$').firstMatch(text.trim());
      if (match == null) {
        await ctx.reply(
          'Использование: /newproject <имя> <путь>\n'
          'Пример: /newproject MyApp /Users/pavelm/projects/myapp',
        );
        return;
      }
      final name = match.group(1)!;
      final dir = match.group(2)!.trim();

      // Validate directory exists
      if (!await io.Directory(dir).exists()) {
        await ctx.reply('Директория не существует: $dir');
        return;
      }

      final project = await ps.addProject(name: name, workingDirectory: dir);
      await ps.setActive(project.id);
      qwen.configure(cliPath: '', workingDir: project.workingDirectory, systemPrompt: systemPrompt);
      await qwen.continueLastSession();

      await ctx.reply(
        'Проект создан и активирован:\n'
        'Name: ${project.name}\n'
        'Dir: ${project.workingDirectory}\n'
        'Готов к работе (--continue)',
      );
    });

    // ─── /switch <N> ───
    _bot!.command('switch', (ctx) async {
      if (!_isAllowed(ctx)) return;
      final ps = projectService;
      if (ps == null) {
        await ctx.reply('ProjectService не подключён');
        return;
      }
      final text = ctx.message?.text ?? '';
      final parts = text.split(' ');
      if (parts.length < 2) {
        await ctx.reply('Использование: /switch <номер>\nСписок: /projects');
        return;
      }
      final idx = int.tryParse(parts[1].trim());
      if (idx == null || idx < 1 || idx > ps.projects.length) {
        await ctx.reply('Неверный номер. Проектов: ${ps.projects.length}');
        return;
      }
      final project = ps.projects[idx - 1];

      // Auto-compact current session before switching
      if (qwen.isRunning && !qwen.isBusy && qwen.currentSessionId != null) {
        await ctx.reply('Сжимаю текущую сессию...');
        try {
          await qwen.compactSession();
        } catch (e) {
          _log.warn('Auto-compact before switch failed: $e');
        }
      }

      await ps.setActive(project.id);
      qwen.configure(
        cliPath: '',
        workingDir: project.workingDirectory,
        systemPrompt: systemPrompt,
      );

      if (project.sessionId != null) {
        await qwen.resumeSession(project.sessionId!);
        final len = project.sessionId!.length < 12 ? project.sessionId!.length : 12;
        await ctx.reply(
          'Проект: ${project.name}\n'
          'Dir: ${project.workingDirectory}\n'
          'Session resumed: ${project.sessionId!.substring(0, len)}',
        );
      } else {
        await qwen.continueLastSession();
        await ctx.reply(
          'Проект: ${project.name}\n'
          'Dir: ${project.workingDirectory}\n'
          'Продолжаю последнюю сессию (--continue)',
        );
      }
    });

    // ─── /newsession ───
    _bot!.command('newsession', (ctx) async {
      if (!_isAllowed(ctx)) return;
      try {
        await qwen.startNewSession();
        // Clear session ID on active project
        final ps = projectService;
        if (ps != null && ps.activeProject != null) {
          ps.activeProject!.sessionId = null;
          await ps.updateProject(ps.activeProject!);
        }
        await ctx.reply('Новая сессия создана');
      } catch (e) {
        await ctx.reply('Error: $e');
      }
    });

    // ─── /model — Переключить модель ───
    _bot!.command('model', (ctx) async {
      if (!_isAllowed(ctx)) return;

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).toList();

      if (args.isEmpty) {
        // Показать текущую модель и доступные
        final currentModel = await qwen.getCurrentModelName();
        final availableModels = await qwen.configService.getAvailableModels();
        final ollamaRunning = qwen.configService.ollamaRunning;

        String modelsList = 'Нет доступных моделей';
        if (availableModels.isNotEmpty) {
          modelsList = availableModels.map((m) {
            final isCurrent = m['id'] == currentModel;
            final icon = isCurrent ? '✅' : '  ';
            return '$icon *${m['name']}* (`${m['id']}`)';
          }).join('\n');
        }

        await ctx.reply(
          '📊 *Текущая модель:* `$currentModel`\n\n'
          '📋 *Доступные модели:*\n$modelsList\n\n'
          'Ollama: ${ollamaRunning ? "✅ Запущена" : qwen.ollamaAvailable ? "⏸ Остановлена" : "❌ Не установлена"}\n\n'
          'Использование:\n'
          '`/model <model_id>` — переключить модель\n'
          '`/model list` — показать список\n'
          '`/model local` — локальная (Ollama)\n'
          '`/model cloud` — облачная (OAuth)\n'
          '`/model stop` — остановить модель (выгрузить из памяти)',
          parseMode: ParseMode.markdown,
        );
        return;
      }

      final command = args.first.toLowerCase();

      switch (command) {
        case 'list':
        case 'ls':
        case 'l':
          // Показать список моделей
          final currentModel = await qwen.getCurrentModelName();
          final availableModels = await qwen.configService.getAvailableModels();
          
          String modelsList = 'Нет доступных моделей';
          if (availableModels.isNotEmpty) {
            modelsList = availableModels.map((m) {
              final isCurrent = m['id'] == currentModel;
              final icon = isCurrent ? '✅' : '  ';
              final desc = m['description']!.isNotEmpty ? ' — ${m['description']}' : '';
              return '$icon *${m['name']}* (`${m['id']}`)$desc';
            }).join('\n');
          }

          await ctx.reply(
            '📋 *Доступные модели:*\n$modelsList',
            parseMode: ParseMode.markdown,
          );
          break;

        case 'cloud':
        case 'c':
          try {
            final availableModels = await qwen.configService.getAvailableModels();
            // Находим облачную модель (не содержащую qwen2.5, ollama, localhost)
            final cloudModel = availableModels.firstWhere(
              (m) => !m['id']!.contains('qwen2.5') && 
                     !m['id']!.contains('ollama') && 
                     !m['id']!.contains('localhost'),
              orElse: () => throw Exception('Облачная модель не найдена'),
            );
            await qwen.configService.switchModel(cloudModel['id']!);
            await ctx.reply('✅ Переключено на ☁️ ОБЛАЧНУЮ модель: *${cloudModel['name']}*', parseMode: ParseMode.markdown);
          } catch (e) {
            await ctx.reply('❌ Error: $e');
          }
          break;

        case 'local':
        case 'l':
          if (!qwen.ollamaAvailable) {
            await ctx.reply('❌ Ollama не установлена');
            return;
          }
          if (!qwen.configService.ollamaRunning) {
            await ctx.reply('⚠️ Ollama остановлена. Запустите Ollama и попробуйте снова.', parseMode: ParseMode.markdown);
            return;
          }
          try {
            final availableModels = await qwen.configService.getAvailableModels();
            // Находим локальную модель
            final localModel = availableModels.firstWhere(
              (m) => m['id']!.contains('qwen2.5') || 
                     m['id']!.contains('ollama') || 
                     m['id']!.contains('localhost'),
              orElse: () => throw Exception('Локальная модель не найдена'),
            );
            await qwen.configService.switchModel(localModel['id']!);
            
            // Проверяем и запускаем модель
            final modelStarted = await qwen.configService.checkAndStartModelByName(localModel['id']!);
            
            if (modelStarted) {
              await ctx.reply('✅ Переключено на 🖥 ЛОКАЛЬНУЮ модель: *${localModel['name']}*\nМодель запущена и готова', parseMode: ParseMode.markdown);
            } else {
              await ctx.reply('⚠️ Переключено на 🖥 ЛОКАЛЬНУЮ модель: *${localModel['name']}*\nНо модель не готова: ${qwen.configService.ollamaModelError}', parseMode: ParseMode.markdown);
            }
          } catch (e) {
            await ctx.reply('❌ Error: $e');
          }
          break;

        case 'stop':
          // Остановить модель (выгрузить из памяти Ollama)
          if (!qwen.configService.ollamaRunning) {
            await ctx.reply('ℹ️ Ollama не запущена');
            return;
          }
          try {
            await ctx.reply('⏳ Остановка модели...');
            final success = await qwen.stopModel();
            if (success) {
              await ctx.reply('✅ Модель остановлена. Память освобождена');
            } else {
              await ctx.reply('❌ Не удалось остановить модель');
            }
          } catch (e) {
            await ctx.reply('❌ Error: $e');
          }
          break;

        default:
          // Переключить по ID модели
          try {
            final modelId = command;
            final availableModels = await qwen.configService.getAvailableModels();
            // Проверяем, существует ли такая модель
            final model = availableModels.firstWhere(
              (m) => m['id'] == modelId,
              orElse: () => throw Exception('Модель "$modelId" не найдена'),
            );
            await qwen.configService.switchModel(modelId);
            await ctx.reply('✅ Переключено на: *${model['name']}*', parseMode: ParseMode.markdown);
          } catch (e) {
            await ctx.reply('❌ Error: $e');
          }
      }
    });

    // ─── /compact ───
    _bot!.command('compact', (ctx) async {
      if (!_isAllowed(ctx)) return;
      try {
        await qwen.compactSession();
        await ctx.reply('Контекст сжат');
      } catch (e) {
        await ctx.reply('Error: $e');
      }
    });

    // ─── /status ───
    _bot!.command('status', (ctx) async {
      if (!_isAllowed(ctx)) return;
      final buf = StringBuffer('Статус:\n\n');
      buf.writeln('Bot: ${_isRunning ? "Running" : "Stopped"}');
      buf.writeln('Qwen: ${qwen.isRunning ? "Running" : "Stopped"}');
      buf.writeln('Model: ${qwen.isLocalModel ? "🖥 Local (config)" : "☁️ Cloud (config)"}');
      buf.writeln('Ollama: ${qwen.ollamaAvailable ? "✅ Available" : "❌ Not available"}');

      // Получаем имя текущей модели
      try {
        final modelName = await qwen.getCurrentModelName();
        if (modelName != null) {
          buf.writeln('Current model: $modelName');
        }
      } catch (_) {}

      buf.writeln('Messages: $_messageCount');
      final proj = projectService?.activeProject;
      if (proj != null) {
        buf.writeln('Project: ${proj.name}');
        buf.writeln('Dir: ${proj.workingDirectory}');
      }
      if (qwen.sessionStartTime != null) {
        final dur = qwen.sessionDuration;
        buf.writeln('Duration: ${dur.inHours}h ${dur.inMinutes % 60}m');
      }
      if (qwen.currentSessionId != null) {
        buf.writeln('Session: ${qwen.currentSessionId}');
      }
      await ctx.reply(buf.toString());
    });

    // ─── /day — Информация о рабочем дне ───
    _bot!.command('day', (ctx) async {
      if (!_isAllowed(ctx)) return;
      
      final day = timeTrackerService?.currentWorkDay;
      if (day == null) {
        await ctx.reply('ℹ️ Рабочий день ещё не начат');
        return;
      }

      final balance = day.balance;
      final balanceText = balance > Duration.zero
        ? '❌ Задолженность: ${DurationFormatter.format(balance)}'
        : balance < Duration.zero
          ? '✅ Свободное время: ${DurationFormatter.format(-balance)}'
          : '⚖️ Баланс';

      final carriedOverText = day.carriedOver > Duration.zero
        ? '\n📤 Перенос на завтра: ${DurationFormatter.format(day.carriedOver)}'
        : '';

      await ctx.reply(
        '📊 *Рабочий день*\n\n'
        '📅 Дата: ${day.createToDate.toLocal().toString().split(' ').first}\n'
        '⏱ Estimate: ${DurationFormatter.format(day.totalEstimate)}\n'
        '🕐 Spent: ${DurationFormatter.format(day.totalSpent)}\n'
        '📥 С прошлого дня: ${DurationFormatter.format(day.prevWorkTime)}'
        '$carriedOverText\n\n'
        '*$balanceText*',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── /quota ───
    _bot!.command('quota', (ctx) async {
      if (!_isAllowed(ctx)) return;
      await ctx.reply('Проверяю квоту...');
      try {
        // Ask Qwen Code about the quota/usage
        final response = await qwen.sendMessage(
          'What is my current API usage/quota status? '
          'Check with /usage if available. Be brief.',
        );
        await _sendReply(ctx, response);
      } catch (e) {
        await ctx.reply('Error: $e');
      }
    });

    // ─── /commands ───
    _bot!.command('commands', (ctx) async {
      if (!_isAllowed(ctx)) return;
      await ctx.reply(
        'Команды Qwen Code CLI (отправляйте как текст):\n\n'
        '🔧 Основные:\n'
        '/compact — Сжать контекст сессии\n'
        '/clear — Очистить историю диалога\n'
        '/cost — Показать стоимость сессии\n'
        '/doctor — Диагностика Qwen Code\n'
        '/help — Помощь Qwen Code\n'
        '/status — Статус Qwen Code\n\n'
        '📁 Проект:\n'
        '/init — Инициализировать QWEN.md\n'
        '/review — Ревью кода\n'
        '/vim — Режим vim\n\n'
        '⚙️ Настройки:\n'
        '/login — Авторизация\n'
        '/logout — Выход\n'
        '/memory — Управление памятью\n'
        '/model — Переключить модель\n'
        '/permissions — Настроить разрешения\n\n'
        '💡 Пример:\n'
        'Отправьте: /doctor\n'
        'И Qwen выполнит эту команду.',
      );
    });

    // ─── /help ───
    _bot!.command('help', (ctx) async {
      if (!_isAllowed(ctx)) return;
      await ctx.reply(
        'Все команды:\n\n'
        'Управление:\n'
        '/start — Приветствие\n'
        '/projects — Список проектов\n'
        '/newproject <имя> <путь> — Создать проект\n'
        '/switch <N> — Переключить проект\n'
        '/newsession — Новая сессия\n'
        '/model — Управление моделью\n'
        '/compact — Сжать контекст\n'
        '/status — Статус системы\n'
        '/quota — Квота API\n'
        '/ping — Проверка связи с Qwen\n'
        '/commands — Команды Qwen Code\n'
        '/help — Эта справка\n\n'
        'Модели:\n'
        '/model — Текущая модель\n'
        '/model cloud — Облачная модель\n'
        '/model local — Локальная модель\n'
        '/model start — Запустить Ollama\n'
        '/model stop — Остановить Ollama\n\n'
        'Задачи (через CLI):\n'
        '/tasks [active|completed|all] — Список задач\n'
        '/starttask <номер|имя> — Запустить таймер\n'
        '/stoptask <номер|имя> — Остановить таймер\n'
        '/addtask <название> [...] — Добавить задачу\n'
        '/export [days] — Экспорт в Excel\n\n'
        'Медиа:\n'
        'Фото — Qwen проанализирует\n'
        'Голос — транскрипция + Qwen\n'
        'Документ — Qwen прочитает файл\n'
        'Текст — отправляется в Qwen Code',
      );
    });

    // ─── /ping — Test connection ───
    _bot!.command('ping', (ctx) async {
      if (!_isAllowed(ctx)) return;

      if (!qwen.isRunning) {
        await ctx.reply('❌ Qwen Code не запущен. Используйте /newsession');
        return;
      }

      if (qwen.isBusy) {
        await ctx.reply('⏳ Qwen Code занят. Подождите...');
        return;
      }

      await ctx.reply('🏓 Qwen Code готов к работе!');
    });

    // ─── /tasks — List tasks ───
    _bot!.command('tasks', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('❌ Доступ запрещён');
        return;
      }

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).toList();
      final status = args.isNotEmpty ? args.first.toLowerCase() : 'active';

      await ctx.reply(
        '📋 *Задачи (${status}):*\n\n'
        '_Для управления задачами используйте CLI:_\n'
        '`qwen_time_tracker.exe list-tasks --status $status`\n\n'
        'Примеры:\n'
        '`/tasks active` — активные задачи\n'
        '`/tasks completed` — завершённые\n'
        '`/tasks all` — все задачи',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── /starttask — Start timer ───
    _bot!.command('starttask', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('❌ Доступ запрещён');
        return;
      }

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).join(' ').trim();
      
      if (args.isEmpty) {
        await ctx.reply('❌ Использование: /starttask <номер_задачи|имя>\n\nПример: `/starttask 5` или `/starttask "Fix bug"`', parseMode: ParseMode.markdown);
        return;
      }

      await ctx.reply(
        '⏱ *Запуск таймера: $args*\n\n'
        '_Для запуска используйте CLI:_\n'
        '`qwen_time_tracker.exe start-timer $args`',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── /stoptask — Stop timer ───
    _bot!.command('stoptask', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('❌ Доступ запрещён');
        return;
      }

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).join(' ').trim();
      
      if (args.isEmpty) {
        await ctx.reply('❌ Использование: /stoptask <номер_задачи|имя>\n\nПример: `/stoptask 5` или `/stoptask "Fix bug"`', parseMode: ParseMode.markdown);
        return;
      }

      await ctx.reply(
        '⏹ *Остановка таймера: $args*\n\n'
        '_Для остановки используйте CLI:_\n'
        '`qwen_time_tracker.exe stop-timer $args`',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── /addtask — Add task ───
    _bot!.command('addtask', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('❌ Доступ запрещён');
        return;
      }

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).join(' ').trim();

      if (args.isEmpty) {
        await ctx.reply(
          '❌ *Добавление задачи*\n\n'
          'Использование:\n'
          '`/addtask <название> --estimate <HH:MM> --project <проект> --description <описание>`\n\n'
          'Пример:\n'
          '`/addtask "Fix bug #123" --estimate 01:30 --project Web --description "Critical bug"`\n\n'
          '_Или используйте CLI:_\n'
          '`qwen_time_tracker.exe add-task "Fix bug" --estimate 01:30`',
          parseMode: ParseMode.markdown,
        );
        return;
      }

      await ctx.reply(
        '✅ *Задача добавлена*\n\n'
        '_Используйте CLI для полного функционала:_\n'
        '`qwen_time_tracker.exe add-task ...`',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── /export — Export to Excel ───
    _bot!.command('export', (ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('❌ Доступ запрещён');
        return;
      }

      final text = ctx.message?.text ?? '';
      final args = text.split(' ').skip(1).toList();
      final days = args.isNotEmpty ? args.first : '7';

      await ctx.reply(
        '📊 *Экспорт в Excel*\n\n'
        'Период: последние $days дн.\n\n'
        '_Для экспорта используйте CLI:_\n'
        '`qwen_time_tracker.exe export-excel --from 2026-03-01 --to 2026-03-03`\n\n'
        'Файл будет сохранён в папке Downloads',
        parseMode: ParseMode.markdown,
      );
    });

    // ─── Handle ALL messages ───
    _bot!.onMessage((ctx) async {
      if (!_isAllowed(ctx)) {
        await ctx.reply('Access denied');
        return;
      }

      final msg = ctx.message;
      if (msg == null) return;

      // Rate limiting
      final senderId = msg.from?.id;
      if (senderId != null && _isRateLimited(senderId)) {
        await ctx.reply('Слишком много сообщений. Подождите минуту.');
        return;
      }

      // Check if it's a command
      if (msg.text != null && msg.text!.startsWith('/')) {
        // Skip bot's own commands (they are handled separately)
        final botCommands = [
          '/start', '/projects', '/newproject', '/switch',
          '/newsession', '/compact', '/status', '/quota', '/commands', '/help',
          '/tasks', '/starttask', '/stoptask', '/addtask', '/export'
        ];
        final command = msg.text!.split(' ')[0].toLowerCase();
        if (botCommands.contains(command)) {
          return; // Let the command handler process it
        }
        
        // It's a qwen-code command (like /doctor, /init, etc.) - forward to Qwen
        if (!qwen.isRunning) {
          await ctx.reply('Qwen Code не запущен. Используйте /newsession');
          return;
        }
        if (qwen.isBusy) {
          await ctx.reply('Обрабатываю предыдущее сообщение. Подождите...');
          return;
        }
        
        // Send the command to Qwen Code CLI
        final commandText = msg.text!.trim();
        await _handleQwenCommand(ctx, commandText);
        return;
      }

      if (!qwen.isRunning) {
        await ctx.reply('Qwen Code не запущен. Используйте /newsession');
        return;
      }

      if (qwen.isBusy) {
        await ctx.reply('Обрабатываю предыдущее сообщение. Подождите...');
        return;
      }

      String queryText;
      String displayQuery;

      // --- PHOTO ---
      if (msg.photo != null && msg.photo!.isNotEmpty) {
        await ctx.reply('Скачиваю картинку...');
        final photo = msg.photo!.last;
        final localPath = await _downloadFile(photo.fileId, 'jpg');
        if (localPath == null) {
          await ctx.reply('Не удалось скачать картинку');
          return;
        }
        final caption = msg.caption ?? 'Describe this image';
        queryText = 'Read and analyze the image at path: $localPath\n\nUser request: $caption';
        displayQuery = '[Photo] $caption';

      // --- VOICE ---
      } else if (msg.voice != null) {
        await ctx.reply('Обработка голосового...');
        final localPath = await _downloadFile(msg.voice!.fileId, 'ogg');
        if (localPath == null) {
          await ctx.reply('Не удалось скачать голосовое');
          return;
        }
        final transcription = await _transcribeVoice(localPath);
        if (transcription != null && transcription.trim().isNotEmpty) {
          await ctx.reply('Транскрипция: $transcription');
          queryText = transcription.trim();
          displayQuery = '[Voice] $queryText';
        } else {
          _log.info('Whisper not available, sending audio file to Qwen directly');
          queryText = 'User sent a voice message (audio file): $localPath\n'
              'Transcription unavailable. Tell user to install whisper: '
              'pip3 install openai-whisper and ffmpeg: brew install ffmpeg';
          displayQuery = '[Voice - no whisper]';
        }

      // --- DOCUMENT ---
      } else if (msg.document != null) {
        await ctx.reply('Скачиваю документ...');
        final doc = msg.document!;
        final ext = doc.fileName?.split('.').last ?? 'bin';
        final localPath = await _downloadFile(doc.fileId, ext);
        if (localPath == null) {
          await ctx.reply('Не удалось скачать документ');
          return;
        }
        final caption = msg.caption ?? 'Read and analyze this file';
        queryText = 'Read the file at path: $localPath\n\nUser request: $caption';
        displayQuery = '[${doc.fileName ?? "Document"}] $caption';

      // --- TEXT ---
      } else if (msg.text != null && msg.text!.isNotEmpty) {
        queryText = msg.text!;
        displayQuery = msg.text!;

      } else {
        await ctx.reply('Неподдерживаемый тип. Отправьте текст, фото, голос или документ.');
        return;
      }

      _messageCount++;
      final msgId = '${DateTime.now().millisecondsSinceEpoch}';
      final senderName = msg.from?.firstName ?? 'Unknown';
      final senderIdVal = msg.from?.id ?? 0;

      final chatMsg = ChatMessage(
        id: msgId,
        senderName: senderName,
        senderTelegramId: senderIdVal,
        query: displayQuery,
        timestamp: DateTime.now(),
      );
      addMessage(chatMsg);
      _log.info('Message from $senderName ($senderIdVal): $displayQuery');

      try {
        await ctx.sendChatAction(ChatAction.typing);
      } catch (_) {}

      try {
        await _handleStreamingResponse(ctx, queryText, msgId);
      } catch (e) {
        final errorStr = e.toString();
        updateMessage(msgId, response: 'Error: $errorStr', status: MessageStatus.error);
        _log.error('Error processing message: $errorStr');

        if (errorStr.contains('500') || errorStr.contains('api_error')) {
          await ctx.reply(
            'Сервер Anthropic временно недоступен (500).\n'
            'Попробуйте через пару минут.'
          );
        } else {
          await ctx.reply('Error: $errorStr');
        }
      }

      notifyListeners();
    });

    _isRunning = true;
    _log.info('Setting isRunning=true, notifying listeners...');
    notifyListeners();

    _log.info('Starting bot polling...');
    unawaited(_bot!.start().catchError((e, st) {
      _log.error('Bot polling error: $e\n$st');
      _isRunning = false;
      notifyListeners();
    }));

    _log.info('Telegram bot started');
  }

  // ─── Streaming response with live Telegram message updates ──────────────

  /// Min interval between editMessageText calls (Telegram rate limit ~1/sec).
  static const _editInterval = Duration(milliseconds: 1500);

  /// System prompt for compact formatting (no mention of Telegram).
  /// Applied only to user messages, not CLI commands.
  static const systemPrompt =
      'Keep responses concise and well-structured. '
      'Prefer short answers over long explanations. '
      'Use markdown sparingly: bold for key points, code blocks for code. '
      'If the result is large, summarize and offer to show more. '
      'Respond in the same language the user writes in.';

  /// Max length for the streaming preview message.
  static const _previewMaxLen = 4000;

  /// Handle a streaming response: send a placeholder message, then
  /// update it as text deltas arrive, then send the final response.
  Future<void> _handleStreamingResponse(
    Context ctx,
    String queryText,
    String msgId,
  ) async {
    final chatId = ctx.message?.chat.id;
    if (chatId == null) return;

    // Send initial "thinking" message with stop button
    final placeholder = await ctx.reply(
      '🤔 Думаю...',
      replyMarkup: _buildStopKeyboard(msgId),
    );
    final placeholderMsgId = placeholder.messageId;
    final tgChatId = ChatID(chatId);

    final accumulated = StringBuffer();
    var lastEditTime = DateTime(0);  // Start with past time to allow first edit immediately
    var lastEditedText = '';
    bool isStopped = false;

    // Store the stop callback
    _stopCallbacks[msgId] = () => isStopped = true;

    try {
      await for (final event in qwen.sendMessageStream(queryText, useSystemPrompt: false)) {
        if (isStopped) break;

        switch (event.type) {
          case StreamEventType.init:
            // Session started, continue typing indicator
            try {
              await ctx.sendChatAction(ChatAction.typing);
            } catch (_) {}

          case StreamEventType.textDelta:
            accumulated.write(event.text);

            // Throttle edits to avoid Telegram rate limits
            final now = DateTime.now();
            if (now.difference(lastEditTime) >= _editInterval) {
              final preview = _truncatePreview(accumulated.toString());
              if (preview != lastEditedText) {
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId,
                    preview,
                    replyMarkup: _buildStopKeyboard(msgId),
                  );
                  lastEditedText = preview;
                } catch (e) {
                  _log.warn('editMessageText failed: $e');
                }
                lastEditTime = now;
              }
              // Refresh typing indicator
              try {
                await ctx.sendChatAction(ChatAction.typing);
              } catch (_) {}
            }

          case StreamEventType.toolUse:
            // Show tool use progress
            if (event.text != null && event.text!.isNotEmpty) {
              try {
                await _bot!.api.editMessageText(
                  tgChatId,
                  placeholderMsgId,
                  '🔧 ${event.text}\n\n${_truncatePreview(accumulated.toString())}',
                  replyMarkup: _buildStopKeyboard(msgId),
                );
              } catch (_) {}
            }

          case StreamEventType.result:
            // Final result received - remove stop button
            _stopCallbacks.remove(msgId);

            final response = event.fullResult ?? accumulated.toString();
            updateMessage(msgId, response: response, status: MessageStatus.sent);
            _log.info(
                'Response: ${response.substring(0, response.length.clamp(0, 200))}');

            // Auto-save session ID to active project
            if (event.sessionId != null) {
              final ps = projectService;
              final activeProj = ps?.activeProject;
              if (ps != null && activeProj != null) {
                await ps.updateSessionId(activeProj.id, event.sessionId!);
                _log.info('Saved session ID to project: ${activeProj.name}');
              }
            }

            // Update the final message - remove stop button, send full response
            if (response.isEmpty) {
              // Empty response
              try {
                await _bot!.api.editMessageText(
                  tgChatId,
                  placeholderMsgId,
                  '(пустой ответ)',
                );
              } catch (_) {}
            } else if (response.length > 3500) {
              // Send as .md file
              final fileName = 'response_${DateTime.now().millisecondsSinceEpoch}.md';
              final tempPath = '${io.Directory.systemTemp.path}\\$fileName';
              final tempFile = io.File(tempPath);
              await tempFile.writeAsString(response);

              try {
                await _bot!.api.editMessageText(
                  tgChatId,
                  placeholderMsgId,
                  '✅ Готово! Ответ большой, поэтому отправляю как файл.',
                );
              } catch (_) {}

              final inputFile = InputFile.fromFile(tempFile, name: fileName);
              await ctx.replyWithDocument(inputFile, caption: '📄 Ответ Qwen Code');

              try {
                await tempFile.delete();
              } catch (_) {}
            } else {
              // Send as text - update existing message, remove stop button
              try {
                await _bot!.api.editMessageText(
                  tgChatId,
                  placeholderMsgId,
                  response,
                );
              } catch (_) {
                await ctx.reply(response);
              }
            }

            await _sendFilesFromResponse(ctx, response);

          case StreamEventType.error:
            _stopCallbacks.remove(msgId);
            final errorText = event.text ?? 'Unknown error';
            updateMessage(msgId,
                response: 'Error: $errorText', status: MessageStatus.error);
            try {
              await _bot!.api.editMessageText(
                tgChatId,
                placeholderMsgId,
                '❌ Error: $errorText',
              );
            } catch (_) {
              await ctx.reply('Error: $errorText');
            }
        }
      }

      // If stopped by user
      if (isStopped) {
        _stopCallbacks.remove(msgId);
        try {
          await _bot!.api.editMessageText(
            tgChatId,
            placeholderMsgId,
            '⏹️ Остановлено пользователем',
          );
        } catch (_) {}
      }
    } catch (e) {
      _stopCallbacks.remove(msgId);
      final errorStr = e.toString();
      try {
        await _bot!.api.editMessageText(
          tgChatId,
          placeholderMsgId,
          '❌ Error: $errorStr',
        );
      } catch (_) {
        await ctx.reply('Error: $errorStr');
      }
      _log.error('Error processing message: $errorStr');
    }

    notifyListeners();
  }

  String _truncatePreview(String text) {
    if (text.length <= _previewMaxLen) return text;
    // Show last N characters with "..." prefix
    return '...${text.substring(text.length - _previewMaxLen + 3)}';
  }

  /// Handle qwen-code CLI commands (like /doctor, /init, etc.)
  Future<void> _handleQwenCommand(Context ctx, String commandText) async {
    final msgId = '${DateTime.now().millisecondsSinceEpoch}';
    final senderName = ctx.message?.from?.firstName ?? 'Unknown';
    final senderIdVal = ctx.message?.from?.id ?? 0;

    _log.info('Qwen command from $senderName ($senderIdVal): $commandText');

    try {
      // Send initial "thinking" message with stop button
      final placeholder = await ctx.reply(
        '🤔 Думаю...',
        replyMarkup: _buildStopKeyboard(msgId),
      );
      final placeholderMsgId = placeholder.messageId;
      final tgChatId = ChatID(ctx.message?.chat.id ?? 0);

      final accumulated = StringBuffer();
      var lastEditTime = DateTime(0);  // Start with past time to allow first edit immediately
      var lastEditedText = '';
      bool isStopped = false;

      // Store the stop callback
      _stopCallbacks[msgId] = () => isStopped = true;

      try {
        // Send command WITHOUT system prompt
        await for (final event in qwen.sendMessageStream(commandText, useSystemPrompt: false)) {
          if (isStopped) break;

          switch (event.type) {
            case StreamEventType.init:
              // Session started - update status
              if (placeholderMsgId != null) {
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId,
                    '⏳ Обрабатываю...',
                    replyMarkup: _buildStopKeyboard(msgId),
                  );
                } catch (_) {}
              }

            case StreamEventType.textDelta:
              accumulated.write(event.text);

              // Throttle edits to avoid Telegram rate limits (max 1 edit per 1.5 sec)
              final now = DateTime.now();
              if (now.difference(lastEditTime) >= _editInterval) {
                final preview = _truncatePreview(accumulated.toString());
                if (preview != lastEditedText && placeholderMsgId != null) {
                  try {
                    await _bot!.api.editMessageText(
                      tgChatId,
                      placeholderMsgId,
                      preview,
                      replyMarkup: _buildStopKeyboard(msgId),
                    );
                    lastEditedText = preview;
                    lastEditTime = now;
                  } catch (e) {
                    _log.warn('editMessageText failed: $e');
                  }
                }
              }

            case StreamEventType.toolUse:
              // Show tool use progress
              if (event.text != null && event.text!.isNotEmpty && placeholderMsgId != null) {
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId,
                    '🔧 ${event.text}\n\n${_truncatePreview(accumulated.toString())}',
                    replyMarkup: _buildStopKeyboard(msgId),
                  );
                } catch (_) {}
              }

            case StreamEventType.result:
              // Final result received - remove stop button
              _stopCallbacks.remove(msgId);
              
              final response = event.fullResult ?? accumulated.toString();
              
              if (response.isEmpty) {
                // Empty response
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId ?? 0,
                    '(пустой ответ)',
                  );
                } catch (_) {}
              } else if (response.length > 3500) {
                // Send as .md file
                final fileName = 'response_${DateTime.now().millisecondsSinceEpoch}.md';
                final tempPath = '${io.Directory.systemTemp.path}\\$fileName';
                final tempFile = io.File(tempPath);
                await tempFile.writeAsString(response);
                
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId ?? 0,
                    '✅ Готово! Ответ большой, поэтому отправляю как файл.',
                  );
                } catch (_) {}
                
                final inputFile = InputFile.fromFile(tempFile, name: fileName);
                await ctx.replyWithDocument(inputFile, caption: '📄 Ответ Qwen Code');
                
                try {
                  await tempFile.delete();
                } catch (_) {}
              } else {
                // Send as text - remove stop button
                try {
                  await _bot!.api.editMessageText(
                    tgChatId,
                    placeholderMsgId ?? 0,
                    response,
                  );
                } catch (_) {
                  await ctx.reply(response);
                }
              }

            case StreamEventType.error:
              _stopCallbacks.remove(msgId);
              final errorStr = event.text ?? 'Unknown error';
              try {
                await _bot!.api.editMessageText(
                  tgChatId,
                  placeholderMsgId ?? 0,
                  '❌ Error: $errorStr',
                );
              } catch (_) {
                await ctx.reply('Error: $errorStr');
              }
          }

          notifyListeners();
        }
        
        // If stopped by user
        if (isStopped && placeholderMsgId != null) {
          try {
            await _bot!.api.editMessageText(
              tgChatId,
              placeholderMsgId,
              '⏹️ Остановлено пользователем',
            );
          } catch (_) {}
        }
      } catch (e) {
        _stopCallbacks.remove(msgId);
        final errorStr = e.toString();
        try {
          await _bot!.api.editMessageText(
            tgChatId,
            placeholderMsgId ?? 0,
            '❌ Error: $errorStr',
          );
        } catch (_) {
          await ctx.reply('Error: $errorStr');
        }
        _log.error('Error processing command: $errorStr');
      }
    } catch (e) {
      _log.error('Fatal error in _handleQwenCommand: $e');
    }

    notifyListeners();
  }

  /// Build inline keyboard with stop button
  InlineKeyboardMarkup _buildStopKeyboard(String msgId) {
    return InlineKeyboardMarkup(inlineKeyboard: [
      [
        InlineKeyboardButton(
          callbackData: 'stop_$msgId',
          text: '⏹️ Остановить',
        ),
      ],
    ]);
  }

  /// Callbacks for stopping generation
  final Map<String, VoidCallback> _stopCallbacks = {};

  /// Handle stop button callback
  void handleStopCallback(String msgId) {
    _log.info('Stop callback received for msgId: $msgId');
    // Call the stop callback if it exists
    _stopCallbacks[msgId]?.call();
    _stopCallbacks.remove(msgId);
    // Kill the active Qwen process
    qwen.stopCurrentRequest();
  }

  /// Sensitive paths that must NEVER be sent to Telegram.
  static const _blockedPathPatterns = [
    '.ssh', '.gnupg', '.aws', '.kube', '.docker',
    '.env', '.credentials', '.netrc', '.npmrc', '.pypirc',
    'id_rsa', 'id_ed25519', 'known_hosts', 'authorized_keys',
    '.git/config', '.gitconfig',
    'keychain', 'Keychain', 'secrets', 'tokens',
  ];

  /// Detect file paths in Qwen's response and send them as documents.
  /// Only sends files that are inside the current working directory.
  Future<void> _sendFilesFromResponse(Context ctx, String response) async {
    final workDir = projectService?.activeProject?.workingDirectory ?? '';
    if (workDir.isEmpty) return;

    final pathRegex = RegExp(r'(?:^|\s)(/(?:Users|tmp|var|home)[^\s\n",;:]+)', multiLine: true);
    final matches = pathRegex.allMatches(response);

    for (final match in matches) {
      final filePath = match.group(1)?.trim();
      if (filePath == null) continue;

      // Resolve to canonical path to prevent ../ traversal
      final canonical = io.File(filePath).resolveSymbolicLinksSync();

      // Only allow files inside the project working directory
      if (!canonical.startsWith(workDir)) {
        _log.warn('Blocked file send (outside working dir): $filePath');
        continue;
      }

      // Block sensitive files
      if (_blockedPathPatterns.any((pat) => canonical.contains(pat))) {
        _log.warn('Blocked file send (sensitive path): $filePath');
        continue;
      }

      final file = io.File(canonical);
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.type == io.FileSystemEntityType.file && stat.size < 50 * 1024 * 1024) {
          try {
            final inputFile = InputFile.fromFile(file, name: p.basename(filePath));
            await ctx.replyWithDocument(inputFile, caption: filePath);
            _log.info('Sent file: $filePath');
          } catch (e) {
            _log.error('Failed to send file $filePath: $e');
          }
        }
      }
    }
  }

  bool _isAllowed(Context ctx) {
    if (allowedUserIds.isEmpty) {
      _log.warn('Access denied: allowedUserIds is empty — no users allowed. '
          'Add at least one Telegram User ID in Settings.');
      return false;
    }
    final userId = ctx.message?.from?.id;
    return userId != null && allowedUserIds.contains(userId);
  }

  /// Returns true if the user has exceeded the rate limit.
  bool _isRateLimited(int userId) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));

    final times = _userMessageTimes.putIfAbsent(userId, () => []);
    // Remove entries older than 1 minute
    times.removeWhere((t) => t.isBefore(cutoff));
    if (times.length >= _rateLimitPerMinute) {
      _log.warn('Rate limited user $userId (${times.length} msgs/min)');
      return true;
    }
    times.add(now);
    return false;
  }

  Future<void> stop() async {
    _log.info('Stopping Telegram bot');
    if (_bot != null) {
      try {
        await _bot!.stop();
      } catch (_) {}
    }
    _bot = null;
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

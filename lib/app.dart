import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/bot_settings.dart';
import 'services/qwen_code_service.dart';
import 'services/log_service.dart';
import 'services/project_service.dart';
import 'services/telegram_bot_service.dart';
import 'services/tray_service.dart';
import 'services/single_instance_service.dart';
import 'services/time_tracker_service.dart';
import 'services/app_directory_service.dart';
import 'widgets/sidebar.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/chat_log_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ipc_service.dart';

class QwenTimeTrackerApp extends StatelessWidget {
  const QwenTimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qwen Time Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade400,
          surface: const Color(0xFF0F0F1A),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _qwenService = QwenCodeService();
  final _projectService = ProjectService();
  final _timeTrackerService = TimeTrackerService();
  final _trayService = TrayService();
  late final TelegramBotService _botService;
  late BotSettings _settings;
  bool _initialized = false;
  SidebarItem _selectedTab = SidebarItem.dashboard;
  final _log = LogService();

  @override
  void initState() {
    super.initState();
    _botService = TelegramBotService(
      qwen: _qwenService,
      projectService: _projectService,
    );
    _init();
    _setupIpcListener();
  }

  /// Настройка прослушивания IPC сообщений от CLI
  void _setupIpcListener() {
    IpcService().messages.listen((message) {
      _log.info('IPC: ${message.type} - ${message.data ?? ''}');
      // Перезагружаем данные из ObjectBox при получении IPC сообщения
      _timeTrackerService.reload();
    });
  }

  Future<void> _init() async {
    try {
      await _log.init();
      _log.info('Init: loading settings...');
      _settings = await BotSettings.load();
      await _projectService.load();
      await _timeTrackerService.load();

      // Определяем директорию приложения и копируем QWEN.md
      final appDirectory = await AppDirectoryService().getAppDirectory();
      _log.info('App directory: $appDirectory');
      
      // Копируем QWEN.md в дирекрию приложения если нет
      await AppDirectoryService().copyQwenContextToAppDirectory();
      _log.info('QWEN.md context copied: ${await AppDirectoryService().hasQwenContext()}');

      _qwenService.configure(
        cliPath: _settings.qwenCliPath,
        workingDir: appDirectory,  // Используем директорию приложения
        useYoloMode: _settings.useYoloMode,
      );
      _botService.allowedUserIds = _settings.allowedUserIds.toSet();

      // Инициализируем сервис конфигураций и синхронизируем модель
      await _qwenService.initialize();

      // Проверяем доступность Ollama
      await _qwenService.checkOllamaAvailability();

      // Автозапуск локальной модели если включено в настройках
      if (_settings.autoStartLocalModel && _qwenService.ollamaAvailable) {
        _log.info('Auto-starting local model: ${_settings.ollamaModel}');
        try {
          final availableModels = await _qwenService.getAvailableModels();
          final localModel = availableModels.firstWhere(
            (m) => m['id'] == _settings.ollamaModel ||
                   m['id']!.contains(_settings.ollamaModel.split(':').first),
            orElse: () => availableModels.firstWhere(
              (m) => m['id']!.contains('qwen2.5'),
              orElse: () => availableModels.first,
            ),
          );
          await _qwenService.switchModel(localModel['id']!);

          // Проверяем и запускаем модель
          final modelStarted = await _qwenService.configService.checkAndStartModelByName(localModel['id']!);
          if (modelStarted) {
            _log.info('Local model auto-started successfully: ${localModel['id']}');
          } else {
            _log.warn('Local model auto-start failed: ${_qwenService.configService.ollamaModelError}');
          }
        } catch (e) {
          _log.error('Error auto-starting local model: $e');
        }
      }

      await _trayService.init();
      _trayService.onStartBot = _startBot;
      _trayService.onStopBot = _stopBot;
      _trayService.onShowWindow = () => setState(() {});
      _trayService.onQuit = _quitApp;

      _qwenService.addListener(_onQwenSessionChanged);

      setState(() => _initialized = true);
      _log.info('Init: UI ready');

      if (_settings.autoStartBot && _settings.isConfigured) {
        _log.info('Init: auto-starting bot...');
        await _startBot();
      }

      _log.info('Init: complete');
    } catch (e, st) {
      _log.error('Init failed: $e\n$st');
    }
  }

  void _onQwenSessionChanged() {
    final sessionId = _qwenService.currentSessionId;
    final activeProject = _projectService.activeProject;
    if (sessionId != null && activeProject != null) {
      _projectService.updateSessionId(activeProject.id, sessionId);
    }
  }

  Future<void> _startBot() async {
    if (_settings.telegramBotToken.isEmpty) {
      _showError('Please set a Telegram Bot Token in Settings');
      return;
    }

    try {
      final activeProject = _projectService.activeProject;
      final workDir = activeProject?.workingDirectory ?? _settings.workingDirectory;

      _qwenService.configure(
        cliPath: _settings.qwenCliPath,
        workingDir: workDir,
        systemPrompt: TelegramBotService.systemPrompt,
        useYoloMode: _settings.useYoloMode,
      );

      final sessionId = activeProject?.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        await _qwenService.resumeSession(sessionId);
      } else {
        await _qwenService.continueLastSession();
      }

      _botService.allowedUserIds = _settings.allowedUserIds.toSet();
      await _botService.start(_settings.telegramBotToken);
      _log.info('Bot started');
    } catch (e, st) {
      _log.error('StartBot failed: $e\n$st');
      _showError('Failed to start: $e');
    }
  }

  Future<void> _stopBot() async {
    await _botService.stop();
    await _qwenService.killSession();
  }

  Future<void> _activateProject(dynamic project) async {
    await _projectService.setActive(project.id);

    _qwenService.configure(
      cliPath: _settings.qwenCliPath,
      workingDir: project.workingDirectory,
      systemPrompt: TelegramBotService.systemPrompt,
      useYoloMode: _settings.useYoloMode,
    );

    if (project.sessionId != null) {
      await _qwenService.resumeSession(project.sessionId!);
    } else {
      await _qwenService.continueLastSession();
    }

    _log.info('Switched to project: ${project.name}');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Универсальная очистка ресурсов
  Future<void> _cleanup() async {
    _qwenService.removeListener(_onQwenSessionChanged);
    await _stopBot();
    await _trayService.destroy();
    _qwenService.dispose();
    _botService.dispose();
    _projectService.dispose();
    _timeTrackerService.dispose();
    await _log.dispose();
    await SingleInstanceService().dispose();
  }

  Future<void> _quitApp() async {
    await _cleanup();
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  @override
  void dispose() {
    _cleanup(); // dispose не может быть async, поэтому игнорируем Future
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          ListenableBuilder(
            listenable: _botService,
            builder: (context, _) {
              return Sidebar(
                selected: _selectedTab,
                onSelect: (item) => setState(() => _selectedTab = item),
                botRunning: _botService.isRunning,
              );
            },
          ),
          Expanded(child: _buildScreen()),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_selectedTab) {
      case SidebarItem.dashboard:
        return ListenableBuilder(
          listenable: _botService,
          builder: (context, _) {
            return DashboardScreen(
              timeTrackerService: _timeTrackerService,
              projectService: _projectService,
              qwenService: _qwenService,
              onStartBot: _startBot,
              onStopBot: _stopBot,
              botRunning: _botService.isRunning,
              onQuickAction: (action) {
                switch (action) {
                  case DashboardQuickAction.history:
                    setState(() => _selectedTab = SidebarItem.history);
                    break;
                  case DashboardQuickAction.projects:
                    setState(() => _selectedTab = SidebarItem.projects);
                    break;
                }
              },
            );
          },
        );
      case SidebarItem.history:
        return HistoryScreen(service: _timeTrackerService);
      case SidebarItem.chatLog:
        return ChatLogScreen(botService: _botService);
      case SidebarItem.projects:
        return ProjectsScreen(
          service: _projectService,
          onActivate: _activateProject,
        );
      case SidebarItem.settings:
        return SettingsScreen(
          settings: _settings,
          onSaved: () {
            _qwenService.configure(
              cliPath: _settings.qwenCliPath,
              workingDir: _settings.workingDirectory,
              useYoloMode: _settings.useYoloMode,
            );
            _botService.allowedUserIds = _settings.allowedUserIds.toSet();
          },
        );
    }
  }
}

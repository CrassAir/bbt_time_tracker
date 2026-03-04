import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'log_service.dart';
import 'objectbox_service.dart';
import 'time_tracker_service.dart';
import 'project_service.dart';
import 'export_service.dart';
import 'ipc_service.dart';
import '../utils/duration_formatter.dart';
import '../models/timer.dart';
import '../models/project.dart';

/// Сервис для обработки консольных команд (CLI)
class CliService {
  final ObjectBoxService _objectBox = ObjectBoxService();
  final TimeTrackerService _timeTracker = TimeTrackerService();
  final ProjectService _projectService = ProjectService();
  final _log = LogService();
  final _ipc = IpcClient();

  bool _isInitialized = false;

  /// Получить все таймеры напрямую из ObjectBox
  List<Timer> get _timers => _objectBox.timerBox.getAll();

  /// Инициализация сервисов (без Flutter-зависимостей для CLI)
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _log.init();
    await _objectBox.init();
    await _projectService.load();

    _isInitialized = true;
    _log.info('CLI Service initialized');
  }

  /// Обработка аргументов командной строки
  Future<void> handleCommand(List<String> args) async {
    await initialize();

    if (args.isEmpty) {
      _printHelp();
      return;
    }

    final command = args.first.toLowerCase();

    try {
      switch (command) {
        case 'help':
        case '--help':
        case '-h':
          _printHelp();
          break;

        case 'add-project':
          await _handleAddProject(args.sublist(1));
          break;

        case 'list-projects':
          await _handleListProjects(args.sublist(1));
          break;

        case 'activate-project':
          await _handleActivateProject(args.sublist(1));
          break;

        case 'add-task':
          await _handleAddTask(args.sublist(1));
          break;

        case 'start-timer':
          await _handleStartTimer(args.sublist(1));
          break;

        case 'stop-timer':
          await _handleStopTimer(args.sublist(1));
          break;

        case 'list-tasks':
          await _handleListTasks(args.sublist(1));
          break;

        case 'delete-task':
          await _handleDeleteTask(args.sublist(1));
          break;

        case 'start-day':
          await _handleStartDay();
          break;

        case 'stop-day':
          await _handleStopDay();
          break;

        case 'status':
          await _handleStatus();
          break;

        case 'export-excel':
          await _handleExportExcel(args.sublist(1));
          break;

        default:
          _log.error('Unknown command: $command');
          _printHelp();
      }
    } catch (e) {
      _log.error('Error executing command: $e');
      stderr.writeln('Error: $e');
    }
  }

  /// Команда: add-project <name> <path>
  Future<void> _handleAddProject(List<String> args) async {
    if (args.length < 2) {
      stderr.writeln('Usage: add-project <name> <path>');
      stderr.writeln('Example: add-project "MyProject" "C:\\Projects\\MyProject"');
      return;
    }

    final name = args[0];
    final path = args[1];

    final project = Project(
      id: '',
      name: name,
      workingDirectory: path,
    );

    await _projectService.addProjectFromCli(project);

    stdout.writeln('✅ Project added: ${project.name}');
    stdout.writeln('   Path: $path');
    _log.info('CLI: Project added - $name');
  }

  /// Команда: add-task <name> [--estimate HH:MM] [--project name] [--description text]
  Future<void> _handleAddTask(List<String> args) async {
    String? name;
    String estimateStr = '00:15';
    String? projectName;
    String? description;

    // Простой парсинг аргументов
    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--estimate' || arg == '-e') {
        if (i + 1 < args.length) {
          estimateStr = args[++i];
        }
      } else if (arg == '--project' || arg == '-p') {
        if (i + 1 < args.length) {
          projectName = args[++i];
        }
      } else if (arg == '--description' || arg == '-d') {
        if (i + 1 < args.length) {
          description = args[++i];
        }
      } else if (!arg.startsWith('-')) {
        name = arg;
      }
    }

    if (name == null || name.isEmpty) {
      stderr.writeln('Usage: add-task <name> [--estimate HH:MM] [--project name] [--description text]');
      stderr.writeln('Example: add-task "Fix bug" --estimate 01:30 --project "Web" --description "Critical bug"');
      return;
    }

    // Парсим estimate
    final parts = estimateStr.split(':');
    final hours = int.tryParse(parts.first) ?? 0;
    final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final estimate = Duration(hours: hours, minutes: minutes);

    // Ищем проект
    Project? project;
    if (projectName != null) {
      project = _projectService.projects.cast<Project?>().firstWhere(
        (p) => p?.name.toLowerCase() == (projectName?.toLowerCase() ?? ''),
        orElse: () => null,
      );
    }

    final timer = await _timeTracker.addTimer(
      name: name,
      estimate: estimate,
      project: project?.name,
      description: description,
    );

    // Отправляем IPC уведомление
    await _ipc.sendTaskAdded(timer.id);

    stdout.writeln('✅ Task added: #${timer.number} ${timer.name}');
    stdout.writeln('   Estimate: ${DurationFormatter.format(estimate)}');
    if (project != null) {
      stdout.writeln('   Project: ${project.name}');
    }
    if (description != null && description.isNotEmpty) {
      stdout.writeln('   Description: $description');
    }
    _log.info('CLI: Task added - #${timer.number} ${timer.name}');
  }

  /// Команда: list-projects
  Future<void> _handleListProjects(List<String> args) async {
    final projects = _projectService.projects;

    if (projects.isEmpty) {
      stdout.writeln('No projects found.');
      return;
    }

    stdout.writeln('\n📁 Projects (${projects.length}):\n');

    final activeProject = _projectService.activeProject;

    for (final project in projects) {
      final isActive = activeProject?.id == project.id;
      final icon = isActive ? '✅' : '  ';
      stdout.writeln('$icon ${project.name}');
      stdout.writeln('   Path: ${project.workingDirectory}');
      if (project.sessionId != null && project.sessionId!.isNotEmpty) {
        stdout.writeln('   Session: ${project.sessionId}');
      }
      stdout.writeln('');
    }
  }

  /// Команда: activate-project <name|id>
  Future<void> _handleActivateProject(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: activate-project <name|id>');
      stderr.writeln('Example: activate-project "MyProject" или activate-project 5');
      return;
    }

    final query = args.first;
    Project? project;

    // Пробуем найти по ID
    final id = int.tryParse(query);
    if (id != null) {
      project = _projectService.projects.firstWhere((p) => p.id == query, orElse: () => null as Project);
    }

    // Если не нашли по ID, ищем по имени
    if (project == null) {
      project = _projectService.projects.firstWhere(
        (p) => p.name.toLowerCase().contains(query.toLowerCase()),
        orElse: () => null as Project,
      );
    }

    if (project == null) {
      stderr.writeln('Project not found: $query');
      return;
    }

    await _projectService.setActive(project.id);

    // Отправляем IPC уведомление
    await _ipc.sendProjectActivated(project.id);

    stdout.writeln('✅ Project activated: ${project.name}');
    stdout.writeln('   Path: ${project.workingDirectory}');
    _log.info('CLI: Project activated - ${project.name}');
  }

  /// Команда: delete-task <name|id>
  Future<void> _handleDeleteTask(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: delete-task <name|id>');
      stderr.writeln('Example: delete-task "Fix bug" или delete-task 5');
      return;
    }

    final query = args.first;
    Timer? timer;

    // Пробуем найти по ID
    final id = int.tryParse(query);
    if (id != null) {
      try {
        timer = _objectBox.timerBox.get(id);
      } catch (_) {
        timer = null;
      }
    }

    // Если не нашли по ID, ищем по имени
    if (timer == null) {
      for (final t in _timers) {
        if (t.name.toLowerCase().contains(query.toLowerCase())) {
          timer = t;
          break;
        }
      }
    }

    if (timer == null) {
      stderr.writeln('Task not found: $query');
      return;
    }

    // Отправляем IPC уведомление перед удалением
    await _ipc.sendTaskDeleted(timer.id);

    // Удаляем таймер напрямую из ObjectBox
    _objectBox.removeTimer(timer);

    stdout.writeln('✅ Task deleted: #${timer.number} ${timer.name}');
    _log.info('CLI: Task deleted - #${timer.number} ${timer.name}');
  }

  /// Команда: start-day
  Future<void> _handleStartDay() async {
    if (_timeTracker.currentWorkDay?.startWorkDateTime != null) {
      stdout.writeln('⏱ Work day is already started');
      stdout.writeln('   Started at: ${_timeTracker.currentWorkDay!.startWorkDateTime}');
      return;
    }

    _timeTracker.startWorkDay();

    // Отправляем IPC уведомление
    await _ipc.sendDayStarted();

    stdout.writeln('▶ Work day started');
    stdout.writeln('  Time: ${DateTime.now().toIso8601String().split('T').join(' ')}');
    _log.info('CLI: Work day started');
  }

  /// Команда: stop-day
  Future<void> _handleStopDay() async {
    if (_timeTracker.currentWorkDay?.startWorkDateTime == null) {
      stderr.writeln('Work day is not started');
      return;
    }

    if (_timeTracker.currentWorkDay?.endWorkDateTime != null) {
      stdout.writeln('⏹ Work day is already stopped');
      stdout.writeln('  Ended at: ${_timeTracker.currentWorkDay!.endWorkDateTime}');
      return;
    }

    _timeTracker.endWorkDay();

    // Отправляем IPC уведомление
    await _ipc.sendDayStopped();

    stdout.writeln('⏹ Work day stopped');
    stdout.writeln('  Duration: ${DurationFormatter.format(_timeTracker.todayWorkDuration ?? Duration.zero)}');
    _log.info('CLI: Work day stopped');
  }

  /// Команда: status
  Future<void> _handleStatus() async {
    stdout.writeln('\n🕐 Qwen Time Tracker Status\n');

    // Work day status
    final workDay = _timeTracker.currentWorkDay;
    if (workDay?.startWorkDateTime != null) {
      stdout.writeln('📅 Work Day:');
      stdout.writeln('   Started: ${workDay!.startWorkDateTime}');
      if (workDay.endWorkDateTime != null) {
        stdout.writeln('   Ended: ${workDay.endWorkDateTime}');
      }
      
      // Рассчитываем длительность правильно
      Duration workDuration;
      if (workDay.endWorkDateTime != null) {
        workDuration = workDay.endWorkDateTime!.difference(workDay.startWorkDateTime!);
      } else {
        workDuration = DateTime.now().difference(workDay.startWorkDateTime!);
      }
      
      stdout.writeln('   Worked: ${DurationFormatter.format(workDuration)}');
      stdout.writeln('   Standard: ${DurationFormatter.format(const Duration(hours: 8))}');
      
      // Debt / Free time
      final debt = _timeTracker.debtSeconds;
      final free = _timeTracker.freeSeconds;
      if (debt > 0) {
        stdout.writeln('   ⚠️ Debt: ${DurationFormatter.format(Duration(seconds: debt))}');
      } else if (free > 0) {
        stdout.writeln('   ✅ Free: ${DurationFormatter.format(Duration(seconds: free))}');
      }
    } else {
      stdout.writeln('📅 Work Day: Not started');
    }

    // Timers status
    final timers = _timers;
    final runningTimers = timers.where((t) => t.isRunning).toList();
    final completedToday = timers.where((t) => t.isComplete && t.endDateTime?.day == DateTime.now().day).toList();

    stdout.writeln('\n⏱ Timers:');
    stdout.writeln('   Total: ${timers.length}');
    stdout.writeln('   Running: ${runningTimers.length}');
    stdout.writeln('   Completed today: ${completedToday.length}');

    if (runningTimers.isNotEmpty) {
      stdout.writeln('\n▶ Running:');
      for (final timer in runningTimers) {
        stdout.writeln('   #${timer.number} ${timer.name} (${DurationFormatter.format(timer.durationLeft ?? Duration.zero)} / ${DurationFormatter.format(timer.estimate)})');
      }
    }

    // Projects status
    final activeProject = _projectService.activeProject;
    stdout.writeln('\n📁 Project:');
    if (activeProject != null) {
      stdout.writeln('   Active: ${activeProject.name}');
    } else {
      stdout.writeln('   No active project');
    }

    stdout.writeln('');
  }

  /// Команда: start-timer <name|id>
  Future<void> _handleStartTimer(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: start-timer <name|id>');
      stderr.writeln('Example: start-timer "Fix bug" или start-timer 5');
      return;
    }

    final query = args.first;
    Timer? timer;

    // Пробуем найти по ID
    final id = int.tryParse(query);
    if (id != null) {
      try {
        timer = _objectBox.timerBox.get(id);
      } catch (_) {
        timer = null;
      }
    }

    // Если не нашли по ID, ищем по имени
    if (timer == null) {
      for (final t in _timers) {
        if (t.name.toLowerCase().contains(query.toLowerCase())) {
          timer = t;
          break;
        }
      }
    }

    if (timer == null) {
      stderr.writeln('Task not found: $query');
      return;
    }

    if (timer.isRunning) {
      stdout.writeln('⏱ Timer is already running: #${timer.number} $timer.name');
      return;
    }

    // Обновляем таймер напрямую в ObjectBox
    timer.startDateTime = DateTime.now();
    timer.isComplete = false;
    await _objectBox.putTimer(timer);

    // Отправляем IPC уведомление
    await _ipc.sendTaskStarted(timer.id);

    stdout.writeln('▶ Timer started: #${timer.number} ${timer.name}');
    stdout.writeln('  Estimate: ${DurationFormatter.format(timer.estimate)}');
    _log.info('CLI: Timer started - #${timer.number} ${timer.name}');
  }

  /// Команда: stop-timer <name|id>
  Future<void> _handleStopTimer(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: stop-timer <name|id>');
      stderr.writeln('Example: stop-timer "Fix bug" или stop-timer 5');
      return;
    }

    final query = args.first;
    Timer? timer;

    // Пробуем найти по ID
    final id = int.tryParse(query);
    if (id != null) {
      try {
        timer = _objectBox.timerBox.get(id);
      } catch (_) {
        timer = null;
      }
    }

    // Если не нашли по ID, ищем по имени
    if (timer == null) {
      for (final t in _timers) {
        if (t.name.toLowerCase().contains(query.toLowerCase())) {
          timer = t;
          break;
        }
      }
    }

    if (timer == null) {
      stderr.writeln('Task not found: $query');
      return;
    }

    if (!timer.isRunning) {
      stdout.writeln('⏸ Timer is not running: #${timer.number} $timer.name');
      return;
    }

    // Обновляем таймер напрямую в ObjectBox
    timer.endDateTime = DateTime.now();
    timer.isComplete = true;
    await _objectBox.putTimer(timer);

    // Отправляем IPC уведомление
    await _ipc.sendTaskStopped(timer.id);

    stdout.writeln('⏹ Timer stopped: #${timer.number} ${timer.name}');
    stdout.writeln('  Spent: ${DurationFormatter.format(timer.durationLeft ?? Duration.zero)}');
    stdout.writeln('  Left: ${DurationFormatter.format(timer.timeLeft)}');
    _log.info('CLI: Timer stopped - #${timer.number} ${timer.name}');
  }

  /// Команда: list-tasks [--status active|completed|all]
  Future<void> _handleListTasks(List<String> args) async {
    String status = 'active';

    // Простой парсинг аргументов
    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--status' || arg == '-s') {
        if (i + 1 < args.length) {
          status = args[++i];
        }
      }
    }

    final timers = _timers;
    List<Timer> filtered;

    switch (status) {
      case 'active':
        filtered = timers.where((t) => !t.isComplete).toList();
        break;
      case 'completed':
        filtered = timers.where((t) => t.isComplete).toList();
        break;
      case 'all':
        filtered = timers;
        break;
      default:
        filtered = timers.where((t) => !t.isComplete).toList();
    }

    if (filtered.isEmpty) {
      stdout.writeln('No tasks found.');
      return;
    }

    stdout.writeln('\n📋 Tasks (${filtered.length}):\n');

    for (final timer in filtered) {
      final statusIcon = timer.isComplete ? '✅' : (timer.isRunning ? '▶' : '⏸');
      stdout.writeln('$statusIcon #${timer.number} ${timer.name}');
      stdout.writeln('   Estimate: ${DurationFormatter.format(timer.estimate)}');
      if (timer.project != null && timer.project!.isNotEmpty) {
        stdout.writeln('   Project: ${timer.project}');
      }
      if (timer.description != null && timer.description!.isNotEmpty) {
        stdout.writeln('   Description: ${timer.description}');
      }
      if (timer.isRunning) {
        stdout.writeln('   Running: ${DurationFormatter.format(timer.durationLeft ?? Duration.zero)}');
      } else if (timer.isComplete) {
        stdout.writeln('   Completed: ${DurationFormatter.format(timer.durationLeft ?? Duration.zero)}');
      }
      stdout.writeln('');
    }
  }

  /// Команда: export-excel [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--output path]
  Future<void> _handleExportExcel(List<String> args) async {
    String? fromStr;
    String? toStr;
    String? outputPath;

    // Простой парсинг аргументов
    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--from' || arg == '-f') {
        if (i + 1 < args.length) {
          fromStr = args[++i];
        }
      } else if (arg == '--to' || arg == '-t') {
        if (i + 1 < args.length) {
          toStr = args[++i];
        }
      } else if (arg == '--output' || arg == '-o') {
        if (i + 1 < args.length) {
          outputPath = args[++i];
        }
      }
    }

    DateTime? fromDate;
    DateTime? toDate;

    if (fromStr != null) {
      fromDate = DateTime.tryParse(fromStr);
      if (fromDate == null) {
        stderr.writeln('Invalid date format: $fromStr (use YYYY-MM-DD)');
        return;
      }
    }

    if (toStr != null) {
      toDate = DateTime.tryParse(toStr);
      if (toDate == null) {
        stderr.writeln('Invalid date format: $toStr (use YYYY-MM-DD)');
        return;
      }
    }

    // Фильтрация таймеров по дате
    final timers = _timers.where((t) {
      if (fromDate != null && t.createdAt.isBefore(fromDate)) return false;
      if (toDate != null && t.createdAt.isAfter(toDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    if (timers.isEmpty) {
      stdout.writeln('No tasks found for the specified period.');
      return;
    }

    try {
      await ExportService.openExcel(timers);
      stdout.writeln('✅ Excel report exported with ${timers.length} tasks');
      stdout.writeln('   Check your Downloads folder');
      _log.info('CLI: Excel exported with ${timers.length} tasks');
    } catch (e) {
      stderr.writeln('Error exporting Excel: $e');
      _log.error('CLI: Excel export error: $e');
    }
  }

  /// Вывод справки
  void _printHelp() {
    stdout.writeln('''
🕐 Qwen Time Tracker CLI

Usage: qwen_time_tracker.exe <command> [options]

Commands:
  help                          Show this help message
  
  Projects:
    add-project <name> <path>   Add a new project
    list-projects               List all projects
    activate-project <name|id>  Activate a project
  
  Tasks:
    add-task <name> [options]   Add a new task
      --estimate, -e HH:MM      Task estimate (default: 00:15)
      --project, -p name        Project name
      --description, -d text    Task description
    list-tasks [options]        List tasks
      --status, -s active|completed|all  Filter by status (default: active)
    delete-task <name|id>       Delete a task
  
  Timers:
    start-timer <name|id>       Start timer for a task
    stop-timer <name|id>        Stop timer for a task
  
  Work Day:
    start-day                   Start work day
    stop-day                    Stop work day
  
  Other:
    status                      Show current status
    export-excel [options]      Export tasks to Excel
      --from, -f YYYY-MM-DD     Start date
      --to, -t YYYY-MM-DD       End date
      --output, -o path         Output file path

Examples:
  qwen_time_tracker.exe add-project "Web" "C:\\Projects\\Web"
  qwen_time_tracker.exe list-projects
  qwen_time_tracker.exe activate-project "Web"
  qwen_time_tracker.exe add-task "Fix bug" --estimate 01:30 --project "Web"
  qwen_time_tracker.exe start-timer "Fix bug"
  qwen_time_tracker.exe start-timer 5
  qwen_time_tracker.exe stop-timer 5
  qwen_time_tracker.exe list-tasks --status active
  qwen_time_tracker.exe list-tasks --status all
  qwen_time_tracker.exe delete-task "Fix bug"
  qwen_time_tracker.exe start-day
  qwen_time_tracker.exe stop-day
  qwen_time_tracker.exe status
  qwen_time_tracker.exe export-excel --from 2026-03-01 --to 2026-03-03
''');
  }

  void dispose() {
    // В CLI режиме не используем TimeTracker с его GlobalTimer
    // Просто закрываем ObjectBox и логгер
    _objectBox.dispose();
    _log.dispose();
  }
}

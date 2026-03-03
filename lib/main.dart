import 'dart:io' show Platform, exit, stdout, stderr;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/log_service.dart';
import 'services/single_instance_service.dart';
import 'services/objectbox_service.dart';
import 'services/cli_service.dart';
import 'services/ipc_service.dart';
import 'utils/global_timer.dart';

void main(List<String> args) async {
  // Проверяем, запущено ли приложение из командной строки с аргументами
  if (args.isNotEmpty && !kIsWeb) {
    // CLI режим
    await _runCliMode(args);
    return;
  }

  // GUI режим
  WidgetsFlutterBinding.ensureInitialized();

  await SingleInstanceService.ensureSingleInstance();

  // Initialize ObjectBox
  await ObjectBoxService().init();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1100, 1250),
    minimumSize: Size(900, 900),
    center: true,
    title: 'Qwen Time Tracker',
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.setPreventClose(true);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize global timer
  GlobalTimer().initialize();

  final log = LogService();
  await log.init();

  // Запускаем IPC сервер в фоне (не блокируем UI)
  IpcService().startServer().then((_) {
    _logIpcMessages();
  }).catchError((e) {
    log.error('IPC server error: $e');
  });

  FlutterError.onError = (details) {
    log.error('FlutterError: ${details.exception}\n${details.stack}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('Uncaught error: $error\n$stack');
    return true;
  };

  // Добавляем слушатель закрытия окна для корректного завершения
  windowManager.addListener(WindowCloseListener());

  runApp(const QwenTimeTrackerApp());
}

/// Логирование IPC сообщений для отладки
void _logIpcMessages() {
  IpcService().messages.listen((message) {
    stdout.writeln('[IPC] Received: ${message.type} - ${message.data ?? ''}');
  });
}

/// Запуск в режиме CLI
Future<void> _runCliMode(List<String> args) async {
  final cli = CliService();
  final ipc = IpcClient();
  
  try {
    await cli.handleCommand(args);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } finally {
    cli.dispose();
    // Небольшая задержка для завершения всех асинхронных операций
    await Future.delayed(const Duration(milliseconds: 100));
    exit(0);
  }
}

class WindowCloseListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Скрываем окно (возможно, приложение сворачивается в трей)
    await windowManager.hide();
    // Если нужно полностью завершить приложение, раскомментируйте:
    // await ObjectBoxService().dispose();
    // exit(0);
  }
}
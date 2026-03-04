import 'dart:io' show Platform, Directory, File;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../services/log_service.dart';

typedef VoidAsyncCallback = Future<void> Function();

class TrayService implements TrayListener {
  final _log = LogService();
  bool _isInitialized = false;

  VoidAsyncCallback? onStartBot;
  VoidAsyncCallback? onStopBot;
  VoidCallback? onShowWindow;
  VoidCallback? onQuit;

  bool _botRunning = false;
  String _projectName = '';
  bool _sessionActive = false;

  @override
  void onTrayIconMouseUp() {
    // No-op
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayIconMouseDown() async {
    await _toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconDoubleClick() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'start_bot':
        onStartBot?.call();
        break;
      case 'stop_bot':
        onStopBot?.call();
        break;
      case 'show_window':
        _showWindow();
        break;
      case 'quit':
        onQuit?.call();
        break;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    await windowManager.ensureInitialized();
    trayManager.addListener(this);
    await _setTrayIcon();
    await trayManager.setToolTip('Qwen Time Tracker');
    await _updateMenu();

    _isInitialized = true;
  }

  Future<void> _setTrayIcon() async {
    try {
      String? iconPath;

      // Для Windows используем абсолютный путь к данным приложения
      if (Platform.isWindows) {
        // Путь к данным Flutter приложения
        final appDataPath = path.dirname(Platform.resolvedExecutable);
        final flutterAssetsPath = path.join(appDataPath, 'data', 'flutter_assets');
        
        final icoPaths = [
          path.join(flutterAssetsPath, 'assets', 'tray_icon.ico'),
          path.join(Directory.current.path, 'assets', 'tray_icon.ico'),
          'assets/tray_icon.ico',
        ];
        for (final p in icoPaths) {
          if (await File(p).exists()) {
            iconPath = p;
            break;
          }
        }
      }

      if (iconPath == null) {
        final pngPaths = [
          path.join(Directory.current.path, 'assets', 'tray_icon.png'),
          'assets/tray_icon.png',
        ];
        for (final p in pngPaths) {
          if (await File(p).exists()) {
            iconPath = p;
            break;
          }
        }
      }

      if (iconPath != null) {
        await trayManager.setIcon(iconPath, isTemplate: false);
        _log.info('Tray icon set: $iconPath');
      } else {
        await trayManager.setIcon('');
        _log.warn('Tray icon not found');
      }
    } catch (e) {
      _log.error('Error setting tray icon: $e');
      await trayManager.setIcon('');
    }
  }

  Future<void> updateState({
    required bool botRunning,
    String projectName = '',
    bool sessionActive = false,
  }) async {
    _botRunning = botRunning;
    _projectName = projectName;
    _sessionActive = sessionActive;
    await _updateMenu();
  }

  Future<void> _updateMenu() async {
    final statusIcon = _botRunning ? '🟢' : '🔴';
    final statusText = _botRunning ? 'Bot Running' : 'Bot Stopped';

    final menu = Menu(items: [
      MenuItem(label: '$statusIcon $statusText'),
      MenuItem.separator(),
      if (_projectName.isNotEmpty)
        MenuItem(label: '📂 $_projectName'),
      if (_sessionActive)
        MenuItem(label: '💬 Session active'),
      if (_projectName.isNotEmpty || _sessionActive) MenuItem.separator(),
      if (!_botRunning)
        MenuItem(label: 'Start Bot', key: 'start_bot'),
      if (_botRunning)
        MenuItem(label: 'Stop Bot', key: 'stop_bot'),
      MenuItem.separator(),
      MenuItem(label: 'Show Window', key: 'show_window'),
      MenuItem.separator(),
      MenuItem(label: 'Quit', key: 'quit'),
    ]);

    await trayManager.setContextMenu(menu);
  }

  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
    onShowWindow?.call();
  }

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } else {
      _showWindow();
    }
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }
}

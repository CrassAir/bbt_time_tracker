import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

/// Сервис для определения рабочей директории приложения
/// Всегда использует директорию исполняемого файла (для релизной сборки)
class AppDirectoryService {
  static final AppDirectoryService _instance = AppDirectoryService._internal();
  factory AppDirectoryService() => _instance;
  AppDirectoryService._internal();

  String? _appDirectory;
  String? _qwenContextPath;

  /// Получить директорию приложения (всегда директория exe-файла)
  Future<String> getAppDirectory() async {
    if (_appDirectory != null) return _appDirectory!;

    try {
      // Всегда используем директорию исполняемого файла
      final executablePath = File(Platform.resolvedExecutable).parent.path;
      _appDirectory = executablePath;
      _qwenContextPath = p.join(_appDirectory!, 'QWEN.md');
      
      return _appDirectory!;
    } catch (e) {
      // Fallback: текущая директория
      _appDirectory = Directory.current.path;
      return _appDirectory!;
    }
  }

  /// Получить путь к файлу контекста QWEN.md
  Future<String> getQwenContextPath() async {
    if (_qwenContextPath != null) return _qwenContextPath!;
    await getAppDirectory();
    return _qwenContextPath!;
  }

  /// Проверить наличие QWEN.md
  Future<bool> hasQwenContext() async {
    final path = await getQwenContextPath();
    return File(path).exists();
  }

  /// Скопировать QWEN.md из assets в директорию приложения
  Future<bool> copyQwenContextToAppDirectory() async {
    try {
      final appDir = await getAppDirectory();
      final qwenPath = p.join(appDir, 'QWEN.md');
      final qwenFile = File(qwenPath);

      // Проверяем, существует ли уже файл
      if (await qwenFile.exists()) {
        return true;
      }

      // Читаем из assets через rootBundle
      final content = await _readFromAssets();
      if (content == null || content.isEmpty) {
        return false;
      }

      // Записываем в директорию приложения
      await qwenFile.writeAsString(content, flush: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Прочитать QWEN.md из assets
  Future<String?> _readFromAssets() async {
    try {
      // Читаем из Flutter assets
      final content = await rootBundle.loadString('QWEN.md');
      return content;
    } catch (e) {
      return null;
    }
  }

  /// Сбросить кэш (для тестирования)
  void reset() {
    _appDirectory = null;
    _qwenContextPath = null;
  }
}

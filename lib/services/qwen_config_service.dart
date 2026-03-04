import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'log_service.dart';

/// Сервис управления конфигурациями Qwen Code CLI
class QwenConfigService extends ChangeNotifier {
  static const String _configDir = r'C:\Users\Nikitir\.qwen';
  static const String _settingsFile = 'settings.json';
  static const String _localSettingsFile = 'settings-local.json';
  static const String _cloudSettingsFile = 'settings-cloud.json';

  final _log = LogService();
  
  bool _isLocalModel = false;
  bool _isSwitching = false;
  bool _ollamaAvailable = false;
  bool _ollamaRunning = false;
  bool _ollamaModelReady = false;  // Модель загружена и готова
  String? _ollamaModelError;
  Process? _ollamaProcess;

  // Геттеры
  bool get isLocalModel => _isLocalModel;
  bool get isCloudModel => !_isLocalModel;
  bool get isSwitching => _isSwitching;
  bool get ollamaAvailable => _ollamaAvailable;
  bool get ollamaRunning => _ollamaRunning;
  bool get ollamaModelReady => _ollamaModelReady;
  String? get ollamaModelError => _ollamaModelError;
  bool get canUseLocal => _ollamaAvailable && _ollamaModelReady;
  bool get isOllamaProcessRunning => _ollamaProcess != null;

  /// Полный путь к директории конфигурации
  String get configDirPath => _configDir;

  /// Полный путь к текущему settings.json
  String get settingsPath => '$_configDir\\$_settingsFile';

  /// Проверить доступность Ollama и модели
  Future<void> checkOllamaStatus() async {
    try {
      // Проверяем, установлена ли Ollama через where (Windows)
      final whereResult = await Process.run('where', ['ollama'], runInShell: true);
      _log.info('Where ollama: exitCode=${whereResult.exitCode}');
      
      if (whereResult.exitCode != 0) {
        _ollamaAvailable = false;
        _ollamaRunning = false;
        _ollamaModelReady = false;
        _ollamaModelError = 'Ollama не установлена';
        _log.error('Ollama not found in PATH');
        notifyListeners();
        return;
      }

      _ollamaAvailable = true;
      _log.info('Ollama found, checking server...');

      // Проверяем, запущен ли сервер Ollama через API
      try {
        final httpClient = HttpClient();
        final response = await httpClient
            .getUrl(Uri.parse('http://localhost:11434/api/tags'))
            .timeout(const Duration(seconds: 2));
        await response.close();
        httpClient.close();
        _ollamaRunning = true;
        _log.info('Ollama server is running');
      } catch (e) {
        _ollamaRunning = false;
        _ollamaModelReady = false;
        _ollamaModelError = 'Ollama не запущена';
        _log.info('Ollama server not running');
        notifyListeners();
        return;
      }

      // Проверяем модель через ollama run
      _log.info('Checking model...');
      await checkModelReady();
      
    } catch (e) {
      _ollamaAvailable = false;
      _ollamaRunning = false;
      _ollamaModelReady = false;
      _ollamaModelError = 'Ollama не доступна: $e';
      _log.error('Error checking Ollama: $e');
    }

    notifyListeners();
  }

  /// Проверить готовность модели через ollama run
  Future<void> checkModelReady() async {
    try {
      final testResult = await Process.run(
        'ollama',
        ['run', 'qwen2.5-coder:7b-instruct-q4_K_M', 'hi'],
        runInShell: true,
      );

      _log.info('Model check: exitCode=${testResult.exitCode}');
      if (testResult.exitCode == 0) {
        _ollamaModelReady = true;
        _ollamaModelError = null;
        _log.info('Model is ready');
      } else {
        _ollamaModelReady = false;
        _ollamaModelError = 'Модель не готова: ${testResult.stderr}';
        _log.info('Model not ready');
      }
    } catch (e) {
      _ollamaModelReady = false;
      _ollamaModelError = 'Ошибка проверки модели: $e';
      _log.error('Error checking model: $e');
    }
  }

  /// Запустить Ollama сервер
  Future<bool> startOllama() async {
    if (_ollamaRunning) {
      _log.warn('Ollama already running');
      return true;
    }

    if (!_ollamaAvailable) {
      throw Exception('Ollama не установлена');
    }

    try {
      _log.info('Starting Ollama server...');
      
      // Запускаем ollama serve в фоновом режиме
      _ollamaProcess = await Process.start(
        'ollama',
        ['serve'],
        runInShell: true,
        mode: ProcessStartMode.detached,
      );

      // Ждём запуска сервера
      await Future.delayed(const Duration(seconds: 3));
      
      // Проверяем, запустился ли сервер
      await checkOllamaStatus();
      
      if (_ollamaRunning) {
        _log.info('Ollama server started');
        notifyListeners();
        return true;
      } else {
        throw Exception('Не удалось запустить Ollama');
      }
    } catch (e) {
      _log.error('Error starting Ollama: $e');
      _ollamaModelError = 'Ошибка запуска: $e';
      notifyListeners();
      return false;
    }
  }

  /// Проверить и запустить модель (через ollama run)
  Future<bool> checkAndStartModel() async {
    if (!_ollamaRunning) {
      _ollamaModelError = 'Сначала запустите Ollama сервер';
      return false;
    }

    try {
      _log.info('Checking model...');
      await checkModelReady();

      if (_ollamaModelReady) {
        _log.info('Model is ready');
        return true;
      } else {
        _log.warn('Model not ready: $_ollamaModelError');
        return false;
      }
    } catch (e) {
      _log.error('Error checking model: $e');
      _ollamaModelError = 'Ошибка проверки модели: $e';
      return false;
    }
  }

  /// Проверить и запустить модель по имени (через ollama run)
  Future<bool> checkAndStartModelByName(String modelName) async {
    if (!_ollamaRunning) {
      _ollamaModelError = 'Сначала запустите Ollama сервер';
      return false;
    }

    try {
      _log.info('Checking model: $modelName');
      
      // Проверяем, запущена ли уже модель через API
      final modelRunning = await isModelRunning(modelName);
      if (modelRunning) {
        _log.info('Model $modelName is already running');
        _ollamaModelReady = true;
        _ollamaModelError = null;
        return true;
      }

      // Запускаем модель через ollama run
      _log.info('Starting model: $modelName');
      final testResult = await Process.run(
        'ollama',
        ['run', modelName, 'hi'],
        runInShell: true,
      );

      _log.info('Model start: exitCode=${testResult.exitCode}');
      if (testResult.exitCode == 0) {
        _ollamaModelReady = true;
        _ollamaModelError = null;
        _log.info('Model $modelName is ready');
        return true;
      } else {
        _ollamaModelReady = false;
        _ollamaModelError = 'Модель не готова: ${testResult.stderr}';
        _log.info('Model not ready: ${testResult.stderr}');
        return false;
      }
    } on TimeoutException {
      _ollamaModelReady = false;
      _ollamaModelError = 'Таймаут запуска модели';
      _log.error('Timeout checking model: $modelName');
      return false;
    } catch (e) {
      _ollamaModelReady = false;
      _ollamaModelError = 'Ошибка проверки модели: $e';
      _log.error('Error checking model: $e');
      return false;
    }
  }

  /// Проверить, запущена ли модель в памяти Ollama
  Future<bool> isModelRunning(String modelName) async {
    try {
      final httpClient = HttpClient();
      try {
        // Проверяем активные сессии через /api/generate с keep_alive=0
        // Если модель загружена, она покажет это в ответе
        final request = await httpClient.postUrl(
          Uri.parse('http://localhost:11434/api/generate')
        );
        request.headers.contentType = ContentType('application', 'json');
        request.write('{"model":"$modelName","prompt":"hi","stream":false}');
        
        final response = await request.close().timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final body = await response.transform(const Utf8Decoder()).join();
          _log.info('Model check response: $body');
          
          // Если модель ответила — она загружена
          final isRunning = body.contains('response') || body.contains('done');
          httpClient.close();
          return isRunning;
        }
        
        httpClient.close();
        return false;
      } finally {
        httpClient.close();
      }
    } on TimeoutException {
      _log.warn('Timeout checking running model');
      return false;
    } catch (e) {
      _log.warn('Error checking running model: $e');
      return false;
    }
  }

  /// Остановить Ollama сервер
  Future<bool> stopOllama() async {
    if (!_ollamaRunning && _ollamaProcess == null) {
      _log.warn('Ollama not running');
      return true;
    }

    try {
      _log.info('Stopping Ollama server...');
      
      // Убиваем процесс
      if (_ollamaProcess != null) {
        _ollamaProcess!.kill();
        _ollamaProcess = null;
      }

      // Также пробуем остановить через API
      try {
        final httpClient = HttpClient();
        await httpClient.postUrl(
          Uri.parse('http://localhost:11434/api/generate'),
        ).then((req) {
          req.headers.contentType = ContentType('application', 'json');
          req.write(jsonEncode({'model': '', 'keep_alive': '0m'}));
          return req.close();
        });
        httpClient.close();
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 1));
      _ollamaModelReady = false;
      await checkOllamaStatus();
      
      _log.info('Ollama server stopped');
      notifyListeners();
      return true;
    } catch (e) {
      _log.error('Error stopping Ollama: $e');
      return false;
    }
  }

  /// Остановить модель (выгрузить из памяти)
  Future<bool> stopModel() async {
    if (!_ollamaRunning) {
      return true;
    }

    try {
      _log.info('Unloading model from memory...');
      
      // Выгружаем модель через API (keep_alive: 0m)
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(
        Uri.parse('http://localhost:11434/api/generate'),
      );
      req.headers.contentType = ContentType('application', 'json');
      req.write(jsonEncode({
        'model': 'qwen2.5-coder:7b-instruct-q4_K_M',
        'keep_alive': '0m',
      }));
      await req.close();
      httpClient.close();
      
      _ollamaModelReady = false;
      _log.info('Model unloaded');
      notifyListeners();
      return true;
    } catch (e) {
      _log.error('Error unloading model: $e');
      return false;
    }
  }

  /// Переключить модель по ID (изменяет model.name в settings.json)
  Future<bool> switchModel(String modelId) async {
    if (_isSwitching) return false;

    _isSwitching = true;
    notifyListeners();

    try {
      final file = File(settingsPath);
      if (!await file.exists()) {
        throw Exception('Файл конфигурации не найден');
      }

      final content = await file.readAsString();
      final jsonContent = _removeJsonComments(content);
      final config = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Обновляем model.name
      config['model'] = {'name': modelId};

      // Сохраняем с форматированием
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(config));

      // Обновляем флаг локальной модели
      _isLocalModel = modelId.contains('qwen2.5') ||
                      modelId.contains('ollama') ||
                      modelId.contains('localhost');

      _log.info('Switched model to: $modelId (${_isLocalModel ? "LOCAL" : "CLOUD"})');
      
      // Если локальная модель — проверяем и запускаем её
      if (_isLocalModel && _ollamaRunning) {
        _log.info('Checking and starting local model: $modelId');
        await checkAndStartModelByName(modelId);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _log.error('Error switching model: $e');
      _isSwitching = false;
      rethrow;
    } finally {
      _isSwitching = false;
    }
  }

  /// Получить список доступных моделей из конфигурации
  Future<List<Map<String, String>>> getAvailableModels() async {
    try {
      final file = File(settingsPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final jsonContent = _removeJsonComments(content);
      final config = jsonDecode(jsonContent) as Map<String, dynamic>;

      final models = <Map<String, String>>[];

      // Получаем модели из openai провайдера
      final modelProviders = config['modelProviders'] as Map?;
      final openaiProviders = modelProviders?['openai'] as List?;
      if (openaiProviders != null) {
        for (final provider in openaiProviders) {
          if (provider is Map) {
            models.add({
              'id': provider['id'] as String? ?? '',
              'name': provider['name'] as String? ?? '',
              'description': provider['description'] as String? ?? '',
            });
          }
        }
      }

      return models;
    } catch (e) {
      _log.error('Error getting models: $e');
      return [];
    }
  }

  /// Переключиться на локальную модель (устаревший метод, использует switchModel)
  @deprecated
  Future<bool> switchToLocal() async {
    // Находим локальную модель в списке и переключаемся на неё
    final models = await getAvailableModels();
    final localModel = models.firstWhere(
      (m) => m['id']!.contains('qwen2.5') || m['id']!.contains('ollama'),
      orElse: () => throw Exception('Локальная модель не найдена в конфигурации'),
    );
    return await switchModel(localModel['id']!);
  }

  /// Переключиться на облачную модель (устаревший метод, использует switchModel)
  @deprecated
  Future<bool> switchToCloud() async {
    // Находим облачную модель в списке и переключаемся на неё
    final models = await getAvailableModels();
    final cloudModel = models.firstWhere(
      (m) => !m['id']!.contains('qwen2.5') && !m['id']!.contains('ollama'),
      orElse: () => throw Exception('Облачная модель не найдена в конфигурации'),
    );
    return await switchModel(cloudModel['id']!);
  }

  /// Переключить модель (автоматически выбирает направление, устаревший метод)
  @deprecated
  Future<bool> toggleModel(bool useLocal) async {
    if (useLocal) {
      return await switchToLocal();
    } else {
      return await switchToCloud();
    }
  }

  /// Получить текущую модель
  Future<String?> getCurrentModelName() async {
    try {
      final file = File(settingsPath);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final jsonContent = _removeJsonComments(content);
      final config = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      final model = config['model'] as Map<String, dynamic>?;
      return model?['name'] as String?;
    } catch (e) {
      _log.error('Error reading model name: $e');
      return null;
    }
  }

  /// Инициализировать сервис
  Future<void> initialize() async {
    await checkOllamaStatus();

    // Определяем текущую модель по model.name
    try {
      final modelName = await getCurrentModelName();
      
      // Локальная модель если model.name содержит ollama, localhost или qwen2.5
      _isLocalModel = modelName != null && 
          (modelName.contains('qwen2.5') || 
           modelName.contains('ollama') || 
           modelName.contains('localhost'));
      
      _log.info('QwenConfigService initialized: ${_isLocalModel ? "LOCAL" : "CLOUD"}');
      _log.info('  - Current model: $modelName');
    } catch (e) {
      _log.error('Error reading config for model detection: $e');
      _isLocalModel = false;
      _log.info('QwenConfigService initialized: CLOUD (default)');
    }

    notifyListeners();
  }

  @override
  void dispose() {
    // Не останавливаем Ollama при закрытии приложения
    super.dispose();
  }

  String _removeJsonComments(String content) {
    final lines = content.split('\n');
    return lines.where((line) {
      final trimmed = line.trim();
      return !trimmed.startsWith('//');
    }).join('\n');
  }
}

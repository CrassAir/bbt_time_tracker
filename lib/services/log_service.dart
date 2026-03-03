import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  Directory? _logDir;
  IOSink? _sink;
  bool _initialized = false;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    String home;
    if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ??
             (Platform.environment['HOMEPATH'] ?? '');
      if (home.isEmpty) {
        home = Directory.systemTemp.path;
      }
    } else {
      home = Platform.environment['HOME'] ?? '/tmp';
    }

    _logDir = Directory(p.join(home, 'qwen-bot-logs'));
    if (!await _logDir!.exists()) {
      await _logDir!.create(recursive: true);
    }
    await _openLogFile();
  }

  Future<void> _openLogFile() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logFile = File(p.join(_logDir!.path, 'bot-$today.log'));
    _sink = logFile.openWrite(mode: FileMode.append);
  }

  void log(String level, String message) {
    final timestamp = _dateFormat.format(DateTime.now());
    final line = '[$timestamp] [$level] $message';
    _sink?.writeln(line);
    print(line);
  }

  void info(String message) => log('INFO', message);
  void error(String message) => log('ERROR', message);
  void warn(String message) => log('WARN', message);

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
  }
}

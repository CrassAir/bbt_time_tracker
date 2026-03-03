import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/log_service.dart';

class QwenCodeService extends ChangeNotifier {
  String? _currentSessionId;
  String _qwenCliPath = '';
  String _workingDirectory = '';
  bool _isRunning = false;
  bool _isBusy = false;
  bool _useContinue = true;
  bool _useYoloMode = true;
  String? _systemPrompt;
  DateTime? _sessionStartTime;
  bool _systemPromptSent = false;
  final _log = LogService();
  Process? _activeProcess;

  bool get isRunning => _isRunning;
  bool get isBusy => _isBusy;
  String? get currentSessionId => _currentSessionId;
  DateTime? get sessionStartTime => _sessionStartTime;

  Duration get sessionDuration {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }

  void configure({
    required String cliPath,
    required String workingDir,
    String? systemPrompt,
    bool? useYoloMode,
  }) {
    _qwenCliPath = cliPath;
    _workingDirectory = workingDir;
    if (systemPrompt != null) _systemPrompt = systemPrompt;
    if (useYoloMode != null) _useYoloMode = useYoloMode;
  }

  Future<String> _resolveCliPath() async {
    if (_qwenCliPath.isNotEmpty) return _qwenCliPath;
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['qwen', 'qwen-code'], runInShell: true);
        if (result.exitCode == 0) {
          final output = (result.stdout as String).trim();
          final path = output.split('\r\n').firstWhere(
            (line) => line.trim().isNotEmpty && !line.contains('Could not find'),
            orElse: () => '',
          ).trim();
          if (path.isNotEmpty) return path;
        }
      } else {
        final result = await Process.run('which', ['qwen', 'qwen-code'], runInShell: true);
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty) return path;
        }
      }
    } catch (_) {}
    return 'qwen';
  }

  Future<void> startNewSession({String? workingDirectory}) async {
    _workingDirectory = workingDirectory ?? _workingDirectory;
    _currentSessionId = null;
    _useContinue = false;
    _sessionStartTime = DateTime.now();
    _systemPromptSent = false;
    _isRunning = true;
    notifyListeners();
    _log.info('Ready for NEW session in $_workingDirectory');
  }

  Future<void> resumeSession(String sessionId) async {
    _currentSessionId = sessionId.isNotEmpty ? sessionId : null;
    _sessionStartTime = DateTime.now();
    _systemPromptSent = false;
    _isRunning = true;
    notifyListeners();
  }

  Future<void> continueLastSession() async {
    _currentSessionId = null;
    _useContinue = true;
    _sessionStartTime = DateTime.now();
    _systemPromptSent = false;
    _isRunning = true;
    notifyListeners();
  }

  Stream<StreamEvent> sendMessageStream(String message, {bool useSystemPrompt = true}) async* {
    if (!_isRunning) {
      yield StreamEvent.error('Qwen Code service is not running');
      return;
    }
    if (_isBusy) {
      yield StreamEvent.error('Already processing a message');
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      yield* _runStreaming(message, useSystemPrompt: useSystemPrompt);
    } catch (e) {
      _log.error('sendMessageStream error: $e');
      yield StreamEvent.error(e.toString());
    } finally {
      _activeProcess = null;
      _isBusy = false;
      notifyListeners();
    }
  }

  Stream<StreamEvent> _runStreaming(String message, {bool useSystemPrompt = true}) async* {
    final cli = await _resolveCliPath();
    final wd = _workingDirectory;

    final args = <String>['-p'];
    if (_useYoloMode) args.add('-y');
    args.addAll(['--output-format', 'stream-json', '--include-partial-messages']);

    if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
      args.addAll(['--resume', _currentSessionId!]);
    } else if (_useContinue) {
      args.add('--continue');
    }

    String finalMessage = message;
    if (useSystemPrompt && _systemPrompt != null && _systemPrompt!.isNotEmpty && !_systemPromptSent) {
      finalMessage = '$_systemPrompt\n\n$finalMessage';
      _systemPromptSent = true;
    }
    args.add(finalMessage);

    _log.info('Running (stream): $cli ${args.join(" ")}');

    if (wd.isNotEmpty && !await Directory(wd).exists()) {
      _log.error('Working directory does not exist: $wd');
      yield StreamEvent.error('Working directory does not exist: $wd');
      return;
    }

    final process = await Process.start(
      cli,
      args,
      workingDirectory: wd,
      environment: Platform.environment,
      runInShell: true,
    );
    _activeProcess = process;
    await process.stdin.close();

    final fullText = StringBuffer();
    String? resultSessionId;
    bool gotResult = false;

    final stdoutLines = process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final stderrBuffer = StringBuffer();
    final stderrSubscription = process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
    });

    await for (final line in stdoutLines) {
      if (line.trim().isEmpty) continue;
      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        final type = data['type'] as String?;

        switch (type) {
          case 'system':
            final sid = data['session_id'] as String? ?? data['uuid'] as String?;
            if (sid != null) {
              resultSessionId = sid;
              yield StreamEvent.init(sid);
            }
            break;
          case 'assistant':
            final msgData = data['message'] as Map<String, dynamic>?;
            if (msgData != null) {
              final content = msgData['content'] as List?;
              if (content != null) {
                for (final block in content) {
                  if (block is Map && block['type'] == 'text') {
                    final text = block['text'] as String? ?? '';
                    if (text.isNotEmpty) {
                      fullText.write(text);
                      yield StreamEvent.textDelta(text);
                    }
                  }
                }
              }
            }
            break;
          case 'result':
            gotResult = true;
            final result = data['result'] as String? ?? fullText.toString();
            resultSessionId = data['session_id'] as String? ?? data['uuid'] as String? ?? resultSessionId;
            if (resultSessionId != null) {
              _currentSessionId = resultSessionId;
              notifyListeners();
            }
            yield StreamEvent.result(result, resultSessionId);
            break;
        }
      } catch (e) {
        _log.warn('Failed to parse stream line: $e');
      }
    }

    await stderrSubscription.cancel();
    final exitCode = await process.exitCode;
    _log.info('Qwen exited with code $exitCode');

    if (!gotResult) {
      if (fullText.isNotEmpty) {
        yield StreamEvent.result(fullText.toString(), resultSessionId);
      } else if (exitCode != 0) {
        yield StreamEvent.error('Qwen Code error (code $exitCode).');
      }
    }
  }

  Future<String> sendMessage(String message, {bool useSystemPrompt = false}) async {
    if (!_isRunning) throw StateError('Qwen Code service is not running');
    if (_isBusy) throw StateError('Already processing a message');

    _isBusy = true;
    notifyListeners();

    try {
      return await _sendWithRetry(message, useSystemPrompt: useSystemPrompt);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String> _sendWithRetry(String message, {bool useSystemPrompt = false}) async {
    final cli = await _resolveCliPath();
    final wd = _workingDirectory;

    final args = <String>['-p'];
    if (_useYoloMode) args.add('-y');
    args.addAll(['--output-format', 'json']);

    if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
      args.addAll(['--resume', _currentSessionId!]);
    } else if (_useContinue) {
      args.add('--continue');
    }

    String finalMessage = message;
    if (useSystemPrompt && _systemPrompt != null && _systemPrompt!.isNotEmpty && !_systemPromptSent) {
      finalMessage = '$_systemPrompt\n\n$finalMessage';
      _systemPromptSent = true;
    }
    args.add(finalMessage);

    final result = await Process.run(cli, args, workingDirectory: wd, environment: Platform.environment, runInShell: true);
    final exitCode = result.exitCode;
    final rawOutput = (result.stdout as String).trim();

    if (rawOutput.isEmpty) {
      if (exitCode != 0) return 'Qwen Code error (code $exitCode).';
      return '(empty response)';
    }

    return _parseJsonOutput(rawOutput);
  }

  String _parseJsonOutput(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        final texts = <String>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final type = item['type'] as String?;
            if (type == 'assistant') {
              final msgData = item['message'] as Map<String, dynamic>?;
              if (msgData != null) {
                final content = msgData['content'] as List?;
                if (content != null) {
                  for (final block in content) {
                    if (block is Map && block['type'] == 'text') {
                      final text = block['text'] as String? ?? '';
                      if (text.isNotEmpty) texts.add(text);
                    }
                  }
                }
              }
            }
            if (type == 'result') {
              final sessionId = item['session_id'] as String? ?? item['uuid'] as String?;
              if (sessionId != null) {
                _currentSessionId = sessionId;
                notifyListeners();
              }
              final result = item['result'] as String?;
              if (result != null) texts.add(result);
            }
          }
        }
        if (texts.isNotEmpty) return texts.join('\n');
      }
      if (data is Map<String, dynamic> && data.containsKey('result')) {
        return data['result'] as String;
      }
    } catch (_) {}
    return raw;
  }

  Future<void> compactSession() async {
    if (!_isRunning) return;
    _log.info('Compacting session');
    try {
      await sendMessage('/compact');
    } catch (e) {
      _log.error('Compact error: $e');
    }
  }

  Future<void> stopCurrentRequest() async {
    if (_activeProcess != null) {
      _log.info('Stopping current Qwen Code request');
      _activeProcess?.kill();
      _activeProcess = null;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> killSession() async {
    _log.info('Stopping Qwen Code service');
    _activeProcess?.kill();
    _activeProcess = null;
    _isRunning = false;
    _isBusy = false;
    _currentSessionId = null;
    _sessionStartTime = null;
    _systemPromptSent = false;
    notifyListeners();
  }

  @override
  void dispose() {
    killSession();
    super.dispose();
  }
}

enum StreamEventType { init, textDelta, toolUse, result, error }

class StreamEvent {
  const StreamEvent._(this.type, {this.text, this.sessionId, this.fullResult});
  factory StreamEvent.init(String sessionId) => StreamEvent._(StreamEventType.init, sessionId: sessionId);
  factory StreamEvent.textDelta(String text) => StreamEvent._(StreamEventType.textDelta, text: text);
  factory StreamEvent.toolUse(String text) => StreamEvent._(StreamEventType.toolUse, text: text);
  factory StreamEvent.result(String fullResult, String? sessionId) => StreamEvent._(StreamEventType.result, fullResult: fullResult, sessionId: sessionId);
  factory StreamEvent.error(String message) => StreamEvent._(StreamEventType.error, text: message);

  final StreamEventType type;
  final String? text;
  final String? sessionId;
  final String? fullResult;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'log_service.dart';

/// Типы IPC сообщений
enum IpcMessageType {
  taskAdded,
  taskDeleted,
  taskStarted,
  taskStopped,
  dayStarted,
  dayStopped,
  projectActivated,
  reload,
}

/// IPC сообщение
class IpcMessage {
  final IpcMessageType type;
  final String? data;
  final DateTime timestamp;

  IpcMessage({
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory IpcMessage.fromJson(Map<String, dynamic> json) => IpcMessage(
        type: IpcMessageType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => IpcMessageType.reload,
        ),
        data: json['data'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  factory IpcMessage.decode(String source) =>
      IpcMessage.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Сервис для межпроцессного взаимодействия (IPC)
class IpcService extends ChangeNotifier {
  static final IpcService _instance = IpcService._internal();
  factory IpcService() => _instance;
  IpcService._internal();

  static const int _port = 49172; // Произвольный порт > 49152
  static const String _host = '127.0.0.1';

  ServerSocket? _server;
  final List<Socket> _clients = [];
  final _log = LogService();
  bool _isRunning = false;

  /// Поток входящих сообщений
  final _messageController = StreamController<IpcMessage>.broadcast();
  Stream<IpcMessage> get messages => _messageController.stream;

  bool get isRunning => _isRunning;

  /// Запуск IPC сервера (для GUI приложения)
  Future<void> startServer() async {
    if (_isRunning) {
      _log.info('IPC server already running');
      return;
    }

    try {
      _server = await ServerSocket.bind(_host, _port);
      _isRunning = true;
      _log.info('IPC server started on $_host:$_port');

      await for (final socket in _server!) {
        _handleClient(socket);
      }
    } catch (e) {
      _log.error('IPC server error: $e');
      _isRunning = false;
    }
  }

  /// Обработка клиентского подключения
  void _handleClient(Socket socket) {
    _log.info('IPC client connected: ${socket.remoteAddress}');
    _clients.add(socket);

    socket.listen(
      (data) {
        try {
          final message = IpcMessage.decode(utf8.decode(data));
          _log.info('IPC message received: ${message.type}');
          _messageController.add(message);
          notifyListeners();
        } catch (e) {
          _log.error('IPC decode error: $e');
        }
      },
      onDone: () {
        _log.info('IPC client disconnected');
        _clients.remove(socket);
        socket.close();
      },
      onError: (e) {
        _log.error('IPC client error: $e');
        _clients.remove(socket);
        socket.close();
      },
    );
  }

  /// Отправка сообщения всем клиентам
  Future<void> broadcast(IpcMessage message) async {
    if (!_isRunning || _clients.isEmpty) return;

    final data = utf8.encode(message.encode());
    for (final client in _clients) {
      try {
        client.add(data);
      } catch (e) {
        _log.error('IPC broadcast error: $e');
        _clients.remove(client);
      }
    }
    _log.info('IPC broadcast: ${message.type}');
  }

  /// Отправка сообщения (удобные методы)
  Future<void> sendTaskAdded(int taskId) async {
    await broadcast(IpcMessage(type: IpcMessageType.taskAdded, data: '$taskId'));
  }

  Future<void> sendTaskDeleted(int taskId) async {
    await broadcast(IpcMessage(type: IpcMessageType.taskDeleted, data: '$taskId'));
  }

  Future<void> sendTaskStarted(int taskId) async {
    await broadcast(IpcMessage(type: IpcMessageType.taskStarted, data: '$taskId'));
  }

  Future<void> sendTaskStopped(int taskId) async {
    await broadcast(IpcMessage(type: IpcMessageType.taskStopped, data: '$taskId'));
  }

  Future<void> sendDayStarted() async {
    await broadcast(IpcMessage(type: IpcMessageType.dayStarted));
  }

  Future<void> sendDayStopped() async {
    await broadcast(IpcMessage(type: IpcMessageType.dayStopped));
  }

  Future<void> sendProjectActivated(String projectId) async {
    await broadcast(IpcMessage(type: IpcMessageType.projectActivated, data: projectId));
  }

  /// Остановка сервера
  Future<void> stop() async {
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    _isRunning = false;
    _log.info('IPC server stopped');
  }

  @override
  void dispose() {
    stop();
    _messageController.close();
    super.dispose();
  }
}

/// IPC клиент (для CLI)
class IpcClient {
  static const int _port = 49172;
  static const String _host = '127.0.0.1';
  final _log = LogService();

  /// Отправка сообщения в GUI
  Future<bool> send(IpcMessage message, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final socket = await Socket.connect(_host, _port, timeout: timeout);
      final data = utf8.encode(message.encode());
      socket.add(data);
      await socket.flush();
      await socket.close();
      _log.info('IPC message sent: ${message.type}');
      return true;
    } catch (e) {
      // GUI не запущен - это нормально для CLI режима
      _log.info('IPC client: GUI not running ($e)');
      return false;
    }
  }

  /// Отправка сообщения (удобные методы)
  Future<bool> sendTaskAdded(int taskId) async {
    return await send(IpcMessage(type: IpcMessageType.taskAdded, data: '$taskId'));
  }

  Future<bool> sendTaskDeleted(int taskId) async {
    return await send(IpcMessage(type: IpcMessageType.taskDeleted, data: '$taskId'));
  }

  Future<bool> sendTaskStarted(int taskId) async {
    return await send(IpcMessage(type: IpcMessageType.taskStarted, data: '$taskId'));
  }

  Future<bool> sendTaskStopped(int taskId) async {
    return await send(IpcMessage(type: IpcMessageType.taskStopped, data: '$taskId'));
  }

  Future<bool> sendDayStarted() async {
    return await send(IpcMessage(type: IpcMessageType.dayStarted));
  }

  Future<bool> sendDayStopped() async {
    return await send(IpcMessage(type: IpcMessageType.dayStopped));
  }

  Future<bool> sendProjectActivated(String projectId) async {
    return await send(IpcMessage(type: IpcMessageType.projectActivated, data: projectId));
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';

class GlobalTimer {
  static final GlobalTimer _instance = GlobalTimer._internal();
  static final AudioPlayer _player = AudioPlayer();
  static DateTime? isAlarmEnd;

  factory GlobalTimer() => _instance;

  GlobalTimer._internal();

  Timer? _timer;
  int _seconds = 0;
  final List<VoidCallback> _listeners = [];
  final List<VoidCallback> _stopListeners = [];
  VoidCallback? dayListener;

  int get seconds => _seconds;

  bool get isRunning => _timer != null;

  void initialize() {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      _notifyListeners();
      dayListener?.call();
    });
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void addStopListener(VoidCallback listener) {
    _stopListeners.add(listener);
  }

  void removeStopListener(VoidCallback listener) {
    _stopListeners.remove(listener);
  }

  void removeAllListeners() {
    _listeners.clear();
    for (var listener in _stopListeners) {
      listener();
    }
  }

  bool isActiveListener(VoidCallback listener) {
    return _listeners.contains(listener);
  }

  void _notifyListeners() {
    if (isAlarmEnd != null) {
      if (DateTime.now().isAfter(isAlarmEnd!)) {
        isAlarmEnd = null;
      }
    }
    for (var listener in _listeners) {
      listener();
    }
  }

  static Future<void> playTimeUpSound() async {
    if (isAlarmEnd == null) {
      try {
        _player.play(AssetSource('mp3/japanese_attention.mp3'));
        isAlarmEnd = DateTime.now().add(Duration(minutes: 1));
        await windowManager.focus();
      } catch (e) {}
    }
  }

  static Future<void> playStartUpSound() async {
    try {
      _player.play(AssetSource('mp3/good_morning_vietnam.mp3'));
      await windowManager.focus();
    } catch (e) {}
  }

  void dispose() {
    _player.dispose();
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
    _stopListeners.clear();
  }
}

import 'dart:async';
import 'dart:ui';

class GlobalTimer {
  static final GlobalTimer _instance = GlobalTimer._internal();

  factory GlobalTimer() => _instance;

  GlobalTimer._internal();

  Timer? _timer;
  int _seconds = 0;
  final List<VoidCallback> _listeners = [];
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

  void removeAllListeners() {
    _listeners.clear();
  }

  bool isActiveListener(VoidCallback listener) {
    return _listeners.contains(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  // Остановка ТОЛЬКО при закрытии приложения
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Глобальный таймер, который тикает каждую секунду и уведомляет слушателей
class GlobalTimer extends ChangeNotifier {
  static final GlobalTimer _instance = GlobalTimer._internal();
  factory GlobalTimer() => _instance;
  GlobalTimer._internal();

  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  VoidCallback? dayListener;

  bool _isInitialized = false;
  bool _isPlaying = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Вызываем dayListener для MultiLevelCircularProgress
      dayListener?.call();
      // Уведомляем всех стандартных слушателей (TimerItem и другие)
      notifyListeners();
    });
  }

  void removeAllListeners() {
    dayListener = null;
  }

  /// Воспроизвести звук начала рабочего дня
  Future<void> playStartUpSound() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      await _audioPlayer.play(AssetSource('mp3/good_morning_vietnam.mp3'));
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
    } catch (e) {
      _isPlaying = false;
      debugPrint('Error playing startup sound: $e');
    }
  }

  /// Воспроизвести звук окончания рабочего дня
  Future<void> playTimeUpSound() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      await _audioPlayer.play(AssetSource('mp3/japanese_attention.mp3'));
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });
    } catch (e) {
      _isPlaying = false;
      debugPrint('Error playing time up sound: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
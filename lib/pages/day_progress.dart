import 'dart:math' as math;
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:flutter/material.dart';

class MultiLevelCircularProgress extends StatefulWidget {
  final List<TimerModel> timers;

  const MultiLevelCircularProgress({super.key, required this.timers});

  @override
  State<MultiLevelCircularProgress> createState() => _MultiLevelCircularProgressState();
}

class _MultiLevelCircularProgressState extends State<MultiLevelCircularProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final double _totalSeconds = 28800;
  Duration startWorkTime = Duration(hours: 11);
  double _leftSeconds = 0;
  double _spentSeconds = 0;
  VoidCallback? listener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    GlobalTimer().dayListener = dayListener;
    listener = startTimer;
    GlobalTimer().addListener(listener!);
  }

  void dayListener() {
    if (listener == null || !GlobalTimer().isActiveListener(listener!)) {
      var starWorkDay = DateTime.now().startOfDay!.add(startWorkTime);
      var endWorkDay = starWorkDay.add(Duration(seconds: _totalSeconds.toInt()));
      if (DateTime.now().isAfter(starWorkDay) && DateTime.now().isBefore(endWorkDay)) {
        listener = startTimer;
        GlobalTimer().addListener(listener!);
      }
    }
  }

  void startTimer() {
    var starWorkDay = DateTime.now().startOfDay!.add(startWorkTime);
    if (DateTime.now().isAfter(starWorkDay)) {
      _leftSeconds = DateTime.now().difference(starWorkDay).inSeconds.toDouble();
    }
    _spentSeconds = 0;
    widget.timers.forEach((el) {
      if (el.endDateTime != null) {
        _spentSeconds += el.estimate.inSeconds.toDouble() + (el.durationLeft?.inSeconds ?? 0);
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _spentProgress => _spentSeconds / _totalSeconds;

  double get _leftProgress => _leftSeconds / _totalSeconds;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 240,
          height: 240,
          margin: EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(painter: CustomPainterCircle(progress: 1.0, color: Colors.grey.shade200, strokeWidth: 25, angleOffset: 0)),

              CustomPaint(
                painter: CustomPainterCircle(
                  progress: (_leftProgress * _animation.value).clamp(0, 1),
                  color: Colors.grey.shade400,
                  strokeWidth: 25,
                  angleOffset: 0,
                ),
              ),

              CustomPaint(
                painter: CustomPainterCircle(
                  progress: (_spentProgress * _animation.value).clamp(0.0, 1.0),
                  color: _spentSeconds > _leftSeconds ? Colors.green.shade400 : Colors.red.shade400,
                  strokeWidth: 20,
                  angleOffset: 0,
                ),
              ),

              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Work time',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _leftSeconds <= 0 ? 'start in ${startWorkTime.inSeconds.toHoursMinutes}' : _leftSeconds.toHoursMinutesSeconds,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _spentSeconds > math.min(_leftSeconds, _totalSeconds) ? 'Free time' : 'Lack of time',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      (_spentSeconds - math.min(_leftSeconds, _totalSeconds)).abs().toHoursMinutesSeconds,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _spentSeconds > _leftSeconds ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: 250.ms,
                      child: _leftSeconds == 0
                          ? ElevatedButton(
                              key: ValueKey('1'),
                              onPressed: () {
                                var now = DateTime.now();
                                startWorkTime = Duration(hours: now.hour, minutes: now.minute, seconds: now.second - 1);
                                startTimer();
                                _leftSeconds = 1;
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: Text('Start day'),
                            )
                          : ElevatedButton(
                              key: ValueKey('2'),
                              onPressed: () {
                                GlobalTimer().removeAllListeners();
                                startWorkTime = Duration(hours: 11);
                                _leftSeconds = 0;
                                _spentSeconds = 0;
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: Text('Stop day'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CustomPainterCircle extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double angleOffset;

  CustomPainterCircle({required this.progress, required this.color, required this.strokeWidth, required this.angleOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 102.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi / 180 * angleOffset,
      math.pi / 180 * (360 * progress),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainterCircle oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

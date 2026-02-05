import 'dart:math' as math;
import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/models/work_day.dart';
import 'package:bbt_time_tracker/objectbox.g.dart';
import 'package:bbt_time_tracker/services/export_service.dart';
import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MultiLevelCircularProgress extends StatefulWidget {
  final List<TimerModel> timers;

  const MultiLevelCircularProgress({super.key, required this.timers});

  @override
  State<MultiLevelCircularProgress> createState() => _MultiLevelCircularProgressState();
}

class _MultiLevelCircularProgressState extends State<MultiLevelCircularProgress> with SingleTickerProviderStateMixin {
  late WorkDayModel day;
  late AnimationController _controller;
  late Animation<double> _animation;
  final int _totalSeconds = 28800;
  Duration startWorkTime = Duration(hours: 11);
  int _leftSeconds = 0;
  int _prevWorkSeconds = 0;
  int _spentSeconds = 0;
  bool isRun = false;
  VoidCallback? listener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
    getDay();
    GlobalTimer().dayListener = dayListener;
  }

  void getDay() {
    // objectbox.store.box<WorkDayModel>().removeAll();
    var rawDay = objectbox.store
        .box<WorkDayModel>()
        .query(WorkDayModel_.createToDate.lessOrEqualDate(DateTime.now().startOfDay!))
        .build()
        .find().lastOrNull;
    if (rawDay == null) {
      rawDay = WorkDayModel();
      rawDay.createToDate = DateTime.now().startOfDay!;
      // rawDay.startWorkDateTime = DateTime.now().startOfDay!.add(startWorkTime);
      // rawDay.endWorkDateTime = rawDay.startWorkDateTime!.add(Duration(seconds: _totalSeconds.toInt()));
      objectbox.store.box<WorkDayModel>().put(rawDay);
    }
    if (rawDay.startWorkDateTime != null) {
      if (rawDay.endWorkDateTime != null) {
        _leftSeconds = rawDay.endWorkDateTime!.difference(rawDay.startWorkDateTime!).inSeconds;
      } else {
        _leftSeconds = DateTime.now().difference(rawDay.startWorkDateTime!).inSeconds;
      }
    }
    day = rawDay;
  }

  void startDay({DateTime? startDateTime}) {
    isRun = true;
    day.startWorkDateTime ??= startDateTime ?? DateTime.now();
    _prevWorkSeconds = day.prevWorkTime.inSeconds;
    objectbox.store.box<WorkDayModel>().put(day);
    calcTime();
    listener = onTimerTick;
    GlobalTimer().addListener(listener!);
    setState(() {});
  }

  void stopDay({bool isSoft = false}) {
    GlobalTimer().removeAllListeners();
    if (isSoft) {
      GlobalTimer().addListener(listener!);
      GlobalTimer.playTimeUpSound();
    } else {
      isRun = false;
    }

    day.endWorkDateTime = DateTime.now();
    objectbox.store.box<WorkDayModel>().put(day);

    var newDay = WorkDayModel();
    newDay.createToDate = DateTime.now().startOfDay!;
    widget.timers.forEach((el) {
      if (el.isRunning) {
        newDay.prevWorkTime += el.durationLeft ?? Duration.zero;
      }
    });
    if (_totalSeconds > _leftSeconds) {
      newDay.debtOfTime = Duration(seconds: (_totalSeconds - _leftSeconds).toInt());
    } else {
      newDay.freeTime = Duration(seconds: (_leftSeconds - _totalSeconds).toInt());
    }
    objectbox.store.box<WorkDayModel>().put(newDay);

    setState(() {});
  }

  void dayListener() {
    if (listener == null || !GlobalTimer().isActiveListener(listener!)) {
      var starWorkDay = DateTime.now().startOfDay!.add(startWorkTime);
      var endWorkDay = starWorkDay.add(Duration(seconds: _totalSeconds.toInt()));
      if (DateTime.now().isAfter(starWorkDay) && DateTime.now().isBefore(endWorkDay) && day.startWorkDateTime == null) {
        startDay(startDateTime: starWorkDay);
      }
      if (day.startWorkDateTime != null &&
          day.endWorkDateTime == null &&
          DateTime.now().isAfter(day.startWorkDateTime!.add(Duration(seconds: _totalSeconds.toInt())))) {
        stopDay(isSoft: true);
      }
    }
  }

  void onTimerTick() {
    calcTime();
    if (mounted) setState(() {});
  }

  void calcTime() {
    _leftSeconds += 1;
    _spentSeconds = 0;
    widget.timers.forEach((el) {
      if (el.isComplete && el.startDateTime?.startOfDay! == DateTime.now().startOfDay!) {
        _spentSeconds += el.estimate.inSeconds;
      }
      if (el.isRunning) {
        _spentSeconds += el.durationLeft?.inSeconds ?? 0;
      }
    });
    _spentSeconds = (_spentSeconds - _prevWorkSeconds).abs();
    if (day.debtOfTime.inSeconds > 0) {
      _spentSeconds -= day.debtOfTime.inSeconds;
    }
    if (day.freeTime.inSeconds > 0) {
      _spentSeconds += day.freeTime.inSeconds;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _spentProgress => _spentSeconds / _totalSeconds;

  double get _leftProgress => _leftSeconds / _totalSeconds;

  bool get isOffDay =>
      day.startWorkDateTime != null && day.startWorkDateTime!.add(Duration(seconds: _totalSeconds.toInt())).isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ExportService.openExcel();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Отчет выгружен и готов к отправке')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                        }
                      },
                      child: Text('EXPORT TO EXCEL'),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        launchUrl(Uri.parse('https://boosty.to/crassair/donate'));
                      },
                      child: Text('DONATE'),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
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
                      CustomPaint(
                        painter: CustomPainterCircle(progress: 1.0, color: Colors.grey.shade200, strokeWidth: 25, angleOffset: 0),
                      ),

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
                          color: _spentSeconds > (isOffDay ? _totalSeconds : _leftSeconds) ? Colors.green.shade400 : Colors.red.shade400,
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
                              _spentSeconds > (isOffDay ? _totalSeconds : _leftSeconds) ? 'Free time' : 'Lack of time',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              (_spentSeconds - (isOffDay ? _totalSeconds : _leftSeconds)).abs().toHoursMinutesSeconds,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _spentSeconds > (isOffDay ? _totalSeconds : _leftSeconds)
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: 250.ms,
                              child: !isRun && day.startWorkDateTime == null
                                  ? ElevatedButton(
                                      key: ValueKey('1'),
                                      onPressed: startDay,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      child: Text('Start day'),
                                    )
                                  : !isRun
                                  ? ElevatedButton(
                                      key: ValueKey('3'),
                                      onPressed: startDay,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
                                      child: Text('Resume day'),
                                    )
                                  : ElevatedButton(
                                      key: ValueKey('2'),
                                      onPressed: stopDay,
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      child: Text('Stop day'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/time_tracker_service.dart';
import '../utils/number.dart';
import '../utils/global_timer.dart';
import '../services/export_service.dart';

class MultiLevelCircularProgress extends StatefulWidget {
  final TimeTrackerService service;

  const MultiLevelCircularProgress({
    super.key,
    required this.service,
  });

  @override
  State<MultiLevelCircularProgress> createState() =>
      _MultiLevelCircularProgressState();
}

class _MultiLevelCircularProgressState
    extends State<MultiLevelCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final service = widget.service;
        final workDay = service.currentWorkDay;
        final isRun = workDay?.startWorkDateTime != null &&
            workDay?.endWorkDateTime == null;
        
        // Используем новые поля
        final workSeconds = service.todayWorkSeconds;
        final remainingSeconds = service.todayRemainingSeconds;
        final freeSeconds = service.freeSeconds;
        final debtSeconds = service.debtSeconds;
        final totalSeconds = 8 * 3600; // 8 часов
        
        // Прогресс рабочего дня
        final workProgress = workSeconds / totalSeconds;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: service.timers.isEmpty
                          ? null
                          : () async {
                        try {
                          await ExportService.openExcel(service.timers);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Отчет выгружен и открыт'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.file_download),
                      label: const Text('Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 260,
                  height: 260,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Серый фон
                      CustomPaint(
                        painter: CustomPainterCircle(
                          progress: 1.0,
                          color: Colors.grey.shade800,
                          strokeWidth: 25,
                          angleOffset: 0,
                        ),
                      ),
                      // Прогресс рабочего дня
                      CustomPaint(
                        painter: CustomPainterCircle(
                          progress: (workProgress * _animation.value)
                              .clamp(0, 1),
                          color: Colors.grey.shade600,
                          strokeWidth: 25,
                          angleOffset: 0,
                        ),
                      ),
                      // Внутренний круг с информацией
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.grey.shade900,
                              Colors.grey.shade900.withValues(alpha: 0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Work time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Время работы дня
                            Text(
                              !isRun
                                  ? 'start in 11:00'
                                  : workSeconds.toHoursMinutesSeconds,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRun)
                              Text(
                                'of ${totalSeconds.toHoursMinutesSeconds} (left: ${remainingSeconds.toHoursMinutesSeconds})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 8),
                            // Баланс времени
                            Text(
                              debtSeconds > 0
                                  ? 'Lack of time'
                                  : freeSeconds > 0
                                      ? 'Free time'
                                      : 'On schedule',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              debtSeconds > 0
                                  ? debtSeconds.toHoursMinutesSeconds
                                  : freeSeconds > 0
                                      ? freeSeconds.toHoursMinutesSeconds
                                      : '0h 0m 0s',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: debtSeconds > 0
                                    ? Colors.red.shade400
                                    : freeSeconds > 0
                                        ? Colors.green.shade400
                                        : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                    opacity: animation, child: child);
                              },
                              child: workDay?.startWorkDateTime == null
                                  ? ElevatedButton(
                                key: const ValueKey('start'),
                                onPressed: service.startWorkDay,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Start day',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                                  : workDay?.endWorkDateTime != null
                                  ? ElevatedButton(
                                key: const ValueKey('resume'),
                                onPressed: service.resumeWorkDay,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Resume',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                                  : ElevatedButton(
                                key: const ValueKey('stop'),
                                onPressed: service.endWorkDay,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Stop day',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
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

  CustomPainterCircle({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.angleOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 115.0;

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
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
import 'package:flutter/material.dart';
import '../models/timer.dart';
import '../utils/number.dart';
import 'blinking_card.dart';

class TimerItem extends StatelessWidget {
  final Timer timer;
  final VoidCallback? onStartStop;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const TimerItem({super.key, required this.timer, this.onStartStop, this.onComplete, this.onDelete, this.onEdit});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Duration get _timeLeft => timer.timeLeft;

  Duration get _overTime => timer.overTime;

  bool get _isOver => timer.durationLeftMilliseconds > timer.estimateMilliseconds;

  double get _progress {
    if (timer.estimateMilliseconds == 0) return 0;
    return timer.durationLeftMilliseconds / timer.estimateMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: timer.isRunning
                  ? Colors.green.shade400
                  : timer.isComplete
                  ? Colors.blue.shade400
                  : Colors.grey.shade600,
              width: 5,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timer.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Номер задачи и описание
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${timer.number}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade300,
                            ),
                          ),
                        ),
                        if (timer.description != null && timer.description!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timer.description!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('Est: ${_formatDuration(timer.estimate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        if (timer.durationLeft != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.hourglass_empty, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _isOver ? 'Over: ${_formatDuration(_overTime)}' : 'Left: ${_formatDuration(_timeLeft)}',
                            style: TextStyle(fontSize: 12, color: _isOver ? Colors.red.shade400 : Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                    if (timer.isRunning) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.play_circle, size: 16, color: Colors.green.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Running',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade400, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation<Color>(_isOver ? Colors.red.shade400 : Colors.green.shade400),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${(_progress * 100).toInt()}%', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ),
                    ],
                    if (timer.isComplete && timer.durationLeft != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isOver ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.green.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isOver ? Icons.warning_amber : Icons.check_circle,
                              size: 14,
                              color: _isOver ? Colors.red.shade400 : Colors.green.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isOver ? 'Over by ${_formatDuration(_overTime)}' : 'Free ${_formatDuration(_timeLeft)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _isOver ? Colors.red.shade400 : Colors.green.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actual: ${_formatDuration(timer.durationLeft!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!timer.isComplete)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          timer.isRunning ? Icons.pause : Icons.play_arrow,
                          color: timer.isRunning ? Colors.orange : Colors.green,
                        ),
                        onPressed: onStartStop,
                        tooltip: timer.isRunning ? 'Pause' : 'Start',
                      ),
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.blue.shade400),
                        onPressed: onComplete,
                        tooltip: 'Complete',
                      ),
                    ],
                  )
                else
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: onStartStop, // resume через тот же колбэк
                    tooltip: 'Resume',
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.grey.shade400),
                      onPressed: onEdit,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade400),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

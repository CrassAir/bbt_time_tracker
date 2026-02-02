import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linkable/linkable.dart';

DateFormat dateFormat = DateFormat('dd.MM.yyyy');
DateFormat shortFormat = DateFormat('HH:mm');

class TimerItem extends StatefulWidget {
  const TimerItem({super.key, required this.timerModel});

  final TimerModel timerModel;

  @override
  State<TimerItem> createState() => _TimerItemState();
}

class _TimerItemState extends State<TimerItem> {
  Duration? left;
  Duration? right;
  VoidCallback? listener;

  void startTimer() {
    widget.timerModel.startDateTime = DateTime.now();
    left = Duration(seconds: widget.timerModel.duration.inSeconds);
    listener = changeDur;
    setState(() {});
    GlobalTimer().addListener(listener!);
  }

  void resumeTimer() {
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
      setState(() {});
    } else {
      listener = changeDur;
      setState(() {});
      GlobalTimer().addListener(listener!);
    }
  }

  void stopTimer() {
    if (right != null) {
      if (right!.inSeconds >= 60) {
        widget.timerModel.timeOver = right;
      }
      right = null;
    } else {
      if (left!.inSeconds >= 60) {
        widget.timerModel.timeFree = Duration(seconds: left!.inSeconds);
      }
    }
    widget.timerModel.endDateTime = DateTime.now();
    left = null;
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
    }
    setState(() {});
  }

  void changeDur() {
    if (left!.inSeconds <= 0) {
      right = Duration(seconds: (right?.inSeconds ?? 0) + 1);
    } else {
      left = Duration(seconds: left!.inSeconds - 1);
    }
    setState(() {});
  }

  Widget builder(TimerModel tim) {
    if (left != null) {
      return Column(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: resumeTimer,
            child: listener != null && GlobalTimer().isActiveListener(listener!) ? Text('PAUSE') : Text('RESUME'),
          ),
          ElevatedButton(onPressed: stopTimer, child: Text('STOP')),
          Text(right != null ? right!.inSeconds.toHoursMinutesSeconds : left!.inSeconds.toHoursMinutesSeconds),
        ],
      );
    }
    if (tim.endDateTime == null) {
      return ElevatedButton(onPressed: startTimer, child: Text('START'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Total ${tim.endDateTime!.difference(tim.startDateTime!).inSeconds.toHoursMinutesSeconds}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        Text(
          'Credit ${tim.duration.inSeconds.toHoursMinutesSeconds}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        if (tim.timeFree != null) Text('Free ${tim.timeFree!.inSeconds.toHoursMinutes}'),
        if (tim.timeOver != null) Text('Over ${tim.timeOver!.inSeconds.toHoursMinutes}'),
      ],
    );
  }

  Color colorByState() {
    if ((left != null && left!.inSeconds <= 0) || widget.timerModel.timeOver != null) {
      return Colors.red.shade100;
    }
    if (widget.timerModel.timeFree != null) {
      return Colors.green.shade100;
    }
    if ((listener == null || !GlobalTimer().isActiveListener(listener!)) && left != null) {
      return Colors.yellow.shade300;
    }
    return Colors.blue.shade50;
  }

  @override
  Widget build(BuildContext context) {
    var tim = widget.timerModel;
    return AnimatedContainer(
      duration: 300.ms,
      decoration: BoxDecoration(color: colorByState()),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(tim.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(tim.name),
                    if (tim.url != null) Linkable(text: tim.url!.toString()),
                  ],
                ),
              ),
              AnimatedSwitcher(duration: 250.ms, child: builder(tim)),
            ],
          ),
          if (left != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: (1 - (left!.inSeconds / widget.timerModel.duration.inSeconds)).clamp(0.0, 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

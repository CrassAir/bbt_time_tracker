import 'dart:async';

import 'package:bbt_time_tracker/models/time_tracker.dart';
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
  Timer? timer;

  void startTimer() {
    timer?.cancel();
    widget.timerModel.startDateTime = DateTime.now();
    left = widget.timerModel.duration;
    setState(() {});
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      changeDur();
    });
  }

  void resumeTimer() {
    if (timer?.isActive == true) {
      timer?.cancel();
      setState(() {});
    } else {
      changeDur();
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        changeDur();
      });
    }
  }

  void stopTimer() {
    if (right != null) {
      widget.timerModel.creditDur = right;
      right = null;
    } else {
      if (left!.inSeconds > 300) {
        widget.timerModel.timeFree = Duration(seconds: widget.timerModel.duration.inSeconds - left!.inSeconds);
      }
    }
    left = null;
    timer?.cancel();
    widget.timerModel.endDateTime = DateTime.now();
    setState(() {});
  }

  void changeDur() {
    if (left!.isNegative) {
      right = Duration(seconds: (right?.inSeconds ?? 0) + 1);
    } else {
      left = Duration(seconds: left!.inSeconds - 1);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var tim = widget.timerModel;
    Widget builder() {
      if (left != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(right != null ? right!.inSeconds.toHoursMinutesSeconds : left!.inSeconds.toHoursMinutesSeconds),
            SizedBox(width: 8),
            ElevatedButton(onPressed: resumeTimer, child: timer?.isActive == true ? Text('PAUSE') : Text('RESUME')),
            ElevatedButton(onPressed: stopTimer, child: Text('STOP')),
          ],
        );
      }
      if (tim.endDateTime == null) {
        return ElevatedButton(onPressed: startTimer, child: Text('START'));
      }
      return Column(
        children: [
          Text('Total ${tim.endDateTime!.difference(tim.startDateTime!).inSeconds.toHoursMinutesSeconds}'),
          if (tim.timeFree != null) Text('Free ${tim.timeFree!.inSeconds.toHoursMinutesSeconds}'),
          if (tim.creditDur != null) Text('Credit ${tim.creditDur!.inSeconds.toHoursMinutesSeconds}'),
        ],
      );
    }

    return AnimatedContainer(
      duration: 300.ms,
      decoration: BoxDecoration(
        color: left?.isNegative == true || tim.creditDur != null
            ? Colors.red.shade100
            : tim.endDateTime != null
            ? Colors.green.shade100
            : Colors.blue.shade50,
      ),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(dateFormat.format(tim.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(tim.name),
                    if (tim.url != null) Linkable(text: tim.url!.toString()),
                  ],
                ),
              ),
              AnimatedSwitcher(duration: 250.ms, child: builder()),
            ],
          ),
          if (left != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: (1 - (left!.inSeconds / widget.timerModel.duration.inSeconds)).clamp(0.0, 1.0)),
            ),
        ],
      ),
    );
  }
}

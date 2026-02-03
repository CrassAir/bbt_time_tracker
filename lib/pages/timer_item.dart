import 'package:audioplayers/audioplayers.dart';
import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/utils/blinking_card.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
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
  ValueNotifier<Duration> left = ValueNotifier(Duration.zero);
  ValueNotifier<Duration> estimate = ValueNotifier(Duration.zero);
  VoidCallback? listener;
  bool isActive = false;
  bool isAlarm = false;

  @override
  void initState() {
    super.initState();
    estimate.value = widget.timerModel.estimate;
    left.value = widget.timerModel.durationLeft ?? Duration.zero;
    GlobalTimer().addStopListener(stopListener);
  }

  @override
  void dispose() {
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
    }
    GlobalTimer().removeStopListener(stopListener);
    super.dispose();
  }

  void startTimer() {
    widget.timerModel.startDateTime = DateTime.now();
    left.value = Duration(seconds: 1);
    listener = changeDur;
    isActive = true;
    setState(() {});
    GlobalTimer().addListener(listener!);
  }

  void resumeTimer() {
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
      widget.timerModel.durationLeft = left.value;
      isActive = false;
      objectbox.store.box<TimerModel>().put(widget.timerModel);
      setState(() {});
    } else {
      listener = changeDur;
      if (widget.timerModel.endDateTime != null) {
        widget.timerModel.endDateTime = null;
        objectbox.store.box<TimerModel>().put(widget.timerModel);
        left.value = widget.timerModel.durationLeft ?? Duration(seconds: 1);
      }
      isActive = true;
      setState(() {});
      GlobalTimer().addListener(listener!);
    }
  }

  void stopTimer() {
    widget.timerModel.endDateTime = DateTime.now();
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
    }
    widget.timerModel.durationLeft = left.value;
    objectbox.store.box<TimerModel>().put(widget.timerModel);
    isActive = false;
    setState(() {});
  }

  void changeDur() {
    left.value = Duration(seconds: left.value.inSeconds + 1);
    widget.timerModel.durationLeft = left.value;
    var time = estimate.value.inSeconds - left.value.inSeconds;
    if (time < 55 && time > 0 && !isAlarm) {
      GlobalTimer.playTimeUpSound();
      isAlarm = true;
      Future.delayed(Duration(seconds: 60)).then((_) {
        if (mounted) {
          setState(() {
            isAlarm = false;
          });
        }
      });
    }
    if (left.value.inSeconds % 60 == 0) {
      objectbox.store.box<TimerModel>().put(widget.timerModel);
    }
    setState(() {});
  }

  void stopListener() {
    isActive = false;
    setState(() {});
  }

  Widget builder(TimerModel tim) {
    if (tim.endDateTime == null) {
      if (left.value.inSeconds == 0) {
        return ElevatedButton(onPressed: startTimer, child: Text('START'));
      }
      var time = tim.estimate.inSeconds - left.value.inSeconds;
      if (time < 0) {
        time = left.value.inSeconds - tim.estimate.inSeconds;
      }
      return Column(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: resumeTimer,
            child: listener != null && GlobalTimer().isActiveListener(listener!) ? Text('PAUSE') : Text('RESUME'),
          ),
          ElevatedButton(onPressed: stopTimer, child: Text('STOP')),
          Text(time.toHoursMinutesSeconds, textAlign: TextAlign.right),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          'Total ${tim.durationLeft!.inSeconds.toHoursMinutesSeconds}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black),
        ),
        ElevatedButton(onPressed: resumeTimer, child: Text('RESUME')),
      ],
    );
  }

  Color colorByState() {
    var isOver = widget.timerModel.estimate.inSeconds - left.value.inSeconds <= 0;
    if (widget.timerModel.endDateTime == null) {
      if (listener == null || !GlobalTimer().isActiveListener(listener!)) {
        return Colors.yellow.shade300;
      }
    }
    if (isOver) {
      return Colors.red.shade100;
    }
    if (!isOver && widget.timerModel.endDateTime != null) {
      return Colors.green.shade100;
    }
    return Colors.blue.shade50;
  }

  void showEditDialog() {
    GlobalKey formKey = GlobalKey<FormBuilderState>();
    var tim = widget.timerModel;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FormBuilder(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tim.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                ValueListenableBuilder(
                  valueListenable: estimate,
                  builder: (BuildContext context, value, Widget? child) {
                    return Text('Estimate time ${estimate.value.inSeconds.toHoursMinutesSeconds}');
                  },
                ),
                SizedBox(height: 8),
                Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        var sub = widget.timerModel.estimate.inSeconds - 600;
                        if (sub > 0) {
                          widget.timerModel.estimate = Duration(seconds: sub);
                          estimate.value = widget.timerModel.estimate;
                          objectbox.store.box<TimerModel>().put(widget.timerModel);
                          setState(() {});
                        }
                      },
                      child: Text('-10 min'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.timerModel.estimate = Duration(seconds: widget.timerModel.estimate.inSeconds + 600);
                        estimate.value = widget.timerModel.estimate;
                        objectbox.store.box<TimerModel>().put(widget.timerModel);
                        isAlarm = false;
                        setState(() {});
                      },
                      child: Text('+10 min'),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                ValueListenableBuilder(
                  valueListenable: left,
                  builder: (BuildContext context, value, Widget? child) {
                    var time = tim.estimate.inSeconds - left.value.inSeconds;
                    if (time < 0) {
                      time = left.value.inSeconds - tim.estimate.inSeconds;
                    }
                    return Text('Left time ${time.toHoursMinutesSeconds}');
                  },
                ),
                SizedBox(height: 8),
                Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        var sub = left.value.inSeconds - 600;
                        left.value = Duration(seconds: sub);
                        isAlarm = false;
                        setState(() {});
                      },
                      child: Text('-10 min'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        left.value = Duration(seconds: left.value.inSeconds + 600);
                        setState(() {});
                      },
                      child: Text('+10 min'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var tim = widget.timerModel;
    var time = widget.timerModel.estimate.inSeconds - left.value.inSeconds;
    var isOver = time <= 0;
    if (isOver) {
      time = left.value.inSeconds - tim.estimate.inSeconds;
    }
    return InkWell(
      onTap: showEditDialog,
      child: Container(
        decoration: BoxDecoration(
          border: BoxBorder.fromLTRB(bottom: BorderSide(color: Colors.black, width: 1)),
        ),
        child: BlinkingCard(
          defaultColor: colorByState(),
          isBlinking: isAlarm,
          child: Padding(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Estimate ${tim.estimate.inSeconds.toHoursMinutes}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            Text(
                              isOver ? 'Over ${time.toHoursMinutes}' : 'Free ${time.toHoursMinutes}',
                              style: TextStyle(fontSize: 18, color: isOver ? Colors.red : Colors.green),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 110,
                          child: AnimatedSwitcher(duration: 250.ms, child: builder(tim)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(value: (left.value.inSeconds / widget.timerModel.estimate.inSeconds).clamp(0.0, 1.0)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

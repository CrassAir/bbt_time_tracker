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
      if (widget.timerModel.isComplete) {
        widget.timerModel.isComplete = false;
        objectbox.store.box<TimerModel>().put(widget.timerModel);
        left.value = widget.timerModel.durationLeft ?? Duration(seconds: 1);
      }
      isActive = true;
      setState(() {});
      GlobalTimer().addListener(listener!);
    }
  }

  void stopTimer() {
    widget.timerModel.isComplete = true;
    if (listener != null && GlobalTimer().isActiveListener(listener!)) {
      GlobalTimer().removeListener(listener!);
      listener = null;
    }
    widget.timerModel.durationLeft = left.value;
    widget.timerModel.endDateTime = DateTime.now();
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
    widget.timerModel.durationLeft = left.value;
    objectbox.store.box<TimerModel>().put(widget.timerModel);
    setState(() {});
  }

  Widget builder(TimerModel tim) {
    if (!tim.isComplete) {
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
    if (!widget.timerModel.isComplete && widget.timerModel.startDateTime != null) {
      if (listener == null || !GlobalTimer().isActiveListener(listener!)) {
        return Colors.yellow.shade300;
      }
    }
    if (widget.timerModel.isComplete) {
      return Colors.green.shade100;
    }
    return Colors.blue.shade50;
  }

  void showEditDialog() async {
    var tim = widget.timerModel;
    TextEditingController controller = TextEditingController(text: tim.name);
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  onChanged: (value) {
                    tim.name = value;
                  },
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
                          setState(() {});
                        }
                      },
                      child: Text('-10 min'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.timerModel.estimate = Duration(seconds: widget.timerModel.estimate.inSeconds + 600);
                        estimate.value = widget.timerModel.estimate;
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
    objectbox.store.box<TimerModel>().put(tim);
    setState(() {});
  }

  void onSetBranch() async {
    var tim = widget.timerModel;
    TextEditingController controller = TextEditingController(text: tim.branchName);
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text('Branch name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextField(
                  controller: controller,
                  onSubmitted: (_) {
                    Navigator.maybePop(context);
                  },
                  onChanged: (value) {
                    tim.branchName = value;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    objectbox.store.box<TimerModel>().put(tim);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var tim = widget.timerModel;
    var time = widget.timerModel.estimate.inSeconds - left.value.inSeconds;
    var isOver = time <= 0;
    if (isOver) {
      time = left.value.inSeconds - tim.estimate.inSeconds;
    }
    return Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 24,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Edit task',
                              verticalOffset: 10,
                              child: InkWell(
                                onTap: showEditDialog,
                                child: Row(
                                  spacing: 4,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(dateFormat.format(tim.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    Icon(Icons.edit, size: 10, color: Colors.grey.shade700),
                                  ],
                                ),
                              ),
                            ),
                            tim.branchName == null || tim.branchName!.isEmpty
                                ? InkWell(
                                    onTap: onSetBranch,
                                    child: Text(
                                      'Enter branch name',
                                      style: TextStyle(fontSize: 12, color: Colors.blue, decorationColor: Colors.blue),
                                    ),
                                  )
                                : Tooltip(
                                    message: 'Edit branch name',
                                    verticalOffset: 10,
                                    child: Row(
                                      spacing: 4,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SelectableText(tim.branchName!, style: TextStyle(fontSize: 12)),
                                        InkWell(
                                          onTap: onSetBranch,
                                          child: Icon(Icons.edit, size: 10, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                        SelectableText(tim.name),
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
                        spacing: 8,
                        children: [
                          Text(
                            'Estimate ${tim.estimate.inSeconds.toHoursMinutes}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          if (tim.isComplete)
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
    );
  }
}

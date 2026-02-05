import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/models/work_day.dart';
import 'package:bbt_time_tracker/objectbox.g.dart';
import 'package:bbt_time_tracker/pages/day_progress.dart';
import 'package:bbt_time_tracker/pages/timer_item.dart';
import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class TimerList extends StatefulWidget {
  const TimerList({super.key});

  @override
  State<TimerList> createState() => _TimerListState();
}

class _TimerListState extends State<TimerList> with AutomaticKeepAliveClientMixin {
  final GlobalKey<FormBuilderState> formKey = GlobalKey<FormBuilderState>();
  List<TimerModel> timers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    timers =
        objectbox.store
            .box<TimerModel>()
            .query(TimerModel_.startDateTime.greaterOrEqualDate(DateTime.now().startOfDay!).or(TimerModel_.isComplete.equals(false)))
            .build()
            .find()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void onRemove(index) {
    var rawDay = objectbox.store
        .box<WorkDayModel>()
        .query(WorkDayModel_.createToDate.equalsDate(DateTime.now().startOfDay!))
        .build()
        .findFirst();
    if (rawDay != null) {
      if (timers[index].isRunning && rawDay.endWorkDateTime != null) {
        rawDay.prevWorkTime -= timers[index].durationLeft ?? Duration.zero;
        objectbox.store.box<WorkDayModel>().put(rawDay);
      }
    }
    objectbox.store.box<TimerModel>().remove(timers[index].id);
    timers.removeAt(index);
    setState(() {});
  }

  void onSubmit() {
    if (formKey.currentState!.saveAndValidate()) {
      var data = {...formKey.currentState!.value};
      formKey.currentState!.reset();
      if (timers.any((el) => el.name == data['name'])) {
        return;
      }
      var hours = data['hours'] == 0 && data['minutes'] == 0 ? 1 : data['hours'];
      var timer = TimerModel(name: data['name']);
      timer.estimate = Duration(hours: hours ?? 0, minutes: data['minutes'] ?? 0);
      objectbox.store.box<TimerModel>().put(timer);
      timers.insert(0, timer);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (wantKeepAlive) {
      super.build(context);
    }
    return FormBuilder(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MultiLevelCircularProgress(timers: timers),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FormBuilderTextField(
                  name: 'name',
                  minLines: 1,
                  maxLines: 6,
                  decoration: InputDecoration(label: Text('Task name'), border: OutlineInputBorder()),
                  validator: FormBuilderValidators.required(),
                ),
                Row(
                  spacing: 4,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 70,
                      child: FormBuilderTextField(
                        name: 'hours',
                        valueTransformer: (value) => int.tryParse(value ?? '0'),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(label: Text('HH'), border: OutlineInputBorder()),
                        validator: FormBuilderValidators.numeric(checkNullOrEmpty: false),
                      ),
                    ),
                    Text(':', style: TextStyle(fontSize: 40)),
                    SizedBox(
                      width: 70,
                      child: FormBuilderTextField(
                        name: 'minutes',
                        decoration: InputDecoration(label: Text('MM'), border: OutlineInputBorder()),
                        valueTransformer: (value) => int.tryParse(value ?? '0'),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: FormBuilderValidators.numeric(checkNullOrEmpty: false),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(onPressed: onSubmit, child: Text('ADD TASK')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: timers.mapIndexed((i, el) {
                  var locTimer = timers[i];
                  return SwipeActionCell(
                    key: ValueKey(locTimer.name),
                    trailingActions: <SwipeAction>[
                      SwipeAction(
                        icon: Icon(Icons.delete, color: Colors.white),
                        onTap: (CompletionHandler handler) async {
                          onRemove(i);
                        },
                        color: Colors.red,
                      ),
                    ],
                    child: TimerItem(timerModel: locTimer),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

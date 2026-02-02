import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/pages/day_progress.dart';
import 'package:bbt_time_tracker/pages/timer_item.dart';
import 'package:bbt_time_tracker/utils/global_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<FormBuilderState> formKey = GlobalKey<FormBuilderState>();
  List<TimerModel> timers = [];

  void onRemove(index) {
    timers.removeAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TIME TRACKER'), centerTitle: true),
      body: FormBuilder(
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
                        width: 60,
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
                        width: 60,
                        child: FormBuilderTextField(
                          name: 'minutes',
                          decoration: InputDecoration(label: Text('MM'), border: OutlineInputBorder()),
                          valueTransformer: (value) => int.tryParse(value ?? '0'),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: FormBuilderValidators.numeric(checkNullOrEmpty: false),
                        ),
                      ),
                      IconButton(onPressed: onSubmit, icon: Icon(Icons.add), iconSize: 35),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Divider(thickness: 1, color: Colors.blue),
            Flexible(
              child: ListView.separated(
                itemCount: timers.length,
                shrinkWrap: true,
                reverse: true,
                separatorBuilder: (context, index) =>
                    Container(height: 1, width: double.maxFinite, color: Colors.black),
                itemBuilder: (context, index) {
                  var locTimer = timers[index];
                  return SwipeActionCell(
                    key: ValueKey(locTimer.name),
                    trailingActions: <SwipeAction>[
                      SwipeAction(
                        icon: Icon(Icons.delete, color: Colors.white),
                        onTap: (CompletionHandler handler) async {
                          onRemove(index);
                        },
                        color: Colors.red,
                      ),
                    ],
                    child: TimerItem(timerModel: locTimer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onSubmit() {
    if (formKey.currentState!.saveAndValidate()) {
      var data = {...formKey.currentState!.value};
      formKey.currentState!.reset();
      if (timers.any((el) => el.name == data['name'])) {
        return;
      }
      var hours = data['hours'] == 0 && data['minutes'] == 0 ? 1 : data['hours'];
      var timer = TimerModel(
        name: data['name'],
        duration: Duration(hours: hours ?? 0, minutes: data['minutes'] ?? 0),
      );
      setState(() {
        timers.add(timer);
      });
    }
  }
}

// TODO: Оповещения на вышедшее общее время, на время карточки
// TODO: Выгрузка данных в эксель по дням
// TODO: Сохранение данных в таблицу, поддержать кнопку конец дня, задачи на паузу до следующего дня по отжатии
// TODO: Сделать сервер, добавить тг бота
// TODO: Добавить настройки(старт рабочего дня, робочее время)
// TODO: Добавить размеры окна макс, мин, дефолт
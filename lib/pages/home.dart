import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/models/work_day.dart';
import 'package:bbt_time_tracker/objectbox.g.dart';
import 'package:bbt_time_tracker/pages/day_progress.dart';
import 'package:bbt_time_tracker/pages/history.dart';
import 'package:bbt_time_tracker/pages/timer_item.dart';
import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:linkable/linkable.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PageController pageController = PageController(initialPage: 0);
  int curPage = 0;
  final GlobalKey<FormBuilderState> formKey = GlobalKey<FormBuilderState>();
  List<TimerModel> timers = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text('TIME TRACKER'),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://github.com/CrassAir'), mode: LaunchMode.externalApplication),
              child: Text(
                'developed by CrassAir',
                style: TextStyle(fontSize: 10, color: Colors.blue, decorationColor: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: curPage,
        onTap: (value) {
          pageController.animateToPage(value, duration: Duration(milliseconds: 250), curve: Curves.easeInOut);
          curPage = value;
          setState(() {});
        },
        items: [
          BottomNavigationBarItem(
            icon: MouseRegion(
              onEnter: (_) {},
              onExit: (_) {},
              child: Icon(Icons.home),
            ),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
        ],
      ),
      body: PageView(
        controller: pageController,
        children: [
          FormBuilder(
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
                Divider(thickness: 1, color: Colors.blue),
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
          ),
          HistoryPage(),
        ],
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
      var timer = TimerModel(name: data['name']);
      timer.estimate = Duration(hours: hours ?? 0, minutes: data['minutes'] ?? 0);
      objectbox.store.box<TimerModel>().put(timer);
      timers.insert(0, timer);
      setState(() {});
    }
  }
}

// TODO: Оповещения на вышедшее общее время
// TODO: Выгрузка данных в эксель по дням
// TODO: Сделать сервер, добавить тг бота
// TODO: Добавить настройки(старт рабочего дня, робочее время)
// TODO: Добавить размеры окна макс, мин, дефолт

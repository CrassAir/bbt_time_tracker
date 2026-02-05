import 'package:bbt_time_tracker/main.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/objectbox.g.dart';
import 'package:bbt_time_tracker/pages/timer_item.dart';
import 'package:bbt_time_tracker/services/export_service.dart';
import 'package:bbt_time_tracker/utils/date_ext.dart';
import 'package:bbt_time_tracker/utils/number.dart';
import 'package:flutter/material.dart';
import 'package:linkable/linkable.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TimerModel> timers = [];

  @override
  void initState() {
    super.initState();
    timers = objectbox.store.box<TimerModel>().query(TimerModel_.isComplete.equals(true)).build().find()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
        centerTitle: true,
        forceMaterialTransparency: true,
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await ExportService.openExcel(timers);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Отчет выгружен и готов к отправке')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            child: Text('EXPORT TO EXCEL'),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: timers.mapIndexed((i, el) {
            var locTimer = timers[i];
            return HistoryItem(tim: locTimer);
          }).toList(),
        ),
      ),
    );
  }
}

class HistoryItem extends StatelessWidget {
  const HistoryItem({super.key, required this.tim});

  final TimerModel tim;

  Color colorByState() {
    if (tim.startDateTime == null) {
      return Colors.yellow;
    }
    if (tim.isComplete) {
      return Colors.green;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    var left = tim.durationLeft?.inSeconds ?? 0;
    var time = tim.estimate.inSeconds - left;
    var isOver = time <= 0;
    if (isOver) {
      time = left - tim.estimate.inSeconds;
    }
    return Container(
      margin: EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: BoxBorder.fromLTRB(
          right: BorderSide(color: colorByState(), width: 4),
          left: BorderSide(color: colorByState(), width: 4),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: Offset(0, 4), blurRadius: 10)],
      ),
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
                        mainAxisSize: MainAxisSize.min,
                        spacing: 24,
                        children: [
                          Text(dateFormat.format(tim.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          if (tim.branchName != null && tim.branchName!.isNotEmpty)
                            SelectableText(tim.branchName!, style: TextStyle(fontSize: 12)),
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

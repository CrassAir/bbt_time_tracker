import 'package:bbt_time_tracker/models/time_tracker.dart';
import 'package:bbt_time_tracker/pages/timer_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:linkable/linkable.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<FormBuilderState> formKey = GlobalKey<FormBuilderState>();
  List<TimerModel> timers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TIME TRACKER'), centerTitle: true),
      body: FormBuilder(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormBuilderTextField(
                    name: 'name',
                    decoration: InputDecoration(hintText: 'Task name'),
                    validator: FormBuilderValidators.required(),
                  ),
                  Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 50,
                        child: FormBuilderTextField(
                          name: 'hours',
                          valueTransformer: (value) => int.tryParse(value ?? '0'),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(hintText: 'HH'),
                          validator: FormBuilderValidators.numeric(checkNullOrEmpty: false),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: FormBuilderTextField(
                          name: 'minutes',
                          decoration: InputDecoration(hintText: 'MM'),
                          valueTransformer: (value) => int.tryParse(value ?? '0'),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: FormBuilderValidators.numeric(checkNullOrEmpty: false),
                        ),
                      ),
                      ElevatedButton(onPressed: onSubmit, child: Text('ADD')),
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
                separatorBuilder:(context, index) => Container(height: 1,width: double.maxFinite, color: Colors.black),
                itemBuilder: (context, index) {
                  var locTimer = timers[index];
                  return TimerItem(timerModel: locTimer);
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
      var timer = TimerModel(
        name: data['name'],
        duration: Duration(hours: data['hours'] == null && data['minutes'] == null ? 1 : data['hours'], minutes: data['minutes'] ?? 0),
      );
      setState(() {
        timers.add(timer);
      });
    }
  }
}

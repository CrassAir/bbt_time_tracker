import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../services/time_tracker_service.dart';
import '../models/timer.dart';
import '../widgets/timer_item.dart';
import '../widgets/blinking_card.dart';
import '../utils/number.dart';

class TimeTrackerScreen extends StatefulWidget {
  final TimeTrackerService service;

  const TimeTrackerScreen({
    super.key,
    required this.service,
  });

  @override
  State<TimeTrackerScreen> createState() => _TimeTrackerScreenState();
}

class _TimeTrackerScreenState extends State<TimeTrackerScreen> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '15');
  final _projectController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  void _addTimer() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final data = _formKey.currentState!.value;
      final hours = data['hours'] as int? ?? 0;
      final minutes = data['minutes'] as int? ?? 0;

      if (hours == 0 && minutes == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите время задачи')),
        );
        return;
      }

      if (widget.service.timers.any((t) => t.name == data['name'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задача с таким именем уже существует')),
        );
        return;
      }

      await widget.service.addTimer(
        name: data['name'] as String,
        estimate: Duration(hours: hours, minutes: minutes),
        project: data['project'] as String?,
      );

      _nameController.clear();
      _hoursController.text = '0';
      _minutesController.text = '15';
      _projectController.clear();
      _formKey.currentState?.reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Задача добавлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Time Tracker',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Add timer form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800, width: 0.5),
                ),
                child: FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FormBuilderTextField(
                        name: 'name',
                        controller: _nameController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Task name',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          hintText: 'e.g., Fix bug #123',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400),
                          ),
                        ),
                        validator: FormBuilderValidators.required(),
                      ),
                      const SizedBox(height: 12),
                      FormBuilderTextField(
                        name: 'project',
                        controller: _projectController,
                        decoration: InputDecoration(
                          labelText: 'Project (optional)',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          hintText: 'e.g., My Project',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 80,
                            child: FormBuilderTextField(
                              name: 'hours',
                              controller: _hoursController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'HH',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.blue.shade400),
                                ),
                              ),
                              valueTransformer: (value) => int.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ':',
                              style: TextStyle(fontSize: 32, color: Colors.white),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: FormBuilderTextField(
                              name: 'minutes',
                              controller: _minutesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'MM',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.blue.shade400),
                                ),
                              ),
                              valueTransformer: (value) => int.tryParse(value ?? '0') ?? 0,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _addTimer,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Timers list header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Timers (${widget.service.timers.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  if (widget.service.timers.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        // Clear all completed
                        widget.service.timers
                            .where((t) => t.isComplete)
                            .toList()
                            .forEach(widget.service.deleteTimer);
                      },
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear completed'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Timers list
              Expanded(
                child: widget.service.timers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 64,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No timers yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a task to start tracking time',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.service.timers.length,
                        itemBuilder: (context, index) {
                          final timer = widget.service.timers[index];
                          final isRunning = timer.isRunning;

                          return BlinkingCard(
                            isActive: isRunning,
                            activeColor: Colors.green,
                            child: TimerItem(
                              timer: timer,
                              onStartStop: () {
                                if (isRunning) {
                                  widget.service.stopTimer(timer);
                                } else {
                                  widget.service.startTimer(timer);
                                }
                              },
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.grey.shade900,
                                    title: const Text('Delete timer?'),
                                    content: Text(
                                      'Are you sure you want to delete "${timer.name}"?',
                                      style: TextStyle(color: Colors.grey.shade300),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey.shade400),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          widget.service.deleteTimer(timer);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade400,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

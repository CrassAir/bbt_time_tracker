import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../services/time_tracker_service.dart';
import '../services/project_service.dart';
import '../services/objectbox_service.dart';
import '../services/qwen_code_service.dart';
import '../utils/duration_formatter.dart';
import '../widgets/day_progress.dart';
import '../widgets/timer_item.dart';
import '../widgets/blinking_card.dart';
import '../models/work_day.dart';
import '../models/timer.dart';

enum DashboardQuickAction { history, projects }

class DashboardScreen extends StatefulWidget {
  final TimeTrackerService timeTrackerService;
  final ProjectService? projectService;
  final QwenCodeService? qwenService;
  final VoidCallback? onStartBot;
  final VoidCallback? onStopBot;
  final bool botRunning;
  final ValueChanged<DashboardQuickAction>? onQuickAction;

  const DashboardScreen({
    super.key,
    required this.timeTrackerService,
    this.projectService,
    this.qwenService,
    this.onStartBot,
    this.onStopBot,
    this.botRunning = false,
    this.onQuickAction,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '15');
  final _projectController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите время задачи')));
        return;
      }

      if (widget.timeTrackerService.timers.any((t) => t.name == data['name'])) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задача с таким именем уже существует')));
        return;
      }

      await widget.timeTrackerService.addTimer(
        name: data['name'] as String,
        estimate: Duration(hours: hours, minutes: minutes),
        project: data['project'] as String?,
        description: data['description'] as String?,
      );

      _nameController.clear();
      _descriptionController.clear();
      _hoursController.text = '0';
      _minutesController.text = '15';
      _projectController.clear();
      _formKey.currentState?.reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задача добавлена'), backgroundColor: Colors.green));
      }
    }
  }

  void _showEditTimerDialog(Timer timer) {
    final nameController = TextEditingController(text: timer.name);
    final descriptionController = TextEditingController(text: timer.description ?? '');
    final hoursController = TextEditingController(text: timer.estimate.inHours.toString());
    final minutesController = TextEditingController(text: (timer.estimate.inMinutes % 60).toString());
    final projectController = TextEditingController(text: timer.project ?? '');
    final formKey = GlobalKey<FormBuilderState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Edit timer'),
        content: SizedBox(
          width: 400,
          child: FormBuilder(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '#${timer.number}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade300),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'name',
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Task name',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue.shade400),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'description',
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'project',
                  controller: projectController,
                  decoration: InputDecoration(
                    labelText: 'Project (optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: FormBuilderTextField(
                        name: 'hours',
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'HH',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':', style: TextStyle(fontSize: 24)),
                    ),
                    SizedBox(
                      width: 80,
                      child: FormBuilderTextField(
                        name: 'minutes',
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'MM',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(hoursController.text) ?? 0;
              final minutes = int.tryParse(minutesController.text) ?? 0;
              widget.timeTrackerService.updateTimer(
                timer,
                name: nameController.text,
                estimate: Duration(hours: hours, minutes: minutes),
                project: projectController.text.isEmpty ? null : projectController.text,
                description: descriptionController.text.isEmpty ? null : descriptionController.text,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade400, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.timeTrackerService, widget.projectService]),
      builder: (context, _) {
        final activeProject = widget.projectService?.activeProject;
        final todayDuration = Duration(seconds: widget.timeTrackerService.todayLeftSeconds);
        final activeTimers = widget.timeTrackerService.timers.where((t) => t.isRunning).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 24),
                // Model switcher - с кнопками управления Ollama и моделью
                if (widget.qwenService != null)
                  ListenableBuilder(
                    listenable: widget.qwenService!.configService,
                    builder: (context, _) {
                      final configService = widget.qwenService!.configService;
                      final isLocal = configService.isLocalModel;
                      final ollamaAvailable = configService.ollamaAvailable;
                      final ollamaRunning = configService.ollamaRunning;
                      final ollamaModelReady = configService.ollamaModelReady;
                      final isSwitching = configService.isSwitching;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLocal ? Colors.orange.shade900.withValues(alpha: 0.2) : Colors.blue.shade900.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isLocal ? Colors.orange.shade700 : Colors.blue.shade700, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Заголовок и статус
                            Row(
                              children: [
                                // Индикатор статуса
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ollamaAvailable
                                        ? (ollamaRunning ? (ollamaModelReady ? Colors.green : Colors.orange) : Colors.red.shade400)
                                        : Colors.grey.shade600,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (ollamaAvailable
                                                    ? (ollamaRunning ? (ollamaModelReady ? Colors.green : Colors.orange) : Colors.red)
                                                    : Colors.grey)
                                                .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isLocal ? '🖥 Локальная модель' : '☁️ Облачная модель',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isLocal ? Colors.orange : Colors.blue.shade300,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        !ollamaAvailable
                                            ? '⚠️ Ollama не найдена'
                                            : !ollamaRunning
                                            ? 'Ollama: остановлена'
                                            : !ollamaModelReady
                                            ? '🔄 Проверка модели...'
                                            : isLocal
                                            ? '✅ Активна'
                                            : 'Готова к работе',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: !ollamaAvailable
                                              ? Colors.grey.shade500
                                              : !ollamaRunning
                                              ? Colors.orange
                                              : !ollamaModelReady
                                              ? Colors.orange
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Кнопка проверки Ollama
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  tooltip: 'Проверить Ollama',
                                  onPressed: () async {
                                    await widget.qwenService!.configService.checkOllamaStatus();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            widget.qwenService!.configService.ollamaAvailable ? '✅ Ollama найдена' : '❌ Ollama не найдена',
                                          ),
                                          backgroundColor: widget.qwenService!.configService.ollamaAvailable ? Colors.green : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Кнопки управления Ollama (если установлена)
                            if (ollamaAvailable) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: ollamaRunning && !isSwitching ? () => widget.qwenService?.stopOllama() : null,
                                      icon: const Icon(Icons.stop, size: 16),
                                      label: const Text('Остановить Ollama', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade400,
                                        side: BorderSide(color: Colors.red.shade700),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Кнопка остановки модели (если модель запущена)
                              if (ollamaRunning && ollamaModelReady) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: !isSwitching ? () => widget.qwenService?.stopModel() : null,
                                        icon: const Icon(Icons.memory, size: 16),
                                        label: const Text('Остановить модель', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade400,
                                          side: BorderSide(color: Colors.orange.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                            // Переключатель моделей
                            Row(
                              children: [
                                Expanded(
                                  child: _ModelSwitchButton(
                                    label: '☁️ Облачная',
                                    isActive: !isLocal,
                                    isEnabled: !isSwitching,
                                    onTap: isSwitching ? null : () async {
                                      final models = await widget.qwenService!.getAvailableModels();
                                      final cloudModel = models.firstWhere(
                                        (m) => !m['id']!.contains('qwen2.5') && 
                                               !m['id']!.contains('ollama') && 
                                               !m['id']!.contains('localhost'),
                                        orElse: () => models.first,
                                      );
                                      await widget.qwenService!.switchModel(cloudModel['id']!);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ModelSwitchButton(
                                    label: '🖥 Локальная',
                                    isActive: isLocal,
                                    isEnabled: ollamaRunning && !isSwitching,
                                    onTap: isSwitching || !ollamaRunning
                                        ? null
                                        : () async {
                                            try {
                                              // Пытаемся переключиться
                                              final models = await widget.qwenService!.getAvailableModels();
                                              final localModel = models.firstWhere(
                                                (m) => m['id']!.contains('qwen2.5') ||
                                                       m['id']!.contains('ollama') ||
                                                       m['id']!.contains('localhost'),
                                                orElse: () => models.first,
                                              );
                                              await widget.qwenService!.switchModel(localModel['id']!);
                                              // Проверяем и запускаем модель по имени
                                              final checkResult = await widget.qwenService!.configService.checkAndStartModelByName(localModel['id']!);
                                              if (!checkResult && mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '⚠️ Модель не готова: ${widget.qwenService!.configService.ollamaModelError}',
                                                    ),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              } else if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('✅ Локальная модель запущена и готова'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(SnackBar(content: Text('❌ Ошибка: $e'), backgroundColor: Colors.red));
                                              }
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                            // Индикатор переключения
                            if (isSwitching) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                backgroundColor: Colors.grey.shade800,
                                valueColor: AlwaysStoppedAnimation<Color>(isLocal ? Colors.orange : Colors.blue),
                              ),
                            ],
                            // Подсказка
                            if (!ollamaAvailable) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Установите Ollama: https://ollama.ai',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ] else if (!ollamaRunning) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Запустите Ollama для использования локальной модели',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                              ),
                            ] else if (!ollamaModelReady) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Проверка модели через ollama run...',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                // Bot control buttons
                Row(
                  children: [
                    _BotControlButton(
                      icon: Icons.play_arrow,
                      label: widget.botRunning ? 'Бот запущен' : 'Запустить бота',
                      color: widget.botRunning ? Colors.green : Colors.blue,
                      onTap: widget.botRunning ? widget.onStopBot : widget.onStartBot,
                      enabled: (widget.botRunning && widget.onStopBot != null) || (!widget.botRunning && widget.onStartBot != null),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade800, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.botRunning ? Colors.green : Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.botRunning ? 'Qwen активен' : 'Qwen не активен',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: widget.botRunning ? Colors.green : Colors.red.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Day Progress Circle
                SizedBox(height: 320, child: MultiLevelCircularProgress(service: widget.timeTrackerService)),

                const SizedBox(height: 24),

                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: 'Сегодня',
                        child: Text(
                          DurationFormatter.format(todayDuration),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.blue.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: 'Таймеры',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.timeTrackerService.timers.length}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.blue.shade300),
                            ),
                            if (activeTimers > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: 'Проект',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeProject?.name ?? 'Нет',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.qwenService?.isLocalModel == true ? Colors.orange : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.qwenService?.isLocalModel == true ? '🖥 Local' : '☁️ Cloud',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: widget.qwenService?.isLocalModel == true ? Colors.orange : Colors.blue.shade300,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Баланс дня
                if (widget.timeTrackerService.currentWorkDay != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.timeTrackerService.todayBalance > Duration.zero
                        ? Colors.red.shade900.withOpacity(0.2)
                        : widget.timeTrackerService.todayBalance < Duration.zero
                          ? Colors.green.shade900.withOpacity(0.2)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.timeTrackerService.todayBalance > Duration.zero
                          ? Colors.red.shade700
                          : widget.timeTrackerService.todayBalance < Duration.zero
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.timeTrackerService.todayBalance > Duration.zero
                                ? '❌ Задолженность'
                                : widget.timeTrackerService.todayBalance < Duration.zero
                                  ? '✅ Свободное время'
                                  : '⚖️ Баланс',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.timeTrackerService.todayBalance > Duration.zero
                                  ? Colors.red.shade400
                                  : widget.timeTrackerService.todayBalance < Duration.zero
                                    ? Colors.green.shade400
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Estimate: ${DurationFormatter.format(widget.timeTrackerService.currentWorkDay!.totalEstimate)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.timeTrackerService.todayBalance > Duration.zero
                                ? '+${DurationFormatter.format(widget.timeTrackerService.todayBalance)}'
                                : DurationFormatter.format(widget.timeTrackerService.todayBalance),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: widget.timeTrackerService.todayBalance > Duration.zero
                                  ? Colors.red.shade400
                                  : widget.timeTrackerService.todayBalance < Duration.zero
                                    ? Colors.green.shade400
                                    : Colors.grey.shade400,
                              ),
                            ),
                            if (widget.timeTrackerService.currentWorkDay!.carriedOver > Duration.zero) ...[
                              const SizedBox(height: 4),
                              Text(
                                '📤 Перенос: ${DurationFormatter.format(widget.timeTrackerService.currentWorkDay!.carriedOver)}',
                                style: TextStyle(fontSize: 10, color: Colors.orange.shade400),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

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
                        // Номер задачи (авто)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade900.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${widget.timeTrackerService.timers.fold<int>(0, (max, t) => t.number > max ? t.number : max) + 1}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade300),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FormBuilderTextField(
                                name: 'name',
                                controller: _nameController,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Task name *',
                                  labelStyle: TextStyle(color: Colors.grey.shade400),
                                  hintText: 'e.g., Fix bug #123',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.blue.shade400),
                                  ),
                                ),
                                validator: FormBuilderValidators.required(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Описание
                        FormBuilderTextField(
                          name: 'description',
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Description (optional)',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            hintText: 'Brief description of the task',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FormBuilderTextField(
                          name: 'project',
                          controller: _projectController,
                          decoration: InputDecoration(
                            labelText: 'Project (optional)',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            hintText: 'e.g., My Project',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'HH',
                                  labelStyle: TextStyle(color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                              child: Text(':', style: TextStyle(fontSize: 32, color: Colors.white)),
                            ),
                            SizedBox(
                              width: 80,
                              child: FormBuilderTextField(
                                name: 'minutes',
                                controller: _minutesController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'MM',
                                  labelStyle: TextStyle(color: Colors.grey.shade400),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.blue.shade400),
                                  ),
                                ),
                                valueTransformer: (value) => int.tryParse(value ?? '0') ?? 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _addTimer,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      'Active Timers (${widget.timeTrackerService.timers.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                    ),
                    if (widget.timeTrackerService.timers.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          widget.timeTrackerService.timers
                              .where((t) => t.isComplete)
                              .toList()
                              .forEach(widget.timeTrackerService.deleteTimer);
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear completed'),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade400),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Timers list
                if (widget.timeTrackerService.timers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(color: Colors.grey.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Icon(Icons.timer_outlined, size: 64, color: Colors.grey.shade700),
                        const SizedBox(height: 16),
                        Text('No timers yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        Text('Add a task to start tracking time', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                else
                  ...widget.timeTrackerService.timers.map((timer) {
                    final isRunning = timer.isRunning;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BlinkingCard(
                        isActive: isRunning,
                        activeColor: Colors.green,
                        child: TimerItem(
                          timer: timer,
                          onStartStop: () async {
                            if (timer.isRunning) {
                              await widget.timeTrackerService.stopTimer(timer);
                            } else if (timer.isComplete) {
                              await widget.timeTrackerService.resumeTimer(timer);
                            } else {
                              await widget.timeTrackerService.startTimer(timer);
                            }
                          },
                          onComplete: () async {
                            // Сохраняем перед завершением
                            await ObjectBoxService().putTimer(timer);
                            await widget.timeTrackerService.completeTimer(timer);
                          },
                          onEdit: () {
                            _showEditTimerDialog(timer);
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
                                    child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      widget.timeTrackerService.deleteTimer(timer);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.history,
                        label: 'History',
                        color: Colors.purple,
                        onTap: () {
                          widget.onQuickAction?.call(DashboardQuickAction.history);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.folder,
                        label: 'Projects',
                        color: Colors.orange,
                        onTap: () {
                          widget.onQuickAction?.call(DashboardQuickAction.projects);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StatusCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Кнопка переключателя моделей
class _ModelSwitchButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _ModelSwitchButton({required this.label, required this.isActive, required this.isEnabled, this.onTap});

  @override
  State<_ModelSwitchButton> createState() => _ModelSwitchButtonState();
}

class _ModelSwitchButtonState extends State<_ModelSwitchButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isActive ? (widget.label.contains('Локальная') ? Colors.orange : Colors.blue) : Colors.grey.shade700;

    return GestureDetector(
      onTap: widget.isEnabled ? widget.onTap : null,
      child: MouseRegion(
        onEnter: (_) {
          if (widget.isEnabled) setState(() => _hovering = true);
        },
        onExit: (_) {
          if (widget.isEnabled) setState(() => _hovering = false);
        },
        cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? baseColor
                : _hovering && widget.isEnabled
                ? baseColor.withValues(alpha: 0.7)
                : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? baseColor
                  : _hovering && widget.isEnabled
                  ? Colors.grey.shade600
                  : Colors.grey.shade700,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isActive)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isEnabled ? (widget.isActive ? Colors.white : Colors.grey.shade300) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _BotControlButton({required this.icon, required this.label, required this.color, this.onTap, this.enabled = true});

  @override
  State<_BotControlButton> createState() => _BotControlButtonState();
}

class _BotControlButtonState extends State<_BotControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (widget.enabled) setState(() => _hovering = false);
      },
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: widget.enabled ? widget.color.withValues(alpha: _hovering ? 0.25 : 0.15) : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.enabled ? widget.color.withValues(alpha: 0.3) : Colors.grey.shade700, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.enabled ? widget.color : Colors.grey.shade500, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.enabled ? widget.color : Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _hovering ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: widget.color, size: 28),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

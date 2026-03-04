import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/bot_settings.dart';
import '../services/app_directory_service.dart';

class SettingsScreen extends StatefulWidget {
  final BotSettings settings;
  final VoidCallback onSaved;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;
  late TextEditingController _userIdsController;
  late TextEditingController _cliPathController;
  late TextEditingController _workDirController;
  late TextEditingController _ollamaModelController;
  late bool _autoStart;
  late bool _yoloMode;
  late bool _notifyOnTimerComplete;
  late bool _notifyOnDayEnd;
  late bool _notifyOnOvertime;
  late int _endDayReminderHour;
  
  // Настройки рабочего дня
  late int _workDayStartHour;
  late int _workDayDurationHours;
  late bool _autoStartDay;
  late bool _autoStopDay;
  
  // Звуковые уведомления
  String? _dayStartSoundPath;
  String? _dayEndSoundPath;
  String? _taskEndingSoonSoundPath;
  late int _taskEndingSoonSeconds;
  
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.settings.telegramBotToken);
    _userIdsController = TextEditingController(
      text: widget.settings.allowedUserIds.join(', '),
    );
    _cliPathController = TextEditingController(text: widget.settings.qwenCliPath);
    _workDirController = TextEditingController(text: widget.settings.workingDirectory);
    _ollamaModelController = TextEditingController(text: widget.settings.ollamaModel);
    _autoStart = widget.settings.autoStartBot;
    _yoloMode = widget.settings.useYoloMode;
    // Настройки уведомлений
    _notifyOnTimerComplete = widget.settings.notifyOnTimerComplete;
    _notifyOnDayEnd = widget.settings.notifyOnDayEnd;
    _notifyOnOvertime = widget.settings.notifyOnOvertime;
    _endDayReminderHour = widget.settings.endDayReminderHour;
    // Настройки рабочего дня
    _workDayStartHour = widget.settings.workDayStartHour;
    _workDayDurationHours = widget.settings.workDayDurationHours;
    _autoStartDay = widget.settings.autoStartDay;
    _autoStopDay = widget.settings.autoStopDay;
    // Звуковые уведомления
    _dayStartSoundPath = widget.settings.dayStartSoundPath;
    _dayEndSoundPath = widget.settings.dayEndSoundPath;
    _taskEndingSoonSoundPath = widget.settings.taskEndingSoonSoundPath;
    _taskEndingSoonSeconds = widget.settings.taskEndingSoonSeconds;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _userIdsController.dispose();
    _cliPathController.dispose();
    _workDirController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  Future<void> _pickQwenCliPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      _cliPathController.text = result.files.single.path!;
      setState(() => _isModified = true);
    }
  }

  Future<void> _pickWorkingDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      _workDirController.text = path;
      setState(() => _isModified = true);
    }
  }

  Future<void> _saveSettings() async {
    final userIds = _userIdsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toList();

    widget.settings.telegramBotToken = _tokenController.text.trim();
    widget.settings.allowedUserIds = userIds;
    widget.settings.qwenCliPath = _cliPathController.text.trim();
    widget.settings.workingDirectory = _workDirController.text.trim();
    widget.settings.autoStartBot = _autoStart;
    widget.settings.useYoloMode = _yoloMode;
    // Настройки уведомлений
    widget.settings.notifyOnTimerComplete = _notifyOnTimerComplete;
    widget.settings.notifyOnDayEnd = _notifyOnDayEnd;
    widget.settings.notifyOnOvertime = _notifyOnOvertime;
    widget.settings.endDayReminderHour = _endDayReminderHour;
    // Настройки нейросетей
    widget.settings.ollamaModel = _ollamaModelController.text.trim();
    // Настройки рабочего дня
    widget.settings.workDayStartHour = _workDayStartHour;
    widget.settings.workDayDurationHours = _workDayDurationHours;
    widget.settings.autoStartDay = _autoStartDay;
    widget.settings.autoStopDay = _autoStopDay;
    // Звуковые уведомления
    widget.settings.dayStartSoundPath = _dayStartSoundPath;
    widget.settings.dayEndSoundPath = _dayEndSoundPath;
    widget.settings.taskEndingSoonSoundPath = _taskEndingSoonSoundPath;
    widget.settings.taskEndingSoonSeconds = _taskEndingSoonSeconds;
    // autoStartLocalModel сохраняется напрямую через SwitchListTile

    await widget.settings.save();
    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки сохранены'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isModified = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: 'Telegram Bot',
                    children: [
                      TextField(
                        controller: _tokenController,
                        onChanged: (_) => setState(() => _isModified = true),
                        decoration: InputDecoration(
                          labelText: 'Bot Token',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          hintText: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _userIdsController,
                        onChanged: (_) => setState(() => _isModified = true),
                        decoration: InputDecoration(
                          labelText: 'Allowed User IDs',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          hintText: '123456789, 987654321',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Разрешённые Telegram User IDs (через запятую)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Qwen Code CLI',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cliPathController,
                              onChanged: (_) => setState(() => _isModified = true),
                              decoration: InputDecoration(
                                labelText: 'Qwen CLI Path',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                hintText: 'qwen или полный путь',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickQwenCliPath,
                            icon: const Icon(Icons.folder),
                            label: const Text('Выбрать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade400,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Директория приложения
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade700),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Директория приложения',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<String>(
                              future: AppDirectoryService().getAppDirectory(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    snapshot.data!,
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  );
                                }
                                return const Text(
                                  'Определение...',
                                  style: TextStyle(fontSize: 11, color: Colors.white54),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _workDirController,
                              onChanged: (_) => setState(() => _isModified = true),
                              decoration: InputDecoration(
                                labelText: 'Working Directory',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickWorkingDirectory,
                            icon: const Icon(Icons.folder),
                            label: const Text('Выбрать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade400,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('YOLO Mode (авто-подтверждение)'),
                        subtitle: Text(
                          'Qwen будет выполнять команды без подтверждения',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _yoloMode,
                        onChanged: (value) {
                          setState(() {
                            _yoloMode = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Рабочий день',
                    children: [
                      SwitchListTile(
                        title: const Text('Авто-старт дня'),
                        subtitle: Text(
                          'Начинать день автоматически в указанное время',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _autoStartDay,
                        onChanged: (value) {
                          setState(() {
                            _autoStartDay = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                      SwitchListTile(
                        title: const Text('Авто-стоп дня'),
                        subtitle: Text(
                          'Завершать день автоматически через указанное время',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _autoStopDay,
                        onChanged: (value) {
                          setState(() {
                            _autoStopDay = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                      ListTile(
                        title: const Text('Время старта'),
                        subtitle: Text('${_workDayStartHour}:00'),
                        trailing: DropdownButton<int>(
                          value: _workDayStartHour,
                          items: List.generate(12, (i) => i + 8)
                              .map((h) => DropdownMenuItem(value: h, child: Text('$h:00')))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _workDayStartHour = value!;
                              _isModified = true;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Продолжительность'),
                        subtitle: Text('${_workDayDurationHours} часов'),
                        trailing: DropdownButton<int>(
                          value: _workDayDurationHours,
                          items: [4, 6, 8, 10, 12]
                              .map((h) => DropdownMenuItem(value: h, child: Text('$h ч')))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _workDayDurationHours = value!;
                              _isModified = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Звуковые уведомления',
                    children: [
                      ListTile(
                        title: const Text('Старт дня'),
                        subtitle: Text(_dayStartSoundPath ?? 'Звук по умолчанию'),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.audio,
                              allowMultiple: false,
                            );
                            if (result != null) {
                              setState(() {
                                _dayStartSoundPath = result.files.single.path;
                                _isModified = true;
                              });
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Завершение дня'),
                        subtitle: Text(_dayEndSoundPath ?? 'Звук по умолчанию'),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.audio,
                              allowMultiple: false,
                            );
                            if (result != null) {
                              setState(() {
                                _dayEndSoundPath = result.files.single.path;
                                _isModified = true;
                              });
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Окончание задачи'),
                        subtitle: Text(_taskEndingSoonSoundPath ?? 'Звук по умолчанию'),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.audio,
                              allowMultiple: false,
                            );
                            if (result != null) {
                              setState(() {
                                _taskEndingSoonSoundPath = result.files.single.path;
                                _isModified = true;
                              });
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Предупреждать за'),
                        subtitle: Text('${_taskEndingSoonSeconds} сек'),
                        trailing: DropdownButton<int>(
                          value: _taskEndingSoonSeconds,
                          items: [30, 60, 120, 300]
                              .map((s) => DropdownMenuItem(value: s, child: Text('$s сек')))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _taskEndingSoonSeconds = value!;
                              _isModified = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Нейросети',
                    children: [
                      const Text(
                        'Переключение модели доступно на Dashboard',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ollamaModelController,
                        onChanged: (_) => setState(() => _isModified = true),
                        decoration: InputDecoration(
                          labelText: 'Модель Ollama',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          hintText: 'qwen2.5-coder:7b-instruct-q4_K_M',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Модель для локального запуска через Ollama',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Автозапуск локальной модели'),
                        subtitle: Text(
                          'Автоматически переключать на локальную модель при старте приложения',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: widget.settings.autoStartLocalModel,
                        onChanged: (value) {
                          setState(() {
                            widget.settings.autoStartLocalModel = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Уведомления',
                    children: [
                      SwitchListTile(
                        title: const Text('Уведомление о завершении таймера'),
                        subtitle: Text(
                          'Отправлять уведомление, когда задача завершена',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _notifyOnTimerComplete,
                        onChanged: (value) {
                          setState(() {
                            _notifyOnTimerComplete = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                      SwitchListTile(
                        title: const Text('Уведомление о завершении дня'),
                        subtitle: Text(
                          'Отправлять статистику в конце рабочего дня',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _notifyOnDayEnd,
                        onChanged: (value) {
                          setState(() {
                            _notifyOnDayEnd = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                      SwitchListTile(
                        title: const Text('Уведомление о превышении времени'),
                        subtitle: Text(
                          'Отправлять уведомление, если задача превысила estimate',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _notifyOnOvertime,
                        onChanged: (value) {
                          setState(() {
                            _notifyOnOvertime = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Время напоминания о завершении дня'),
                        subtitle: Text(
                          'Напоминание в ${_endDayReminderHour}:00',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        trailing: DropdownButton<int>(
                          value: _endDayReminderHour,
                          dropdownColor: Colors.grey.shade800,
                          items: List.generate(12, (i) => i + 14).map((hour) {
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('$hour:00'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _endDayReminderHour = value;
                                _isModified = true;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'Приложение',
                    children: [
                      SwitchListTile(
                        title: const Text('Автозапуск бота'),
                        subtitle: Text(
                          'Запускать бота при старте приложения',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        value: _autoStart,
                        onChanged: (value) {
                          setState(() {
                            _autoStart = value;
                            _isModified = true;
                          });
                        },
                        activeColor: Colors.blue.shade400,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isModified ? _saveSettings : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Сохранить настройки',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade300,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

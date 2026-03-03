import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/project.dart';
import '../services/project_service.dart';

class ProjectsScreen extends StatefulWidget {
  final ProjectService service;
  final Function(Project)? onActivate;

  const ProjectsScreen({
    super.key,
    required this.service,
    this.onActivate,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      _pathController.text = path;
      setState(() {});
    }
  }

  Future<void> _addProject() async {
    if (_nameController.text.trim().isEmpty || _pathController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    await widget.service.addProject(
      name: _nameController.text.trim(),
      workingDirectory: _pathController.text.trim(),
    );

    _nameController.clear();
    _pathController.clear();
    setState(() => _isAdding = false);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Projects',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isAdding = !_isAdding),
                    icon: Icon(_isAdding ? Icons.close : Icons.add),
                    label: Text(_isAdding ? 'Отмена' : 'Добавить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isAdding)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade800, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Название проекта',
                          labelStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pathController,
                              decoration: InputDecoration(
                                labelText: 'Путь к проекту',
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
                            onPressed: _pickDirectory,
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
                      ElevatedButton(
                        onPressed: _addProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ),

              if (!_isAdding) const SizedBox(height: 16),

              Expanded(
                child: widget.service.projects.isEmpty
                    ? Center(
                        child: Text(
                          'Нет проектов. Добавьте первый проект.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.service.projects.length,
                        itemBuilder: (context, index) {
                          final project = widget.service.projects[index];
                          final isActive = project.id == widget.service.activeProjectId;

                          return _ProjectTile(
                            project: project,
                            isActive: isActive,
                            onActivate: () {
                              widget.service.setActive(project.id);
                              widget.onActivate?.call(project);
                            },
                            onDelete: () {
                              widget.service.deleteProject(project.id);
                            },
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

class _ProjectTile extends StatelessWidget {
  final Project project;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const _ProjectTile({
    required this.project,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue.shade900.withValues(alpha: 0.2)
            : Colors.grey.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.blue.shade400 : Colors.grey.shade800,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.shade400 : Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  project.workingDirectory,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isActive)
            ElevatedButton(
              onPressed: onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Актив.', style: TextStyle(fontSize: 11)),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade400),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

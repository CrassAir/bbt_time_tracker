import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import 'log_service.dart';

class ProjectService extends ChangeNotifier {
  static const _storageKey = 'projects_list';
  static const _activeKey = 'active_project_id';

  final _log = LogService();
  List<Project> _projects = [];
  String? _activeProjectId;

  List<Project> get projects => List.unmodifiable(_projects);

  Project? get activeProject {
    if (_activeProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _activeProjectId);
    } catch (_) {
      return null;
    }
  }

  String? get activeProjectId => _activeProjectId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      _projects = Project.decode(raw);
    }
    _activeProjectId = prefs.getString(_activeKey);
    _log.info('Loaded ${_projects.length} projects, active: $_activeProjectId');
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, Project.encode(_projects));
    if (_activeProjectId != null) {
      await prefs.setString(_activeKey, _activeProjectId!);
    } else {
      await prefs.remove(_activeKey);
    }
  }

  Future<Project> addProject({
    required String name,
    required String workingDirectory,
  }) async {
    final project = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      workingDirectory: workingDirectory,
    );
    _projects.add(project);
    await _save();
    _log.info('Added project: ${project.name} (${project.id})');
    notifyListeners();
    return project;
  }

  /// Добавить проект из CLI (принимает Project объект)
  Future<Project> addProjectFromCli(Project project) async {
    project.id = DateTime.now().millisecondsSinceEpoch.toString();
    _projects.add(project);
    await _save();
    _log.info('Added project (CLI): ${project.name} (${project.id})');
    notifyListeners();
    return project;
  }

  Future<void> updateProject(Project project) async {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      await _save();
      _log.info('Updated project: ${project.name}');
      notifyListeners();
    }
  }

  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    if (_activeProjectId == id) {
      _activeProjectId = null;
    }
    await _save();
    _log.info('Deleted project: $id');
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    _activeProjectId = id;
    final project = activeProject;
    if (project != null) {
      project.lastUsedAt = DateTime.now();
    }
    await _save();
    _log.info('Active project: $id');
    notifyListeners();
  }

  Future<void> updateSessionId(String projectId, String sessionId) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx].sessionId = sessionId;
      await _save();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

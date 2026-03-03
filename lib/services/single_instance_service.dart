import 'dart:io';
import 'package:path/path.dart' as p;

class SingleInstanceService {
  static const String _lockFileName = 'qwen_time_tracker.lock';
  File? _lockFile;

  Future<bool> checkIsFirstInstance() async {
    final lockDir = Directory.systemTemp;
    _lockFile = File(p.join(lockDir.path, _lockFileName));

    try {
      if (await _lockFile!.exists()) {
        final content = await _lockFile!.readAsString();
        final pid = int.tryParse(content.trim());

        if (pid != null && pid != 0) {
          if (Platform.isWindows) {
            final result = await Process.run(
              'tasklist',
              ['/FI', 'PID eq $pid', '/NH'],
              runInShell: true,
            );
            if (result.exitCode == 0 &&
                result.stdout.toString().contains('qwen_time_tracker')) {
              return false;
            }
          } else {
            final result = await Process.run('ps', ['-p', pid.toString()]);
            if (result.exitCode == 0) {
              return false;
            }
          }
        }

        await _lockFile!.delete();
      }

      await _lockFile!.writeAsString(pid.toString());
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> dispose() async {
    try {
      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
      }
    } catch (_) {}
  }

  static Future<void> ensureSingleInstance() async {
    final service = SingleInstanceService();
    final isFirst = await service.checkIsFirstInstance();

    if (!isFirst) {
      await _showAlreadyRunningDialog();
      await service.dispose();
      exit(0);
    }
  }

  static Future<void> _showAlreadyRunningDialog() async {
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-Command',
        'Add-Type -AssemblyName PresentationCore,PresentationFramework; '
        '[System.Windows.MessageBox]::Show('
        '"Qwen Time Tracker уже запущен!\\n\\nПриложение уже работает в системном трее.", '
        '"Qwen Time Tracker", '
        '"OK", '
        '[System.Windows.MessageBoxButton]::OK, '
        '[System.Windows.MessageBoxImage]::Warning'
        ')'
      ], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'display dialog "Qwen Time Tracker уже запущен!\\n\\nПриложение уже работает в системном трее." with icon stop buttons {"OK"} default button "OK"',
      ]);
    } else if (Platform.isLinux) {
      await Process.run('zenity', [
        '--warning',
        '--title=Qwen Time Tracker',
        '--text=Qwen Time Tracker уже запущен!\\n\\nПриложение уже работает в системном трее.',
      ], runInShell: true);
    }
  }
}

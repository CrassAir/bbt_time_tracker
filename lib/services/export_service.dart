import 'dart:io';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/timer.dart';
import 'package:intl/intl.dart';

class ExportService {
  static Future<String> exportToExcel(List<Timer> timers) async {
    if (timers.isEmpty) {
      throw Exception('Нет данных для экспорта');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Timer Report'];

    final headers = ['Status', 'Name', 'Created', 'Start', 'End', 'Estimate', 'Duration Left', 'Project', 'URL'];

    for (int i = 0; i < headers.length; i++) {
      final cellIndex = CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0);
      final cell = sheet.cell(cellIndex);
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue100);
    }

    for (final timer in timers) {
      final row = timer.toExportMap().values.map((e) => TextCellValue(e.toString())).toList();
      sheet.appendRow(row);
    }
    excel.delete(excel.getDefaultSheet()!);
    excel.setDefaultSheet(sheet.sheetName);

    final directory = await getDownloadsDirectory();
    final file = File('${directory!.path}/timers_${DateTime.now().millisecondsSinceEpoch}.xlsx');

    final bytes = excel.encode()!;
    await file.writeAsBytes(bytes);

    return file.path;
  }

  static Future<void> shareExcel(List<Timer> timers) async {
    try {
      final path = await exportToExcel(timers);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Отчет таймеров', title: 'Отчет таймеров'));
    } catch (e) {
      print('Ошибка экспорта: $e');
    }
  }

  static Future<void> openExcel(List<Timer> timers) async {
    try {
      final path = await exportToExcel(timers);
      OpenFile.open(path);
    } catch (e) {
      print('Ошибка открытия: $e');
    }
  }
}

extension TimerExport on Timer {
  Map<String, dynamic> toExportMap() {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final timeFormat = DateFormat('dd.MM.yyyy HH:mm');
    
    return {
      'Status': isRunning ? 'Running' : (isComplete ? 'Completed' : 'Pending'),
      'Name': name,
      'Created': dateFormat.format(createdAt.toLocal()),
      'Start': startDateTime != null ? timeFormat.format(startDateTime!.toLocal()) : '-',
      'End': isComplete && startDateTime != null
          ? timeFormat.format(startDateTime!.add(durationLeft ?? Duration.zero).toLocal())
          : '-',
      'Estimate': _formatDuration(estimate),
      'Duration Left': _formatDuration(durationLeft ?? Duration.zero),
      'Project': project ?? '-',
      'URL': url ?? '-',
    };
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

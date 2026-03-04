import 'dart:io';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/timer.dart';
import 'package:intl/intl.dart';
import '../utils/duration_formatter.dart';

class ExportService {
  /// Экспорт с фильтрацией по периоду (по дате старта)
  static Future<String> exportToExcel(
    List<Timer> timers, {
    DateTime? from,
    DateTime? to,
  }) async {
    // Фильтруем по дате старта если указан период
    List<Timer> filtered = timers;
    if (from != null || to != null) {
      filtered = timers.where((t) {
        final start = t.startDateTime;
        if (start == null) return false;
        if (from != null && start.isBefore(from)) return false;
        if (to != null && start.isAfter(to)) return false;
        return true;
      }).toList();
    }

    if (filtered.isEmpty) {
      throw Exception('Нет данных для экспорта');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Timer Report'];

    // Заголовки с балансом
    final headers = ['Status', 'Name', 'Created', 'Start', 'End', 'Estimate', 'Spent', 'Balance', 'Project', 'URL'];

    for (int i = 0; i < headers.length; i++) {
      final cellIndex = CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0);
      final cell = sheet.cell(cellIndex);
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue100);
    }

    // Данные
    for (final timer in filtered) {
      final row = timer.toExportMap().values.map((e) => TextCellValue(e.toString())).toList();
      sheet.appendRow(row);
    }

    // Итоговая строка
    sheet.appendRow([]);
    final totalEstimate = filtered.fold<Duration>(Duration.zero, (sum, t) => sum + t.estimate);
    final totalSpent = filtered.fold<Duration>(Duration.zero, (sum, t) => sum + (t.durationLeft ?? Duration.zero));
    final totalBalance = totalEstimate - totalSpent;
    
    final balanceText = totalBalance > Duration.zero
      ? '+${DurationFormatter.format(totalBalance)}'
      : DurationFormatter.format(totalBalance);

    sheet.appendRow([
      TextCellValue('ИТОГО'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(DurationFormatter.format(totalEstimate)),
      TextCellValue(DurationFormatter.format(totalSpent)),
      TextCellValue(balanceText),
      TextCellValue(''),
      TextCellValue(''),
    ]);

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
    final spent = durationLeft ?? Duration.zero;
    final balance = estimate - spent;
    final balanceText = balance > Duration.zero
      ? '+${DurationFormatter.format(balance)}'
      : DurationFormatter.format(balance);

    return {
      'Status': isRunning ? 'Running' : (isComplete ? 'Completed' : 'Pending'),
      'Name': name,
      'Created': dateFormat.format(createdAt.toLocal()),
      'Start': startDateTime != null ? timeFormat.format(startDateTime!.toLocal()) : '-',
      'End': isComplete && startDateTime != null
          ? timeFormat.format(startDateTime!.add(durationLeft ?? Duration.zero).toLocal())
          : '-',
      'Estimate': DurationFormatter.format(estimate),
      'Spent': DurationFormatter.format(spent),
      'Balance': balanceText,
      'Project': project ?? '-',
      'URL': url ?? '-',
    };
  }
}

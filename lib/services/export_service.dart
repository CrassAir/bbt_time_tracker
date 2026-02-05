import 'dart:io';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bbt_time_tracker/models/time_tracker.dart';

class ExportService {
  static Future<String> exportToExcel(List<TimerModel> timers) async {
    if (timers.isEmpty) {
      throw Exception('Нет данных для экспорта');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Timer Report'];

    final headers = ['Status', 'Name', 'Created', 'Start', 'End', 'Estimate', 'Duration Left','Branch name', 'URL'];

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

  static Future<void> shareExcel(List<TimerModel> timers) async {
    try {
      final path = await exportToExcel(timers);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Отчет таймеров', title: 'Отчет таймеров'));
    } catch (e) {
      print('Ошибка экспорта: $e');
    }
  }

  static Future<void> openExcel(List<TimerModel> timers) async {
    try {
      final path = await exportToExcel(timers);
      OpenFile.open(path);
    } catch (e) {
      print('Ошибка открытия: $e');
    }
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExportFileData {
  final String fileName;
  final List<int> bytes;

  ExportFileData({
    required this.fileName,
    required this.bytes,
  });
}

class ImportStat {
  final String name;
  final int totalRows;
  final int importedRows;

  ImportStat({
    required this.name,
    required this.totalRows,
    required this.importedRows,
  });
}

class ImportResult {
  final List<ImportStat> stats;

  ImportResult(this.stats);
}

class ExcelTransferService {

  /// Build excel data but don't save file yet
  static Future<ExportFileData> buildExportFileData() async {
    final excel = Excel.createExcel();
    final sheet = excel['Records'];

    sheet.appendRow([
      'Date',
      'Category',
      'Amount',
      'Note',
    ]);

    // Dummy sample row (replace with your DB data if needed)
    sheet.appendRow([
      DateTime.now().toString(),
      'Food',
      '100',
      'Sample expense'
    ]);

    final bytes = excel.encode() ?? [];

    final fileName =
        'fintrack_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    return ExportFileData(
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// Save file directly to device
  static Future<String> exportAllData() async {
    final exportData = await buildExportFileData();

    final dir = await _preferredExportDirectory();

    final filePath = '${dir.path}/${exportData.fileName}';

    final file = File(filePath);

    await file.writeAsBytes(exportData.bytes, flush: true);

    return filePath;
  }

  /// Import from excel file bytes
  static Future<ImportResult> importAllDataFromBytes(Uint8List bytes) async {

    final excel = Excel.decodeBytes(bytes);

    List<ImportStat> stats = [];

    for (var table in excel.tables.keys) {

      final sheet = excel.tables[table];

      if (sheet == null) continue;

      int totalRows = sheet.rows.length;
      int importedRows = 0;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        if (row.isEmpty) continue;

        // Here you would normally insert into database
        importedRows++;
      }

      stats.add(
        ImportStat(
          name: table,
          totalRows: totalRows,
          importedRows: importedRows,
        ),
      );
    }

    return ImportResult(stats);
  }

  /// Preferred export directory (ONLY ONE FUNCTION)
  static Future<Directory> _preferredExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }
}

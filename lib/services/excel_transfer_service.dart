import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class ImportSheetStats {
  final String name;
  final int totalRows;
  final int importedRows;

  const ImportSheetStats({
    required this.name,
    required this.totalRows,
    required this.importedRows,
  });
}

class ImportResult {
  final List<ImportSheetStats> stats;

  const ImportResult({required this.stats});
}

class ExcelTransferService {
  static const List<String> orderedSheets = [
    'Records',
    'Budget',
    'Account',
    'Category',
  ];

  static Future<String> exportAllData() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final records = await DatabaseService.getTransactions();
    final budgets = await DatabaseService.getBudgets();
    final accounts = await DatabaseService.getAccounts();
    final categories = await DatabaseService.getCategories();

    _writeSheet(
      excel,
      'Records',
      const ['Category', 'Amount', 'Date', 'Type'],
      records
          .map((record) => [
                record['title']?.toString() ?? '',
                (record['amount'] as num?)?.toDouble() ?? 0,
                record['date']?.toString() ?? '',
                record['type']?.toString() ?? '',
              ])
          .toList(),
    );

    _writeSheet(
      excel,
      'Budget',
      const ['Category', 'Amount', 'Month', 'Year'],
      budgets
          .map((budget) => [
                budget['category']?.toString() ?? '',
                (budget['amount'] as num?)?.toDouble() ?? 0,
                budget['month']?.toString() ?? '',
                budget['year']?.toString() ?? '',
              ])
          .toList(),
    );

    _writeSheet(
      excel,
      'Account',
      const ['Name', 'Type', 'IconCodePoint'],
      accounts
          .map((account) => [
                account['name']?.toString() ?? '',
                account['type']?.toString() ?? '',
                account['icon']?.toString() ?? '',
              ])
          .toList(),
    );

    _writeSheet(
      excel,
      'Category',
      const ['Name', 'Type', 'IconCodePoint'],
      categories
          .map((category) => [
                category['name']?.toString() ?? '',
                category['type']?.toString() ?? '',
                category['icon']?.toString() ?? '',
              ])
          .toList(),
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/fintrack_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    return path;
  }

  static Future<ImportResult> importAllDataFromBytes(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    final rowsBySheet = <String, List<List<dynamic>>>{};
    for (final sheetName in orderedSheets) {
      final sheet = excel.tables[sheetName];
      final rows = sheet?.rows ?? <List<dynamic>>[];
      rowsBySheet[sheetName] = rows;
    }

    final stats = <ImportSheetStats>[];

    final categoryStats = await _importCategories(rowsBySheet['Category']!);
    stats.add(categoryStats);

    final accountStats = await _importAccounts(rowsBySheet['Account']!);
    stats.add(accountStats);

    final budgetStats = await _importBudgets(rowsBySheet['Budget']!);
    stats.add(budgetStats);

    final recordStats = await _importRecords(rowsBySheet['Records']!);
    stats.add(recordStats);

    final orderedStats = [
      _statFor('Records', stats),
      _statFor('Budget', stats),
      _statFor('Account', stats),
      _statFor('Category', stats),
    ];

    return ImportResult(stats: orderedStats);
  }

  static ImportSheetStats _statFor(String name, List<ImportSheetStats> stats) {
    return stats.firstWhere((s) => s.name == name,
        orElse: () => ImportSheetStats(name: name, totalRows: 0, importedRows: 0));
  }

  static void _writeSheet(
    Excel excel,
    String name,
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    final sheet = excel[name];

    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
          TextCellValue(headers[i]);
    }

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (var colIndex = 0; colIndex < rows[rowIndex].length; colIndex++) {
        final value = rows[rowIndex][colIndex];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1))
            .value = TextCellValue(value.toString());
      }
    }
  }

  static Future<ImportSheetStats> _importCategories(List<List<dynamic>> rows) async {
    var imported = 0;
    final dataRows = _dataRows(rows);

    for (final row in dataRows) {
      final name = _cell(row, 0);
      final type = _normalizedType(_cell(row, 1));
      final icon = int.tryParse(_cell(row, 2)) ?? 0xe0b7;

      if (name.isEmpty || type.isEmpty) {
        continue;
      }

      final exists = await DatabaseService.categoryExists(name, type);
      if (!exists) {
        await DatabaseService.insertCategory(name, type, icon);
        imported++;
      }
    }

    return ImportSheetStats(name: 'Category', totalRows: dataRows.length, importedRows: imported);
  }

  static Future<ImportSheetStats> _importAccounts(List<List<dynamic>> rows) async {
    var imported = 0;
    final dataRows = _dataRows(rows);

    for (final row in dataRows) {
      final name = _cell(row, 0);
      final type = _normalizedType(_cell(row, 1));
      final icon = int.tryParse(_cell(row, 2)) ?? 0xe851;

      if (name.isEmpty || type.isEmpty) {
        continue;
      }

      final exists = await DatabaseService.accountExists(name, type);
      if (!exists) {
        await DatabaseService.insertAccount(name, type, icon);
        imported++;
      }
    }

    return ImportSheetStats(name: 'Account', totalRows: dataRows.length, importedRows: imported);
  }

  static Future<ImportSheetStats> _importBudgets(List<List<dynamic>> rows) async {
    var imported = 0;
    final dataRows = _dataRows(rows);

    for (final row in dataRows) {
      final category = _cell(row, 0);
      final amount = double.tryParse(_cell(row, 1)) ?? 0;
      final month = int.tryParse(_cell(row, 2)) ?? 0;
      final year = int.tryParse(_cell(row, 3)) ?? 0;

      if (category.isEmpty || amount <= 0 || month <= 0 || year <= 0) {
        continue;
      }

      await DatabaseService.insertBudget(category, amount, month, year);
      imported++;
    }

    return ImportSheetStats(name: 'Budget', totalRows: dataRows.length, importedRows: imported);
  }

  static Future<ImportSheetStats> _importRecords(List<List<dynamic>> rows) async {
    var imported = 0;
    final dataRows = _dataRows(rows);

    for (final row in dataRows) {
      final category = _cell(row, 0);
      final amount = double.tryParse(_cell(row, 1)) ?? 0;
      final parsedDate = DateTime.tryParse(_cell(row, 2));
      final type = _normalizedType(_cell(row, 3));

      if (category.isEmpty || amount <= 0 || parsedDate == null || type.isEmpty) {
        continue;
      }

      final categoryExists = await DatabaseService.categoryExists(category, type);
      if (!categoryExists) {
        await DatabaseService.insertCategory(category, type, 0xe0b7);
      }

      await DatabaseService.insertTransaction(category, amount, parsedDate, type);
      imported++;
    }

    return ImportSheetStats(name: 'Records', totalRows: dataRows.length, importedRows: imported);
  }

  static List<List<dynamic>> _dataRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];
    return rows.sublist(1).where((row) => row.any((cell) => _stringCell(cell).isNotEmpty)).toList();
  }

  static String _cell(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return _stringCell(row[index]).trim();
  }

  static String _stringCell(dynamic data) {
    if (data == null || data.value == null) return '';
    return data.value.toString();
  }

  static String _normalizedType(String type) {
    final lower = type.trim().toLowerCase();
    if (lower == 'income') return 'income';
    if (lower == 'expense') return 'expense';
    return '';
  }
}

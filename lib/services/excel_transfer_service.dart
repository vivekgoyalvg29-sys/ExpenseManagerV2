import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

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
  static const String _recordsSheet = 'Records';
  static const String _budgetSheet = 'budget';
  static const String _accountsSheet = 'accounts';
  static const String _categorySheet = 'category';

  /// Build excel data but don't save file yet
  static Future<ExportFileData> buildExportFileData() async {
    final excel = Excel.createExcel();

    final db = await DatabaseService.database;
    final transactions = await db.query('transactions', orderBy: 'date DESC');
    final budgets = await db.query('budgets', orderBy: 'year DESC, month DESC');
    final accounts = await db.query('accounts', orderBy: 'name ASC');
    final categories = await db.query('categories', orderBy: 'name ASC');

    final categoryTypeByName = <String, String>{
      for (final cat in categories)
        (cat['name']?.toString().trim().toLowerCase() ?? ''): cat['type']?.toString().trim() ?? 'expense',
    };

    final recordsSheet = excel[_recordsSheet];
    recordsSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Account'),
    ]);

    for (final tx in transactions) {
      recordsSheet.appendRow([
        IntCellValue((tx['id'] as num?)?.toInt() ?? 0),
        TextCellValue(tx['title']?.toString() ?? ''),
        DoubleCellValue((tx['amount'] as num?)?.toDouble() ?? 0),
        TextCellValue(tx['date']?.toString() ?? ''),
        TextCellValue(tx['type']?.toString() ?? ''),
        TextCellValue(''),
      ]);
    }

    final budgetSheet = excel[_budgetSheet];
    budgetSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Month'),
      TextCellValue('Year'),
      TextCellValue('Type'),
    ]);

    for (final budget in budgets) {
      final categoryName = budget['category']?.toString() ?? '';
      final categoryType = categoryTypeByName[categoryName.trim().toLowerCase()] ?? 'expense';
      budgetSheet.appendRow([
        IntCellValue((budget['id'] as num?)?.toInt() ?? 0),
        TextCellValue(categoryName),
        DoubleCellValue((budget['amount'] as num?)?.toDouble() ?? 0),
        IntCellValue((budget['month'] as num?)?.toInt() ?? 0),
        IntCellValue((budget['year'] as num?)?.toInt() ?? 0),
        TextCellValue(categoryType),
      ]);
    }

    final accountsSheet = excel[_accountsSheet];
    accountsSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Icon'),
    ]);

    for (final account in accounts) {
      accountsSheet.appendRow([
        IntCellValue((account['id'] as num?)?.toInt() ?? 0),
        TextCellValue(account['name']?.toString() ?? ''),
        TextCellValue(account['type']?.toString() ?? ''),
        IntCellValue((account['icon'] as num?)?.toInt() ?? 0),
      ]);
    }

    final categorySheet = excel[_categorySheet];
    categorySheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Icon'),
    ]);

    for (final category in categories) {
      categorySheet.appendRow([
        IntCellValue((category['id'] as num?)?.toInt() ?? 0),
        TextCellValue(category['name']?.toString() ?? ''),
        TextCellValue(category['type']?.toString() ?? ''),
        IntCellValue((category['icon'] as num?)?.toInt() ?? 0),
      ]);
    }

    // Remove default auto-created sheet only after all target sheets exist.
    for (final defaultSheet in ['Sheet1', 'Sheet']) {
      if (![
        _recordsSheet,
        _budgetSheet,
        _accountsSheet,
        _categorySheet,
      ].contains(defaultSheet) &&
          excel.tables.containsKey(defaultSheet)) {
        excel.delete(defaultSheet);
      }
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not generate a valid Excel file.');
    }

    final fileName = 'fintrack_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

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
    final db = await DatabaseService.database;

    final stats = <ImportStat>[];

    final importers = <String, Future<int> Function(Database, Sheet)>{
      _recordsSheet: _importRecords,
      _budgetSheet: _importBudgets,
      _accountsSheet: _importAccounts,
      _categorySheet: _importCategories,
    };

    for (final sheetName in [_recordsSheet, _budgetSheet, _accountsSheet, _categorySheet]) {
      final sheet = _findSheetByName(excel, sheetName);
      final dataRows = sheet == null || sheet.rows.isEmpty ? 0 : sheet.rows.length - 1;
      int importedRows = 0;

      if (sheet != null) {
        importedRows = await importers[sheetName]!(db, sheet);
      }

      stats.add(
        ImportStat(
          name: sheetName,
          totalRows: dataRows,
          importedRows: importedRows,
        ),
      );
    }

    return ImportResult(stats);
  }

  static Future<int> _importRecords(Database db, Sheet sheet) async {
    int importedRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final id = _asInt(_cellValue(row, 0));
      final category = _asString(_cellValue(row, 1));
      final amount = _asDouble(_cellValue(row, 2));
      final dateText = _asString(_cellValue(row, 3));
      final type = _normalizeType(_asString(_cellValue(row, 4)));
      final account = _asString(_cellValue(row, 5));

      if (category.isEmpty || amount == null || dateText.isEmpty) {
        continue;
      }

      final parsedDate = DateTime.tryParse(dateText);
      final normalizedDate = (parsedDate ?? DateTime.now()).toIso8601String();

      await _ensureCategoryExists(db, category, type);
      if (account.isNotEmpty) {
        await _ensureAccountExists(db, account, type);
      }

      final values = {
        'title': category,
        'amount': amount,
        'date': normalizedDate,
        'type': type,
      };

      if (id != null && id > 0) {
        final updated = await db.update(
          'transactions',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (updated == 0) {
          await db.insert('transactions', {'id': id, ...values});
        }
      } else {
        await db.insert('transactions', values);
      }

      importedRows++;
    }

    return importedRows;
  }

  static Future<int> _importBudgets(Database db, Sheet sheet) async {
    int importedRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final id = _asInt(_cellValue(row, 0));
      final category = _asString(_cellValue(row, 1));
      final amount = _asDouble(_cellValue(row, 2));
      final month = _asInt(_cellValue(row, 3));
      final year = _asInt(_cellValue(row, 4));
      final type = _normalizeType(_asString(_cellValue(row, 5)), fallback: 'expense');

      if (category.isEmpty || amount == null || month == null || year == null) {
        continue;
      }

      await _ensureCategoryExists(db, category, type);

      final values = {
        'category': category,
        'amount': amount,
        'month': month,
        'year': year,
      };

      if (id != null && id > 0) {
        final updated = await db.update(
          'budgets',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (updated == 0) {
          await db.insert('budgets', {'id': id, ...values});
        }
      } else {
        await db.insert('budgets', values);
      }

      importedRows++;
    }

    return importedRows;
  }

  static Future<int> _importAccounts(Database db, Sheet sheet) async {
    int importedRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final id = _asInt(_cellValue(row, 0));
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;

      if (name.isEmpty) continue;

      await _upsertLookupRow(
        db: db,
        table: 'accounts',
        id: id,
        name: name,
        type: type,
        icon: icon,
      );

      importedRows++;
    }

    return importedRows;
  }

  static Future<int> _importCategories(Database db, Sheet sheet) async {
    int importedRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final id = _asInt(_cellValue(row, 0));
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;

      if (name.isEmpty) continue;

      await _upsertLookupRow(
        db: db,
        table: 'categories',
        id: id,
        name: name,
        type: type,
        icon: icon,
      );

      importedRows++;
    }

    return importedRows;
  }

  static Future<void> _ensureCategoryExists(Database db, String name, String type) async {
    await _ensureLookupExists(db, 'categories', name, type, 0);
  }

  static Future<void> _ensureAccountExists(Database db, String name, String type) async {
    await _ensureLookupExists(db, 'accounts', name, type, 0);
  }

  static Future<void> _ensureLookupExists(
    Database db,
    String table,
    String name,
    String type,
    int icon,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;

    final existing = await db.query(
      table,
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [normalizedName.toLowerCase(), type],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(table, {
        'name': normalizedName,
        'type': type,
        'icon': icon,
      });
    }
  }

  static Future<void> _upsertLookupRow({
    required Database db,
    required String table,
    required int? id,
    required String name,
    required String type,
    required int icon,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;

    final values = {
      'name': normalizedName,
      'type': type,
      'icon': icon,
    };

    if (id != null && id > 0) {
      final updated = await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updated > 0) {
        return;
      }
    }

    final existingByNameType = await db.query(
      table,
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [normalizedName.toLowerCase(), type],
      limit: 1,
    );

    if (existingByNameType.isNotEmpty) {
      await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [existingByNameType.first['id']],
      );
      return;
    }

    if (id != null && id > 0) {
      await db.insert(table, {'id': id, ...values});
      return;
    }

    await db.insert(table, values);
  }

  static Data? _cellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    return row[index];
  }

  static bool _isRowEmpty(List<Data?> row) {
    return row.every((cell) => _asString(cell).isEmpty);
  }

  static String _asString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  static int? _asInt(Data? cell) {
    final raw = _asString(cell);
    if (raw.isEmpty) return null;
    if (cell?.value is num) {
      return (cell!.value as num).toInt();
    }
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
  }

  static double? _asDouble(Data? cell) {
    final raw = _asString(cell);
    if (raw.isEmpty) return null;
    if (cell?.value is num) {
      return (cell!.value as num).toDouble();
    }
    return double.tryParse(raw);
  }

  static String _normalizeType(String value, {String fallback = 'expense'}) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'income' || normalized == 'expense') {
      return normalized;
    }
    return fallback;
  }

  static Sheet? _findSheetByName(Excel excel, String sheetName) {
    final aliases = <String>{sheetName};

    if (sheetName == _budgetSheet) {
      aliases.add('Budget');
    }

    if (sheetName == _accountsSheet) {
      aliases.add('Accounts');
    }

    if (sheetName == _categorySheet) {
      aliases.add('Category');
    }

    for (final entry in excel.tables.entries) {
      if (aliases.any((name) => name.toLowerCase() == entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Preferred export directory
  static Future<Directory> _preferredExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }
}

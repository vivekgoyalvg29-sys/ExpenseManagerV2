import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class ExportFileData {
  final String fileName;
  final List<int> bytes;

  ExportFileData({required this.fileName, required this.bytes});
}

class ImportStat {
  final String name;
  final int totalRows;
  final int importedRows;

  ImportStat({required this.name, required this.totalRows, required this.importedRows});
}

class ImportResult {
  final List<ImportStat> stats;

  ImportResult(this.stats);
}

class ExcelTransferService {
  static const String _recordsSheet = 'Records';
  static const String _budgetsSheet = 'Budgets';
  static const String _accountsSheet = 'Accounts';
  static const String _categoriesSheet = 'Categories';
  static const String _customIconsSheet = 'CustomIcons';

  static const List<String> _exportSheetOrder = [
    _recordsSheet,
    _budgetsSheet,
    _accountsSheet,
    _categoriesSheet,
    _customIconsSheet,
  ];

  static const List<String> _importSheetOrder = [
    _customIconsSheet,
    _categoriesSheet,
    _accountsSheet,
    _budgetsSheet,
    _recordsSheet,
  ];

  static const Map<String, List<String>> _sheetAliases = {
    _recordsSheet: [_recordsSheet],
    _budgetsSheet: [_budgetsSheet, 'Budget'],
    _accountsSheet: [_accountsSheet],
    _categoriesSheet: [_categoriesSheet, 'Category'],
    _customIconsSheet: [_customIconsSheet, 'Icons', 'Custom Icon', 'CustomIcons'],
  };

  static Future<ExportFileData> buildExportFileData() async {
    final excel = Excel.createExcel();
    final recordsSheet = _prepareRecordsSheet(excel);

    final db = await DatabaseService.database;
    final transactions = await db.query('transactions', orderBy: 'date DESC');
    final budgets = await db.query('budgets', orderBy: 'year DESC, month DESC, id DESC');
    final accounts = await db.query('accounts', orderBy: 'name COLLATE NOCASE ASC, id ASC');
    final categories = await db.query('categories', orderBy: 'name COLLATE NOCASE ASC, id ASC');

    final categoryTypeByName = <String, String>{
      for (final category in categories)
        (category['name']?.toString().trim().toLowerCase() ?? ''):
            category['type']?.toString().trim().toLowerCase() ?? 'expense',
    };

    recordsSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Account'),
      TextCellValue('Comment'),
    ]);

    for (final transaction in transactions) {
      recordsSheet.appendRow([
        IntCellValue((transaction['id'] as num?)?.toInt() ?? 0),
        TextCellValue(transaction['title']?.toString() ?? ''),
        DoubleCellValue((transaction['amount'] as num?)?.toDouble() ?? 0),
        TextCellValue(transaction['date']?.toString() ?? ''),
        TextCellValue(transaction['type']?.toString() ?? ''),
        TextCellValue(transaction['account']?.toString() ?? ''),
        TextCellValue(transaction['comment']?.toString() ?? ''),
      ]);
    }

    final budgetsSheet = excel[_budgetsSheet];
    budgetsSheet.appendRow([
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
      budgetsSheet.appendRow([
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
      TextCellValue('IconPath'),
    ]);

    for (final account in accounts) {
      accountsSheet.appendRow([
        IntCellValue((account['id'] as num?)?.toInt() ?? 0),
        TextCellValue(account['name']?.toString() ?? ''),
        TextCellValue(account['type']?.toString() ?? ''),
        IntCellValue((account['icon'] as num?)?.toInt() ?? 0),
        TextCellValue(account['icon_path']?.toString() ?? ''),
      ]);
    }

    final categoriesSheet = excel[_categoriesSheet];
    categoriesSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Icon'),
      TextCellValue('IconPath'),
    ]);

    for (final category in categories) {
      categoriesSheet.appendRow([
        IntCellValue((category['id'] as num?)?.toInt() ?? 0),
        TextCellValue(category['name']?.toString() ?? ''),
        TextCellValue(category['type']?.toString() ?? ''),
        IntCellValue((category['icon'] as num?)?.toInt() ?? 0),
        TextCellValue(category['icon_path']?.toString() ?? ''),
      ]);
    }

    final customIcons = await _collectCustomIconsPayloads([...accounts, ...categories]);
    final iconsSheet = excel[_customIconsSheet];
    iconsSheet.appendRow([
      TextCellValue('OriginalPath'),
      TextCellValue('FileName'),
      TextCellValue('Base64Data'),
    ]);
    for (final icon in customIcons) {
      iconsSheet.appendRow([
        TextCellValue(icon.originalPath),
        TextCellValue(icon.fileName),
        TextCellValue(icon.base64Data),
      ]);
    }

    final bytes = excel.encode() ?? [];
    return ExportFileData(
      fileName: 'AllData.xlsx',
      bytes: bytes,
    );
  }

  static Sheet _prepareRecordsSheet(Excel excel) {
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != _recordsSheet) {
      excel.rename(defaultSheet, _recordsSheet);
    }
    excel.setDefaultSheet(_recordsSheet);
    for (final extraSheet in ['Sheet1', 'Sheet']) {
      if (extraSheet != _recordsSheet && excel.tables.containsKey(extraSheet)) {
        excel.delete(extraSheet);
      }
    }
    return excel[_recordsSheet];
  }

  static Future<String> exportAllData() async {
    final exportData = await buildExportFileData();
    final dir = await _preferredExportDirectory();
    final filePath = '${dir.path}/${exportData.fileName}';
    final file = File(filePath);
    await file.writeAsBytes(exportData.bytes, flush: true);
    return filePath;
  }

  static Future<ImportResult> importAllDataFromBytes(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final db = await DatabaseService.database;
    final stats = <ImportStat>[];
    final customIconPathMap = await _importCustomIcons(excel);

    final importers = <String, Future<int> Function(Database, Sheet)>{
      _recordsSheet: _importRecords,
      _budgetsSheet: _importBudgets,
      _accountsSheet: (db, sheet) => _importAccounts(db, sheet, customIconPathMap),
      _categoriesSheet: (db, sheet) => _importCategories(db, sheet, customIconPathMap),
      _customIconsSheet: (_, __) async => customIconPathMap.length,
    };

    for (final sheetName in _importSheetOrder) {
      final sheet = _resolveSheet(excel, sheetName);
      final dataRows = sheet == null || sheet.rows.isEmpty ? 0 : sheet.rows.length - 1;
      final importedRows = sheet == null ? 0 : await importers[sheetName]!(db, sheet);
      stats.add(ImportStat(name: sheetName, totalRows: dataRows, importedRows: importedRows));
    }

    return ImportResult(_sortStatsForDisplay(stats));
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
      final comment = _asString(_cellValue(row, 6));

      if (category.isEmpty || amount == null || dateText.isEmpty) continue;

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
        'account': account,
        'comment': comment,
      };

      if (id != null && id > 0) {
        final updated = await db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
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
      if (category.isEmpty || amount == null || month == null || year == null) continue;
      await _ensureCategoryExists(db, category, type);
      final values = {'category': category, 'amount': amount, 'month': month, 'year': year};
      if (id != null && id > 0) {
        final updated = await db.update('budgets', values, where: 'id = ?', whereArgs: [id]);
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

  static Future<int> _importAccounts(Database db, Sheet sheet, Map<String, String> customIconPathMap) async {
    int importedRows = 0;
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;
      final id = _asInt(_cellValue(row, 0));
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;
      final iconPath = _resolveImportedIconPath(_asString(_cellValue(row, 4)), customIconPathMap);
      if (name.isEmpty) continue;
      await _upsertLookupRow(db: db, table: 'accounts', id: id, name: name, type: type, icon: icon, iconPath: iconPath);
      importedRows++;
    }
    return importedRows;
  }

  static Future<int> _importCategories(Database db, Sheet sheet, Map<String, String> customIconPathMap) async {
    int importedRows = 0;
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;
      final id = _asInt(_cellValue(row, 0));
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;
      final iconPath = _resolveImportedIconPath(_asString(_cellValue(row, 4)), customIconPathMap);
      if (name.isEmpty) continue;
      await _upsertLookupRow(db: db, table: 'categories', id: id, name: name, type: type, icon: icon, iconPath: iconPath);
      importedRows++;
    }
    return importedRows;
  }

  static Future<void> _ensureCategoryExists(Database db, String name, String type) async => _ensureLookupExists(db, 'categories', name, type, 0, '');
  static Future<void> _ensureAccountExists(Database db, String name, String type) async => _ensureLookupExists(db, 'accounts', name, type, 0, '');

  static Future<void> _ensureLookupExists(Database db, String table, String name, String type, int icon, String iconPath) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final existing = await db.query(table, where: 'LOWER(name) = ? AND type = ?', whereArgs: [normalizedName.toLowerCase(), type], limit: 1);
    if (existing.isEmpty) {
      await db.insert(table, {'name': normalizedName, 'type': type, 'icon': icon, 'icon_path': iconPath});
    }
  }

  static Future<void> _upsertLookupRow({required Database db, required String table, required int? id, required String name, required String type, required int icon, required String iconPath}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final values = {'name': normalizedName, 'type': type, 'icon': icon, 'icon_path': iconPath.isEmpty ? null : iconPath};
    if (id != null && id > 0) {
      final updated = await db.update(table, values, where: 'id = ?', whereArgs: [id]);
      if (updated > 0) return;
    }
    final existingByNameType = await db.query(table, where: 'LOWER(name) = ? AND type = ?', whereArgs: [normalizedName.toLowerCase(), type], limit: 1);
    if (existingByNameType.isNotEmpty) {
      await db.update(table, values, where: 'id = ?', whereArgs: [existingByNameType.first['id']]);
      return;
    }
    if (id != null && id > 0) {
      await db.insert(table, {'id': id, ...values});
      return;
    }
    await db.insert(table, values);
  }

  static Sheet? _resolveSheet(Excel excel, String canonicalName) {
    for (final candidate in _sheetAliases[canonicalName] ?? [canonicalName]) {
      final sheet = excel.tables[candidate];
      if (sheet != null) return sheet;
    }
    return null;
  }

  static List<ImportStat> _sortStatsForDisplay(List<ImportStat> stats) {
    final byName = {for (final stat in stats) stat.name: stat};
    return [for (final sheetName in _exportSheetOrder) if (byName.containsKey(sheetName)) byName[sheetName]!];
  }

  static Data? _cellValue(List<Data?> row, int index) => index >= row.length ? null : row[index];
  static bool _isRowEmpty(List<Data?> row) => row.every((cell) => _asString(cell).isEmpty);
  static String _asString(Data? cell) => cell == null || cell.value == null ? '' : cell.value.toString().trim();
  static int? _asInt(Data? cell) {
    final raw = _asString(cell);
    if (raw.isEmpty) return null;
    if (cell?.value is num) return (cell!.value as num).toInt();
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
  }
  static double? _asDouble(Data? cell) {
    final raw = _asString(cell);
    if (raw.isEmpty) return null;
    if (cell?.value is num) return (cell!.value as num).toDouble();
    return double.tryParse(raw);
  }
  static String _normalizeType(String value, {String fallback = 'expense'}) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'income' || normalized == 'expense') return normalized;
    return fallback;
  }

  static Future<Directory> _preferredExportDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  static String _resolveImportedIconPath(String source, Map<String, String> customIconPathMap) {
    if (source.isEmpty) return '';
    final byExactPath = customIconPathMap[source];
    if (byExactPath != null) return byExactPath;
    final fileName = p.basename(source);
    if (fileName.isEmpty) return source;
    final byFileName = customIconPathMap[fileName];
    return byFileName ?? source;
  }

  static Future<List<_CustomIconPayload>> _collectCustomIconsPayloads(List<Map<String, dynamic>> rows) async {
    final payloads = <_CustomIconPayload>[];
    final seenPaths = <String>{};

    for (final row in rows) {
      final iconPath = row['icon_path']?.toString() ?? '';
      if (iconPath.isEmpty || seenPaths.contains(iconPath)) continue;
      seenPaths.add(iconPath);

      final file = File(iconPath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      payloads.add(_CustomIconPayload(
        originalPath: iconPath,
        fileName: p.basename(iconPath),
        base64Data: base64Encode(bytes),
      ));
    }

    return payloads;
  }

  static Future<Map<String, String>> _importCustomIcons(Excel excel) async {
    final sheet = _resolveSheet(excel, _customIconsSheet);
    if (sheet == null || sheet.rows.length <= 1) return const {};

    final directory = await getApplicationDocumentsDirectory();
    final iconsDirectory = Directory(p.join(directory.path, 'custom_icons'));
    if (!await iconsDirectory.exists()) {
      await iconsDirectory.create(recursive: true);
    }

    final mapped = <String, String>{};

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final originalPath = _asString(_cellValue(row, 0));
      final fileNameFromSheet = _asString(_cellValue(row, 1));
      final base64Data = _asString(_cellValue(row, 2));
      if (base64Data.isEmpty) continue;

      Uint8List iconBytes;
      try {
        iconBytes = base64Decode(base64Data);
      } catch (_) {
        continue;
      }
      if (iconBytes.isEmpty) continue;

      final extension = p.extension(fileNameFromSheet).isEmpty ? '.png' : p.extension(fileNameFromSheet);
      final baseName = p.basenameWithoutExtension(fileNameFromSheet).trim();
      final safeBaseName = baseName.isEmpty ? 'imported_icon' : baseName;
      final storedPath = p.join(
        iconsDirectory.path,
        '${safeBaseName}_${DateTime.now().microsecondsSinceEpoch}$extension',
      );

      final output = File(storedPath);
      await output.writeAsBytes(iconBytes, flush: true);
      mapped[originalPath] = storedPath;
      mapped[fileNameFromSheet] = storedPath;
    }

    return mapped;
  }
}

class _CustomIconPayload {
  final String originalPath;
  final String fileName;
  final String base64Data;

  _CustomIconPayload({
    required this.originalPath,
    required this.fileName,
    required this.base64Data,
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data_service.dart';
import 'firestore_service.dart';
import 'profile_service.dart';

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
  static final _profileService = ProfileService();

  /// During a single import run, skip repeated category/account existence checks.
  static final Set<String> _importEnsuredCategoryKeys = {};
  static final Set<String> _importEnsuredAccountKeys = {};
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

    final transactions = await DataService.getTransactions();
    final budgets = await DataService.getBudgets();
    final accounts = await DataService.getAccounts();
    final categories = await DataService.getCategories();

    // Resolve the active profile's identifier for export tagging
    final profileService = ProfileService();
    final activeProfile = await profileService.getActiveProfile();
    final profileName = activeProfile?.name ?? '';
    final profileIdentifier = activeProfile != null
        ? (activeProfile.isShareable
            ? activeProfile.shareCode
            : (FirebaseAuth.instance.currentUser?.phoneNumber ?? ''))
        : (FirebaseAuth.instance.currentUser?.phoneNumber ?? '');

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
      TextCellValue('ProfileIdentifier'),
      TextCellValue('ProfileName'),
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
        TextCellValue(profileIdentifier),
        TextCellValue(profileName),
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
      TextCellValue('ProfileIdentifier'),
      TextCellValue('ProfileName'),
    ]);

    for (final budget in budgets) {
      final categoryName = budget['category']?.toString() ?? '';
      final categoryType =
          categoryTypeByName[categoryName.trim().toLowerCase()] ?? 'expense';
      budgetsSheet.appendRow([
        IntCellValue((budget['id'] as num?)?.toInt() ?? 0),
        TextCellValue(categoryName),
        DoubleCellValue((budget['amount'] as num?)?.toDouble() ?? 0),
        IntCellValue((budget['month'] as num?)?.toInt() ?? 0),
        IntCellValue((budget['year'] as num?)?.toInt() ?? 0),
        TextCellValue(categoryType),
        TextCellValue(profileIdentifier),
        TextCellValue(profileName),
      ]);
    }

    final accountsSheet = excel[_accountsSheet];
    accountsSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Icon'),
      TextCellValue('IconPath'),
      TextCellValue('ProfileIdentifier'),
      TextCellValue('ProfileName'),
    ]);

    for (final account in accounts) {
      accountsSheet.appendRow([
        IntCellValue((account['id'] as num?)?.toInt() ?? 0),
        TextCellValue(account['name']?.toString() ?? ''),
        TextCellValue(account['type']?.toString() ?? ''),
        IntCellValue((account['icon'] as num?)?.toInt() ?? 0),
        TextCellValue(account['icon_path']?.toString() ?? ''),
        TextCellValue(profileIdentifier),
        TextCellValue(profileName),
      ]);
    }

    final categoriesSheet = excel[_categoriesSheet];
    categoriesSheet.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Icon'),
      TextCellValue('IconPath'),
      TextCellValue('ProfileIdentifier'),
      TextCellValue('ProfileName'),
    ]);

    for (final category in categories) {
      categoriesSheet.appendRow([
        IntCellValue((category['id'] as num?)?.toInt() ?? 0),
        TextCellValue(category['name']?.toString() ?? ''),
        TextCellValue(category['type']?.toString() ?? ''),
        IntCellValue((category['icon'] as num?)?.toInt() ?? 0),
        TextCellValue(category['icon_path']?.toString() ?? ''),
        TextCellValue(profileIdentifier),
        TextCellValue(profileName),
      ]);
    }

    final customIcons =
        await _collectCustomIconsPayloads([...accounts, ...categories]);
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
    return ExportFileData(fileName: 'AllData.xlsx', bytes: bytes);
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
    _importEnsuredCategoryKeys.clear();
    _importEnsuredAccountKeys.clear();
    final excel = Excel.decodeBytes(bytes);
    final stats = <ImportStat>[];
    final customIconPathMap = await _importCustomIcons(excel);
    final profileService = ProfileService();
    final firestoreService = FirestoreService();

    // Collect all unique (identifier, profileName) pairs across all data sheets
    final identifierPairs = <({String identifier, String name})>{};
    for (final sheetName in [
      _recordsSheet,
      _budgetsSheet,
      _accountsSheet,
      _categoriesSheet,
    ]) {
      final sheet = _resolveSheet(excel, sheetName);
      if (sheet == null || sheet.rows.length < 2) continue;
      final headerRow = sheet.rows.first;
      final idCol = _findColumnIndex(headerRow, 'ProfileIdentifier');
      final nameCol = _findColumnIndex(headerRow, 'ProfileName');
      if (idCol == null || nameCol == null) continue;
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (_isRowEmpty(row)) continue;
        final id = _asString(_cellValue(row, idCol));
        final nm = _asString(_cellValue(row, nameCol));
        if (id.isNotEmpty) identifierPairs.add((identifier: id, name: nm));
      }
    }

    // Build map: (identifier, profileName) → profileId (null = no access / skip)
    final resolvedProfiles = <String, String?>{};
    for (final pair in identifierPairs) {
      final key = '${pair.identifier}|||${pair.name}';
      final profileId = await profileService.findProfileIdByIdentifier(
        pair.identifier,
        pair.name,
      );
      resolvedProfiles[key] = profileId;
    }

    // Determine whether the file has profile columns at all
    final hasProfileCols = identifierPairs.isNotEmpty;

    for (final sheetName in _importSheetOrder) {
      final sheet = _resolveSheet(excel, sheetName);
      final dataRows = sheet == null || sheet.rows.isEmpty
          ? 0
          : sheet.rows.length - 1;
      int importedRows = 0;

      if (sheet != null) {
        if (sheetName == _customIconsSheet) {
          importedRows = customIconPathMap.length;
        } else {
          final headerRow =
              sheet.rows.isNotEmpty ? sheet.rows.first : <Data?>[];
          final idCol = _findColumnIndex(headerRow, 'ProfileIdentifier');
          final nameCol = _findColumnIndex(headerRow, 'ProfileName');

          if (!hasProfileCols || idCol == null || nameCol == null) {
            // Old-format file without profile columns — import into active profile
            importedRows = await _importSheet(
              sheetName,
              sheet,
              customIconPathMap,
            );
          } else {
            // Group rows by profile
            final grouped = <String, List<int>>{};
            for (int i = 1; i < sheet.rows.length; i++) {
              final row = sheet.rows[i];
              if (_isRowEmpty(row)) continue;
              final id = _asString(_cellValue(row, idCol));
              final nm = _asString(_cellValue(row, nameCol));
              final key = '$id|||$nm';
              grouped.putIfAbsent(key, () => []).add(i);
            }

            for (final entry in grouped.entries) {
              final profileId = resolvedProfiles[entry.key]
                ?? await _profileService.getActiveProfileId(); // fallback;
              if (profileId == null) continue; // skip — no access

              firestoreService.setImportOverride(profileId);
              try {
                importedRows += await _importSheetRows(
                  sheetName,
                  sheet,
                  entry.value,
                  customIconPathMap,
                );
              } finally {
                firestoreService.setImportOverride(null);
              }
            }
          }
        }
      }

      stats.add(ImportStat(
        name: sheetName,
        totalRows: dataRows,
        importedRows: importedRows,
      ));
    }

    try {
      return ImportResult(_sortStatsForDisplay(stats));
    } finally {
      _importEnsuredCategoryKeys.clear();
      _importEnsuredAccountKeys.clear();
    }
  }

  /// Import all data rows of a sheet into the currently active profile (legacy path).
  static Future<int> _importSheet(
    String sheetName,
    Sheet sheet,
    Map<String, String> customIconPathMap,
  ) async {
    final allRows =
        List.generate(sheet.rows.length - 1, (i) => i + 1);
    return _importSheetRows(sheetName, sheet, allRows, customIconPathMap);
  }

  /// Import specific row indices from a sheet.
  static Future<int> _importSheetRows(
    String sheetName,
    Sheet sheet,
    List<int> rowIndices,
    Map<String, String> customIconPathMap,
  ) async {
    switch (sheetName) {
      case _recordsSheet:
        return _importRecordRows(sheet, rowIndices, customIconPathMap);
      case _budgetsSheet:
        return _importBudgetRows(sheet, rowIndices);
      case _accountsSheet:
        return _importAccountRows(sheet, rowIndices, customIconPathMap);
      case _categoriesSheet:
        return _importCategoryRows(sheet, rowIndices, customIconPathMap);
      default:
        return 0;
    }
  }

  static Future<int> _importRecordRows(
    Sheet sheet,
    List<int> rowIndices,
    Map<String, String> customIconPathMap,
  ) async {
    int importedRows = 0;
    for (final i in rowIndices) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      final category = _asString(_cellValue(row, 1));
      final amount = _asDouble(_cellValue(row, 2));
      final dateText = _asString(_cellValue(row, 3));
      final type = _normalizeType(_asString(_cellValue(row, 4)));
      final account = _asString(_cellValue(row, 5));
      final comment = _asString(_cellValue(row, 6));

      if (category.isEmpty || amount == null || dateText.isEmpty) continue;

      final parsedDate = DateTime.tryParse(dateText);
      final normalizedDate = parsedDate ?? DateTime.now();

      await _ensureDataServiceCategoryExists(category, type);
      if (account.isNotEmpty) {
        await _ensureDataServiceAccountExists(account, type);
      }

      try {
        await DataService.insertTransaction(
          category,
          amount,
          normalizedDate,
          type,
          account,
          comment,
        );
        importedRows++;
      } catch (_) {}
    }
    return importedRows;
  }

  static Future<int> _importBudgetRows(
    Sheet sheet,
    List<int> rowIndices,
  ) async {
    int importedRows = 0;
    for (final i in rowIndices) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;
      final category = _asString(_cellValue(row, 1));
      final amount = _asDouble(_cellValue(row, 2));
      final month = _asInt(_cellValue(row, 3));
      final year = _asInt(_cellValue(row, 4));
      final type =
          _normalizeType(_asString(_cellValue(row, 5)), fallback: 'expense');
      if (category.isEmpty ||
          amount == null ||
          month == null ||
          year == null) continue;

      await _ensureDataServiceCategoryExists(category, type);
      try {
        await DataService.insertBudget(category, amount, month, year);
        importedRows++;
      } catch (_) {}
    }
    return importedRows;
  }

  static Future<int> _importAccountRows(
    Sheet sheet,
    List<int> rowIndices,
    Map<String, String> customIconPathMap,
  ) async {
    int importedRows = 0;
    for (final i in rowIndices) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;
      final iconPath = _resolveImportedIconPath(
          _asString(_cellValue(row, 4)), customIconPathMap);
      if (name.isEmpty) continue;

      final exists = await DataService.accountExists(name, type);
      if (!exists) {
        try {
          await DataService.insertAccount(
            name,
            type,
            icon,
            iconPath: iconPath.isEmpty ? null : iconPath,
          );
        } catch (_) {}
      }
      importedRows++;
    }
    return importedRows;
  }

  static Future<int> _importCategoryRows(
    Sheet sheet,
    List<int> rowIndices,
    Map<String, String> customIconPathMap,
  ) async {
    int importedRows = 0;
    for (final i in rowIndices) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;
      final name = _asString(_cellValue(row, 1));
      final type = _normalizeType(_asString(_cellValue(row, 2)));
      final icon = _asInt(_cellValue(row, 3)) ?? 0;
      final iconPath = _resolveImportedIconPath(
          _asString(_cellValue(row, 4)), customIconPathMap);
      if (name.isEmpty) continue;

      final exists = await DataService.categoryExists(name, type);
      if (!exists) {
        try {
          await DataService.insertCategory(
            name,
            type,
            icon,
            iconPath: iconPath.isEmpty ? null : iconPath,
          );
        } catch (_) {}
      }
      importedRows++;
    }
    return importedRows;
  }

  static Future<void> _ensureDataServiceCategoryExists(
    String name,
    String type,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final key = '${type.trim().toLowerCase()}::${normalizedName.toLowerCase()}';
    if (_importEnsuredCategoryKeys.contains(key)) return;
    try {
      final exists = await DataService.categoryExists(normalizedName, type);
      if (!exists) {
        await DataService.insertCategory(normalizedName, type, 0);
      }
      _importEnsuredCategoryKeys.add(key);
    } catch (_) {}
  }

  static Future<void> _ensureDataServiceAccountExists(
    String name,
    String type,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final key = '${type.trim().toLowerCase()}::${normalizedName.toLowerCase()}';
    if (_importEnsuredAccountKeys.contains(key)) return;
    try {
      final exists = await DataService.accountExists(normalizedName, type);
      if (!exists) {
        await DataService.insertAccount(normalizedName, type, 0);
      }
      _importEnsuredAccountKeys.add(key);
    } catch (_) {}
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

  static Data? _cellValue(List<Data?> row, int index) =>
      index >= row.length ? null : row[index];

  /// Finds the column index (0-based) of a header by name. Returns null if not found.
  static int? _findColumnIndex(List<Data?> headerRow, String name) {
    for (int i = 0; i < headerRow.length; i++) {
      if (_asString(headerRow[i]).toLowerCase() == name.toLowerCase()) {
        return i;
      }
    }
    return null;
  }

  static bool _isRowEmpty(List<Data?> row) =>
      row.every((cell) => _asString(cell).isEmpty);
  static String _asString(Data? cell) =>
      cell == null || cell.value == null ? '' : cell.value.toString().trim();
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

  static String _resolveImportedIconPath(
    String source,
    Map<String, String> customIconPathMap,
  ) {
    if (source.isEmpty) return '';
    final byExactPath = customIconPathMap[source];
    if (byExactPath != null) return byExactPath;
    final fileName = p.basename(source);
    if (fileName.isEmpty) return source;
    final byFileName = customIconPathMap[fileName];
    return byFileName ?? source;
  }

  static Future<List<_CustomIconPayload>> _collectCustomIconsPayloads(
    List<Map<String, dynamic>> rows,
  ) async {
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

      final extension = p.extension(fileNameFromSheet).isEmpty
          ? '.png'
          : p.extension(fileNameFromSheet);
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

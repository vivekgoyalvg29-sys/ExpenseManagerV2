import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../models.dart';
import 'data_store.dart';
import 'database_service.dart' show DatabaseService, RecurringResolvedRow;
import 'firestore_service.dart';
import 'profile_service.dart';

/// DataService is the single access point for all data operations.
///
/// **Signed out:** SQLite is the source of truth (private on-device profile).
/// **Signed in:** Firestore first → SQLite cache in background (existing behavior).
class DataService {
  static final DataService _instance = DataService._();

  DataService._();

  final FirestoreService _fs = FirestoreService();

  /// SQLite is primary for unsigned users, local profile ids, and cloud profiles
  /// marked "local only" after the owner turned off sharing (Firestore data wiped).
  static bool get _localPrimary {
    if (!AppConfig.firebaseCloudEnabled) return true;
    if (FirebaseAuth.instance.currentUser == null) return true;
    final id = ProfileService().cachedActiveProfileId;
    if (id == null || id.isEmpty) return true;
    if (ProfileService.isLocalProfileId(id)) return true;
    return ProfileService().usesSqlitePrimaryForCloudProfile(id);
  }

  // ============ Streams ============

  static Stream<List<ProfileModel>> get profilesStream =>
      ProfileService().getMyProfiles();

  static Stream<bool> get isOnline {
    final ctrl = StreamController<bool>.broadcast();
    ctrl.add(true);
    return ctrl.stream;
  }

  // ============ Helpers ============

  /// Fire-and-forget SQLite cache update — errors are silently swallowed.
  static void _cacheAsync(Future<void> Function() op) {
    () async {
      try {
        await op();
      } catch (_) {}
    }();
  }

  static int _idCounter = 0;

  static int _newLocalId() =>
      DateTime.now().microsecondsSinceEpoch + (_idCounter++);

  // ============ TRANSACTIONS ============

  static Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    bool preferServer = false,
  }) async {
    if (_localPrimary) {
      return DatabaseService.getTransactions(
        startDate: startDate,
        endDate: endDate,
      );
    }
    final getOptions = preferServer
        ? const GetOptions(source: Source.server)
        : const GetOptions();
    return _instance._fs.getTransactions(
      startDate: startDate,
      endDate: endDate,
      getOptions: getOptions,
    );
  }

  static Future<void> insertTransaction(
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    if (_localPrimary) {
      await DatabaseService.insertTransaction(
        title,
        amount,
        date,
        type,
        account,
        comment,
      );
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    final id = _newLocalId();
    await _instance._fs
        .insertTransaction(id, title, amount, date, type, account, comment);
    _cacheAsync(() => DatabaseService.insertTransactionRaw(
        id, title, amount, date, type, account, comment));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> updateTransaction(
    int id,
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    if (_localPrimary) {
      await DatabaseService.updateTransaction(
        id,
        title,
        amount,
        date,
        type,
        account,
        comment,
      );
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs
        .updateTransaction(id, title, amount, date, type, account, comment);
    _cacheAsync(() => DatabaseService.updateTransaction(
        id, title, amount, date, type, account, comment));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> deleteTransaction(int id) async {
    if (_localPrimary) {
      await DatabaseService.deleteTransaction(id);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteTransaction(id);
    _cacheAsync(() => DatabaseService.deleteTransaction(id));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> deleteAllTransactions() async {
    if (_localPrimary) {
      await DatabaseService.deleteAllTransactions();
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteAllTransactions();
    try {
      await DatabaseService.deleteAllTransactions();
    } catch (_) {}
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<List<String>> getExistingComments() async {
    if (_localPrimary) {
      return DatabaseService.getExistingComments();
    }
    return _instance._fs.getExistingComments();
  }

  // ============ ACCOUNTS ============

  static Future<List<Map<String, dynamic>>> getAccounts({
    bool preferServer = false,
  }) async {
    if (_localPrimary) return DatabaseService.getAccounts();
    final getOptions = preferServer
        ? const GetOptions(source: Source.server)
        : const GetOptions();
    return _instance._fs.getAccounts(getOptions: getOptions);
  }

  static Future<void> insertAccount(
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    if (_localPrimary) {
      await DatabaseService.insertAccount(name, type, icon, iconPath: iconPath);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    final id = _newLocalId();
    await _instance._fs.insertAccount(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(
        () => DatabaseService.insertAccountRaw(id, name, type, icon, iconPath: iconPath));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> updateAccount(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    if (_localPrimary) {
      await DatabaseService.updateAccount(id, name, type, icon, iconPath: iconPath);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.updateAccount(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(
        () => DatabaseService.updateAccount(id, name, type, icon, iconPath: iconPath));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> deleteAccount(int id) async {
    if (_localPrimary) {
      await DatabaseService.deleteAccount(id);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteAccount(id);
    _cacheAsync(() => DatabaseService.deleteAccount(id));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> setAccountFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    if (_localPrimary) {
      await DatabaseService.setAccountFavorite(
        id: id,
        type: type,
        isFavorite: isFavorite,
      );
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs
        .setAccountFavorite(id: id, type: type, isFavorite: isFavorite);
    _cacheAsync(() =>
        DatabaseService.setAccountFavorite(id: id, type: type, isFavorite: isFavorite));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<String?> getFavoriteAccountName(String type) async {
    if (_localPrimary) {
      return DatabaseService.getFavoriteAccountName(type);
    }
    return _instance._fs.getFavoriteAccountName(type);
  }

  // ============ CATEGORIES ============

  static Future<List<Map<String, dynamic>>> getCategories({
    bool preferServer = false,
  }) async {
    if (_localPrimary) return DatabaseService.getCategories();
    final getOptions = preferServer
        ? const GetOptions(source: Source.server)
        : const GetOptions();
    return _instance._fs.getCategories(getOptions: getOptions);
  }

  static Future<void> insertCategory(
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    if (_localPrimary) {
      await DatabaseService.insertCategory(name, type, icon, iconPath: iconPath);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    final id = _newLocalId();
    await _instance._fs
        .insertCategory(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(() =>
        DatabaseService.insertCategoryRaw(id, name, type, icon, iconPath: iconPath));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> updateCategory(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    if (_localPrimary) {
      await DatabaseService.updateCategory(id, name, type, icon, iconPath: iconPath);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs
        .updateCategory(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(() =>
        DatabaseService.updateCategory(id, name, type, icon, iconPath: iconPath));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> deleteCategory(int id) async {
    if (_localPrimary) {
      await DatabaseService.deleteCategory(id);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteCategory(id);
    _cacheAsync(() => DatabaseService.deleteCategory(id));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> setCategoryFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    if (_localPrimary) {
      await DatabaseService.setCategoryFavorite(
        id: id,
        type: type,
        isFavorite: isFavorite,
      );
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs
        .setCategoryFavorite(id: id, type: type, isFavorite: isFavorite);
    _cacheAsync(() =>
        DatabaseService.setCategoryFavorite(id: id, type: type, isFavorite: isFavorite));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<String?> getFavoriteCategoryName(String type) async {
    if (_localPrimary) {
      return DatabaseService.getFavoriteCategoryName(type);
    }
    return _instance._fs.getFavoriteCategoryName(type);
  }

  // ============ BUDGETS ============

  static Future<List<Map<String, dynamic>>> getBudgets({
    bool preferServer = false,
  }) async {
    if (_localPrimary) return DatabaseService.getBudgets();
    final getOptions = preferServer
        ? const GetOptions(source: Source.server)
        : const GetOptions();
    return _instance._fs.getBudgets(getOptions: getOptions);
  }

  static Future<void> insertBudget(
    String category,
    double amount,
    int month,
    int year,
  ) async {
    if (_localPrimary) {
      await DatabaseService.insertBudget(category, amount, month, year);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    final id = _newLocalId();
    await _instance._fs.insertBudget(id, category, amount, month, year);
    _cacheAsync(
        () => DatabaseService.insertBudgetRaw(id, category, amount, month, year));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> updateBudget(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    if (_localPrimary) {
      await DatabaseService.updateBudget(id, category, amount, month, year);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.updateBudget(id, category, amount, month, year);
    _cacheAsync(
        () => DatabaseService.updateBudget(id, category, amount, month, year));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<void> deleteBudget(int id) async {
    if (_localPrimary) {
      await DatabaseService.deleteBudget(id);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteBudget(id);
    _cacheAsync(() => DatabaseService.deleteBudget(id));
    DataStore.bumpTransactionMutationGeneration();
  }

  static Map<String, dynamic>? _budgetRowFor(
    List<Map<String, dynamic>> all,
    String category,
    int month,
    int year,
  ) {
    for (final b in all) {
      if ((b['category'] as String?) == category &&
          (b['month'] as num?)?.toInt() == month &&
          (b['year'] as num?)?.toInt() == year) {
        return b;
      }
    }
    return null;
  }

  /// Smart Budget Copy: duplicate expense category amounts from [fromMonth] into each
  /// month in [toMonths] (overwriting existing rows for same category + month).
  static Future<void> smartBudgetCopy({
    required DateTime fromMonth,
    required List<String> categories,
    required List<DateTime> toMonths,
  }) async {
    final all = await getBudgets();
    final fy = fromMonth.year;
    final fm = fromMonth.month;

    final sqliteOps = <({
      bool isUpdate,
      int? rowId,
      String category,
      double amount,
      int month,
      int year,
    })>[];

    final fsOps = <({
      bool isUpdate,
      int localId,
      String category,
      int categoryId,
      double amount,
      int month,
      int year,
    })>[];

    if (_localPrimary) {
      for (final cat in categories) {
        final source = _budgetRowFor(all, cat, fm, fy);
        if (source == null) continue;
        final amount = (source['amount'] as num).toDouble();
        for (final dest in toMonths) {
          final dy = dest.year;
          final dm = dest.month;
          final existing = _budgetRowFor(all, cat, dm, dy);
          if (existing != null) {
            sqliteOps.add((
              isUpdate: true,
              rowId: existing['id'] as int,
              category: cat,
              amount: amount,
              month: dm,
              year: dy,
            ));
          } else {
            sqliteOps.add((
              isUpdate: false,
              rowId: null,
              category: cat,
              amount: amount,
              month: dm,
              year: dy,
            ));
          }
        }
      }
      await DatabaseService.applyBudgetCopyOperations(sqliteOps);
      DataStore.bumpTransactionMutationGeneration();
      return;
    }

    final categoryIds = <String, int>{};
    for (final cat in categories) {
      final cid = await _instance._fs.expenseCategoryIdByName(cat);
      if (cid == null) {
        throw Exception('Category not found: $cat');
      }
      categoryIds[cat] = cid;
    }

    for (final cat in categories) {
      final source = _budgetRowFor(all, cat, fm, fy);
      if (source == null) continue;
      final amount = (source['amount'] as num).toDouble();
      final cid = categoryIds[cat]!;
      for (final dest in toMonths) {
        final dy = dest.year;
        final dm = dest.month;
        final existing = _budgetRowFor(all, cat, dm, dy);
        if (existing != null) {
          fsOps.add((
            isUpdate: true,
            localId: existing['id'] as int,
            category: cat,
            categoryId: cid,
            amount: amount,
            month: dm,
            year: dy,
          ));
        } else {
          fsOps.add((
            isUpdate: false,
            localId: _newLocalId(),
            category: cat,
            categoryId: cid,
            amount: amount,
            month: dm,
            year: dy,
          ));
        }
      }
    }

    await _instance._fs.batchApplyBudgetCopies(fsOps);
    for (final op in fsOps) {
      if (op.isUpdate) {
        _cacheAsync(
          () => DatabaseService.updateBudget(
            op.localId,
            op.category,
            op.amount,
            op.month,
            op.year,
          ),
        );
      } else {
        _cacheAsync(
          () => DatabaseService.insertBudgetRaw(
            op.localId,
            op.category,
            op.amount,
            op.month,
            op.year,
          ),
        );
      }
    }
    DataStore.bumpTransactionMutationGeneration();
  }

  // ============ MISC ============

  static Future<void> deleteAllData() async {
    if (_localPrimary) {
      try {
        await DatabaseService.deleteAllData();
      } catch (_) {}
      DataStore.bumpTransactionMutationGeneration();
      return;
    }
    await _instance._fs.deleteAllData();
    try {
      await DatabaseService.deleteAllData();
    } catch (_) {}
    DataStore.bumpTransactionMutationGeneration();
  }

  static Future<bool> accountExists(String name, String type) async {
    if (_localPrimary) {
      return DatabaseService.accountExists(name, type);
    }
    return _instance._fs.accountExists(name, type);
  }

  static Future<bool> categoryExists(String name, String type) async {
    if (_localPrimary) {
      return DatabaseService.categoryExists(name, type);
    }
    return _instance._fs.categoryExists(name, type);
  }

  static Future<int> initializeDefaultCategoriesAndAccounts() async {
    final created = _localPrimary
        ? await DatabaseService.initializeDefaultCategoriesAndAccounts()
        : await _instance._fs.initializeDefaultCategoriesAndAccounts();
    DataStore.bumpTransactionMutationGeneration();
    return created;
  }

  static Future<int> initializeDefaultCategoriesAndAccountsForProfile(
      String profileId) async {
    int created;
    if (_localPrimary ||
        profileId == ProfileService.localPrivateProfileId) {
      created = await DatabaseService.initializeDefaultCategoriesAndAccounts();
    } else {
      _instance._fs.setImportOverride(profileId);
      try {
        created = await _instance._fs.initializeDefaultCategoriesAndAccounts();
      } finally {
        _instance._fs.setImportOverride(null);
      }
    }
    DataStore.bumpTransactionMutationGeneration();
    return created;
  }

  // ============ RECURRING EXPENSE MASTERS ============

  static Future<List<Map<String, dynamic>>> getRecurringMasters() async {
    if (_localPrimary) return DatabaseService.getRecurringMasters();
    return _instance._fs.getRecurringMasters();
  }

  static Future<Map<String, RecurringResolvedRow>> getRecurringResolvedMap() async {
    if (_localPrimary) return DatabaseService.getAllRecurringResolvedDetailed();
    return _instance._fs.getAllRecurringResolvedDetailed();
  }

  static Future<int> insertRecurringMaster({
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required Map<String, dynamic> scheduleMap,
  }) async {
    final jsonStr = jsonEncode(scheduleMap);
    if (_localPrimary) {
      return DatabaseService.insertRecurringMaster(
        title: title,
        amount: amount,
        type: type,
        account: account,
        comment: comment,
        scheduleKind: scheduleKind,
        scheduleJson: jsonStr,
      );
    }
    final id = _newLocalId();
    final createdMs = DateTime.now().millisecondsSinceEpoch;
    await _instance._fs.insertRecurringMaster(
      localId: id,
      title: title,
      amount: amount,
      type: type,
      account: account,
      comment: comment,
      scheduleKind: scheduleKind,
      scheduleMap: scheduleMap,
      createdAtMs: createdMs,
    );
    return id;
  }

  static Future<void> updateRecurringMaster({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required Map<String, dynamic> scheduleMap,
  }) async {
    final jsonStr = jsonEncode(scheduleMap);
    if (_localPrimary) {
      await DatabaseService.updateRecurringMaster(
        id: id,
        title: title,
        amount: amount,
        type: type,
        account: account,
        comment: comment,
        scheduleKind: scheduleKind,
        scheduleJson: jsonStr,
      );
      return;
    }
    await _instance._fs.updateRecurringMaster(
      id: id,
      title: title,
      amount: amount,
      type: type,
      account: account,
      comment: comment,
      scheduleKind: scheduleKind,
      scheduleMap: scheduleMap,
    );
  }

  static Future<void> deleteRecurringMaster(int id) async {
    if (_localPrimary) {
      await DatabaseService.deleteRecurringMaster(id);
      return;
    }
    await _instance._fs.deleteRecurringMaster(id);
  }

  static Future<void> deleteRecurringMastersMany(Iterable<int> ids) async {
    if (_localPrimary) {
      await DatabaseService.deleteRecurringMastersMany(ids);
      return;
    }
    for (final id in ids) {
      await _instance._fs.deleteRecurringMaster(id);
    }
  }

  static Future<void> putRecurringResolved({
    required int masterId,
    required String scheduledDateIso,
    required String status,
    String? deferUntilIso,
  }) async {
    if (_localPrimary) {
      await DatabaseService.putRecurringResolved(
        masterId: masterId,
        scheduledDateIso: scheduledDateIso,
        status: status,
        deferUntilIso: deferUntilIso,
      );
      return;
    }
    await _instance._fs.putRecurringResolved(
      masterLocalId: masterId,
      scheduledDateIso: scheduledDateIso,
      status: status,
      deferUntilIso: deferUntilIso,
    );
  }
}

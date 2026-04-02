import 'dart:async';

import '../models.dart';
import 'database_service.dart';
import 'firestore_service.dart';
import 'profile_service.dart';

/// DataService is the single access point for all data operations.
///
/// Write path  : Firestore first → SQLite cache in background (fire-and-forget).
/// Read path   : Firestore directly. Firestore's offline persistence handles
///               caching transparently — no timeout-based SQLite fallback needed.
class DataService {
  static final DataService _instance = DataService._();

  DataService._();

  final FirestoreService _fs = FirestoreService();
  final ProfileService _profile = ProfileService();

  // ============ Streams ============

  static Stream<List<ProfileModel>> get profilesStream =>
      _instance._profile.getMyProfiles();

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

  // Monotonically increasing local ID generator
  static int _idCounter = 0;

  static int _newLocalId() =>
      DateTime.now().microsecondsSinceEpoch + (_idCounter++);

  // ============ TRANSACTIONS ============

  static Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _instance._fs.getTransactions(startDate: startDate, endDate: endDate);

  static Future<void> insertTransaction(
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    final id = _newLocalId();
    await _instance._fs
        .insertTransaction(id, title, amount, date, type, account, comment);
    _cacheAsync(() => DatabaseService.insertTransactionRaw(
        id, title, amount, date, type, account, comment));
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
    await _instance._fs
        .updateTransaction(id, title, amount, date, type, account, comment);
    _cacheAsync(() => DatabaseService.updateTransaction(
        id, title, amount, date, type, account, comment));
  }

  static Future<void> deleteTransaction(int id) async {
    await _instance._fs.deleteTransaction(id);
    _cacheAsync(() => DatabaseService.deleteTransaction(id));
  }

  static Future<void> deleteAllTransactions() async {
    await _instance._fs.deleteAllTransactions();
    try {
      await DatabaseService.deleteAllTransactions();
    } catch (_) {}
  }

  static Future<List<String>> getExistingComments() =>
      _instance._fs.getExistingComments();

  // ============ ACCOUNTS ============

  static Future<List<Map<String, dynamic>>> getAccounts() =>
      _instance._fs.getAccounts();

  static Future<void> insertAccount(
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final id = _newLocalId();
    await _instance._fs.insertAccount(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(
        () => DatabaseService.insertAccountRaw(id, name, type, icon, iconPath: iconPath));
  }

  static Future<void> updateAccount(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    await _instance._fs.updateAccount(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(
        () => DatabaseService.updateAccount(id, name, type, icon, iconPath: iconPath));
  }

  static Future<void> deleteAccount(int id) async {
    await _instance._fs.deleteAccount(id);
    _cacheAsync(() => DatabaseService.deleteAccount(id));
  }

  static Future<void> setAccountFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    await _instance._fs
        .setAccountFavorite(id: id, type: type, isFavorite: isFavorite);
    _cacheAsync(() =>
        DatabaseService.setAccountFavorite(id: id, type: type, isFavorite: isFavorite));
  }

  static Future<String?> getFavoriteAccountName(String type) =>
      _instance._fs.getFavoriteAccountName(type);

  // ============ CATEGORIES ============

  static Future<List<Map<String, dynamic>>> getCategories() =>
      _instance._fs.getCategories();

  static Future<void> insertCategory(
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final id = _newLocalId();
    await _instance._fs
        .insertCategory(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(() =>
        DatabaseService.insertCategoryRaw(id, name, type, icon, iconPath: iconPath));
  }

  static Future<void> updateCategory(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    await _instance._fs
        .updateCategory(id, name, type, icon, iconPath: iconPath);
    _cacheAsync(() =>
        DatabaseService.updateCategory(id, name, type, icon, iconPath: iconPath));
  }

  static Future<void> deleteCategory(int id) async {
    await _instance._fs.deleteCategory(id);
    _cacheAsync(() => DatabaseService.deleteCategory(id));
  }

  static Future<void> setCategoryFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    await _instance._fs
        .setCategoryFavorite(id: id, type: type, isFavorite: isFavorite);
    _cacheAsync(() =>
        DatabaseService.setCategoryFavorite(id: id, type: type, isFavorite: isFavorite));
  }

  static Future<String?> getFavoriteCategoryName(String type) =>
      _instance._fs.getFavoriteCategoryName(type);

  // ============ BUDGETS ============

  static Future<List<Map<String, dynamic>>> getBudgets() =>
      _instance._fs.getBudgets();

  static Future<void> insertBudget(
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final id = _newLocalId();
    await _instance._fs.insertBudget(id, category, amount, month, year);
    _cacheAsync(
        () => DatabaseService.insertBudgetRaw(id, category, amount, month, year));
  }

  static Future<void> updateBudget(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    await _instance._fs.updateBudget(id, category, amount, month, year);
    _cacheAsync(
        () => DatabaseService.updateBudget(id, category, amount, month, year));
  }

  static Future<void> deleteBudget(int id) async {
    await _instance._fs.deleteBudget(id);
    _cacheAsync(() => DatabaseService.deleteBudget(id));
  }

  // ============ MISC ============

  static Future<void> deleteAllData() async {
    await _instance._fs.deleteAllData();
    try {
      await DatabaseService.deleteAllData();
    } catch (_) {}
  }

  static Future<bool> accountExists(String name, String type) =>
      _instance._fs.accountExists(name, type);

  static Future<bool> categoryExists(String name, String type) =>
      _instance._fs.categoryExists(name, type);

  static Future<int> initializeDefaultCategoriesAndAccounts() =>
      _instance._fs.initializeDefaultCategoriesAndAccounts();
}

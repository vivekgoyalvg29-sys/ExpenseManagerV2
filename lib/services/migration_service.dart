import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'firestore_service.dart';
import 'profile_service.dart';

class MigrationService {
  static const String _migratedKey = 'firestore_migrated';

  /// Returns true if the local SQLite data has already been migrated.
  Future<bool> hasMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migratedKey) ?? false;
  }

  /// Marks migration as complete without uploading any data.
  /// Use when there is no local data worth migrating (e.g. fresh install).
  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migratedKey, true);
  }

  /// Migrates all local SQLite data to Firestore.
  /// Creates a default "My Profile" and uploads all data to it.
  /// On failure, does NOT mark as migrated so it retries on next launch.
  Future<void> migrateLocalDataToFirestore() async {
    if (await hasMigrated()) return;

    try {
      final profileService = ProfileService();
      final firestoreService = FirestoreService();

      // Read all local SQLite data
      final transactions = await DatabaseService.getTransactions();
      final budgets = await DatabaseService.getBudgets();
      final categories = await DatabaseService.getCategories();
      final accounts = await DatabaseService.getAccounts();

      // Create the default profile (also sets it as active)
      await profileService.createProfile('My Profile');

      int idOffset = 0;

      // Upload categories
      for (final cat in categories) {
        final localId =
            DateTime.now().microsecondsSinceEpoch + idOffset++;
        await firestoreService.insertCategory(
          localId,
          cat['name']?.toString() ?? '',
          cat['type']?.toString() ?? 'expense',
          (cat['icon'] as num?)?.toInt() ?? 0,
          iconPath: cat['icon_path']?.toString(),
        );
      }

      // Upload accounts
      for (final acc in accounts) {
        final localId =
            DateTime.now().microsecondsSinceEpoch + idOffset++;
        await firestoreService.insertAccount(
          localId,
          acc['name']?.toString() ?? '',
          acc['type']?.toString() ?? 'expense',
          (acc['icon'] as num?)?.toInt() ?? 0,
          iconPath: acc['icon_path']?.toString(),
        );
      }

      // Upload budgets
      for (final budget in budgets) {
        final localId =
            DateTime.now().microsecondsSinceEpoch + idOffset++;
        await firestoreService.insertBudget(
          localId,
          budget['category']?.toString() ?? '',
          (budget['amount'] as num?)?.toDouble() ?? 0.0,
          (budget['month'] as num?)?.toInt() ?? 1,
          (budget['year'] as num?)?.toInt() ?? DateTime.now().year,
        );
      }

      // Upload transactions
      for (final tx in transactions) {
        final localId =
            DateTime.now().microsecondsSinceEpoch + idOffset++;
        final date =
            DateTime.tryParse(tx['date']?.toString() ?? '') ??
                DateTime.now();
        await firestoreService.insertTransaction(
          localId,
          tx['title']?.toString() ?? '',
          (tx['amount'] as num?)?.toDouble() ?? 0.0,
          date,
          tx['type']?.toString() ?? 'expense',
          tx['account']?.toString() ?? '',
          tx['comment']?.toString() ?? '',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migratedKey, true);
    } catch (e) {
      // Do not mark as migrated — will retry on next launch
      rethrow;
    }
  }
}

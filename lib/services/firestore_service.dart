import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._();

  factory FirestoreService() => _instance;

  FirestoreService._();

  static const String _activeProfileKey = 'active_profile_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory localId → docId caches (reset when profile changes)
  final Map<int, String> _txDocIds = {};
  final Map<int, String> _accountDocIds = {};
  final Map<int, String> _categoryDocIds = {};
  final Map<int, String> _budgetDocIds = {};

  /// When set, overrides SharedPreferences for the active profile ID.
  /// Used during multi-profile import to route rows to different profiles.
  String? _importProfileOverride;

  String get _currentPhone => _auth.currentUser?.phoneNumber ?? '';

  /// Sets a temporary profile ID override for import operations.
  /// Pass null to clear the override.
  void setImportOverride(String? profileId) {
    _importProfileOverride = profileId;
    clearCaches();
  }

  Future<String?> _getActiveProfileId() async {
    if (_importProfileOverride != null) return _importProfileOverride;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  Future<CollectionReference<Map<String, dynamic>>?> _col(String name) async {
    final profileId = await _getActiveProfileId();
    if (profileId == null) return null;
    return _firestore
        .collection('profiles')
        .doc(profileId)
        .collection(name);
  }

  Future<DocumentReference<Map<String, dynamic>>?> _profileRef() async {
    final profileId = await _getActiveProfileId();
    if (profileId == null) return null;
    return _firestore.collection('profiles').doc(profileId);
  }

  int _localIdFromDoc(Map<String, dynamic> data, String docId) {
    return (data['localId'] as num?)?.toInt() ?? docId.hashCode.abs();
  }

  void clearCaches() {
    _txDocIds.clear();
    _accountDocIds.clear();
    _categoryDocIds.clear();
    _budgetDocIds.clear();
  }

  // ============ TRANSACTIONS ============

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final col = await _col('transactions');
    if (col == null) throw Exception('No active profile');
    final snap = await col.orderBy('date', descending: true).get();
    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _txDocIds[localId] = doc.id;
      results.add({
        'id': localId,
        'title': data['title'] ?? '',
        'amount': data['amount'] ?? 0.0,
        'date': data['date'] ?? DateTime.now().toIso8601String(),
        'type': data['type'] ?? 'expense',
        'account': data['account'] ?? '',
        'comment': data['comment'] ?? '',
      });
    }
    return results;
  }

  Future<void> insertTransaction(
    int localId,
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    final col = await _col('transactions');
    if (col == null) return;
    final ref = await col.add({
      'localId': localId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'comment': comment,
      'createdBy': _currentPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _txDocIds[localId] = ref.id;
  }

  Future<void> updateTransaction(
    int id,
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    final col = await _col('transactions');
    if (col == null) return;
    final docId = await _resolveDocId(col, _txDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'comment': comment,
    });
  }

  Future<void> deleteTransaction(int id) async {
    final col = await _col('transactions');
    if (col == null) return;
    final docId = await _resolveDocId(col, _txDocIds, id);
    if (docId != null) {
      await col.doc(docId).delete();
      _txDocIds.remove(id);
    }
  }

  Future<void> deleteAllTransactions() async {
    await _deleteAllInCollection('transactions');
    _txDocIds.clear();
  }

  Future<List<String>> getExistingComments() async {
    final col = await _col('transactions');
    if (col == null) throw Exception('No active profile');
    final snap = await col.orderBy('createdAt', descending: true).get();
    final seen = <String>{};
    final comments = <String>[];
    for (final doc in snap.docs) {
      final comment = (doc.data()['comment'] ?? '').toString().trim();
      if (comment.isEmpty) continue;
      final key = comment.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      comments.add(comment);
    }
    return comments;
  }

  // ============ ACCOUNTS ============

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final col = await _col('accounts');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get();
    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _accountDocIds[localId] = doc.id;
      results.add({
        'id': localId,
        'name': data['name'] ?? '',
        'type': data['type'] ?? 'expense',
        'icon': (data['icon'] as num?)?.toInt() ?? 0,
        'icon_path': data['icon_path']?.toString(),
        'is_favorite': (data['is_favorite'] as num?)?.toInt() ?? 0,
      });
    }
    return results;
  }

  Future<void> insertAccount(
    int localId,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final col = await _col('accounts');
    if (col == null) return;
    final ref = await col.add({
      'localId': localId,
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
      'is_favorite': 0,
      'createdBy': _currentPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _accountDocIds[localId] = ref.id;
  }

  Future<void> updateAccount(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final col = await _col('accounts');
    if (col == null) return;
    final docId = await _resolveDocId(col, _accountDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    });
  }

  Future<void> deleteAccount(int id) async {
    final col = await _col('accounts');
    if (col == null) return;
    final docId = await _resolveDocId(col, _accountDocIds, id);
    if (docId != null) {
      await col.doc(docId).delete();
      _accountDocIds.remove(id);
    }
  }

  Future<void> setAccountFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    final col = await _col('accounts');
    if (col == null) return;

    if (isFavorite) {
      final snap = await col.where('type', isEqualTo: type).get();
      if (snap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'is_favorite': 0});
        }
        await batch.commit();
      }
    }

    final docId = await _resolveDocId(col, _accountDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({'is_favorite': isFavorite ? 1 : 0});
  }

  Future<String?> getFavoriteAccountName(String type) async {
    final col = await _col('accounts');
    if (col == null) throw Exception('No active profile');
    final snap = await col
        .where('type', isEqualTo: type)
        .where('is_favorite', isEqualTo: 1)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['name']?.toString();
  }

  // ============ CATEGORIES ============

  Future<List<Map<String, dynamic>>> getCategories() async {
    final col = await _col('categories');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get();
    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _categoryDocIds[localId] = doc.id;
      results.add({
        'id': localId,
        'name': data['name'] ?? '',
        'type': data['type'] ?? 'expense',
        'icon': (data['icon'] as num?)?.toInt() ?? 0,
        'icon_path': data['icon_path']?.toString(),
        'is_favorite': (data['is_favorite'] as num?)?.toInt() ?? 0,
      });
    }
    return results;
  }

  Future<void> insertCategory(
    int localId,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final col = await _col('categories');
    if (col == null) return;
    final ref = await col.add({
      'localId': localId,
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
      'is_favorite': 0,
      'createdBy': _currentPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _categoryDocIds[localId] = ref.id;
  }

  Future<void> updateCategory(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final col = await _col('categories');
    if (col == null) return;
    final docId = await _resolveDocId(col, _categoryDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    });
  }

  Future<void> deleteCategory(int id) async {
    final col = await _col('categories');
    if (col == null) return;
    final docId = await _resolveDocId(col, _categoryDocIds, id);
    if (docId != null) {
      await col.doc(docId).delete();
      _categoryDocIds.remove(id);
    }
  }

  Future<void> setCategoryFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    final col = await _col('categories');
    if (col == null) return;

    if (isFavorite) {
      final snap = await col.where('type', isEqualTo: type).get();
      if (snap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'is_favorite': 0});
        }
        await batch.commit();
      }
    }

    final docId = await _resolveDocId(col, _categoryDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({'is_favorite': isFavorite ? 1 : 0});
  }

  Future<String?> getFavoriteCategoryName(String type) async {
    final col = await _col('categories');
    if (col == null) throw Exception('No active profile');
    final snap = await col
        .where('type', isEqualTo: type)
        .where('is_favorite', isEqualTo: 1)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['name']?.toString();
  }

  // ============ BUDGETS ============

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final col = await _col('budgets');
    if (col == null) throw Exception('No active profile');
    final snap = await col.orderBy('year', descending: true).get();
    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _budgetDocIds[localId] = doc.id;
      results.add({
        'id': localId,
        'category': data['category'] ?? '',
        'amount': data['amount'] ?? 0.0,
        'month': (data['month'] as num?)?.toInt() ?? 1,
        'year': (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      });
    }
    return results;
  }

  Future<void> insertBudget(
    int localId,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final col = await _col('budgets');
    if (col == null) return;
    final ref = await col.add({
      'localId': localId,
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
      'createdBy': _currentPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _budgetDocIds[localId] = ref.id;
  }

  Future<void> updateBudget(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final col = await _col('budgets');
    if (col == null) return;
    final docId = await _resolveDocId(col, _budgetDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
    });
  }

  Future<void> deleteBudget(int id) async {
    final col = await _col('budgets');
    if (col == null) return;
    final docId = await _resolveDocId(col, _budgetDocIds, id);
    if (docId != null) {
      await col.doc(docId).delete();
      _budgetDocIds.remove(id);
    }
  }

  // ============ EXISTENCE CHECKS ============

  Future<bool> accountExists(String name, String type) async {
    final col = await _col('accounts');
    if (col == null) throw Exception('No active profile');
    final snap = await col.where('type', isEqualTo: type).get();
    return snap.docs.any((doc) =>
        doc.data()['name']?.toString().trim().toLowerCase() ==
        name.trim().toLowerCase());
  }

  Future<bool> categoryExists(String name, String type) async {
    final col = await _col('categories');
    if (col == null) throw Exception('No active profile');
    final snap = await col.where('type', isEqualTo: type).get();
    return snap.docs.any((doc) =>
        doc.data()['name']?.toString().trim().toLowerCase() ==
        name.trim().toLowerCase());
  }

  // ============ BULK OPERATIONS ============

  Future<void> deleteAllData() async {
    await Future.wait([
      _deleteAllInCollection('transactions'),
      _deleteAllInCollection('budgets'),
      _deleteAllInCollection('accounts'),
      _deleteAllInCollection('categories'),
    ]);
    clearCaches();
  }

  Future<int> initializeDefaultCategoriesAndAccounts() async {
    const incomeCategories = <String>[
      'Salary', 'Bonus', 'Freelance', 'Interest', 'Dividends',
      'Gifts', 'Reimbursements', 'Rental', 'Other',
    ];
    const expenseCategories = <String>[
      'Housing', 'Utilities', 'Groceries', 'Dining', 'Transport',
      'Health', 'Insurance', 'Education', 'Entertainment', 'Shopping',
      'Subscriptions', 'Debt', 'Savings', 'Donations', 'Misc',
    ];
    const accountNames = <String>['Cash', 'Bank', 'Savings', 'Credit Card', 'Wallet'];

    var created = 0;
    for (final name in incomeCategories) {
      if (await categoryExists(name, 'income')) continue;
      final id = DateTime.now().microsecondsSinceEpoch + created;
      await insertCategory(id, name, 'income', Icons.trending_up.codePoint);
      created++;
    }
    for (final name in expenseCategories) {
      if (await categoryExists(name, 'expense')) continue;
      final id = DateTime.now().microsecondsSinceEpoch + created;
      await insertCategory(id, name, 'expense', Icons.shopping_bag_outlined.codePoint);
      created++;
    }
    for (final name in accountNames) {
      for (final type in const ['income', 'expense']) {
        if (await accountExists(name, type)) continue;
        final id = DateTime.now().microsecondsSinceEpoch + created;
        await insertAccount(id, name, type, Icons.account_balance_wallet_outlined.codePoint);
        created++;
      }
    }
    return created;
  }

  // ============ PRIVATE HELPERS ============

  Future<String?> _resolveDocId(
    CollectionReference<Map<String, dynamic>> col,
    Map<int, String> cache,
    int localId,
  ) async {
    final cached = cache[localId];
    if (cached != null) return cached;
    final snap =
        await col.where('localId', isEqualTo: localId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final docId = snap.docs.first.id;
    cache[localId] = docId;
    return docId;
  }

  Future<void> _deleteAllInCollection(String collectionName) async {
    final ref = await _profileRef();
    if (ref == null) return;
    final col = ref.collection(collectionName);
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == 400);
  }
}

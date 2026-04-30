import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'default_seed_icons.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._();

  factory FirestoreService() => _instance;

  FirestoreService._();

  static const String _activeProfileKey = 'active_profile_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'krchabookdb',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory localId → docId caches (reset when profile changes)
  final Map<int, String> _txDocIds = {};
  final Map<int, String> _accountDocIds = {};
  final Map<int, String> _categoryDocIds = {};
  final Map<int, String> _budgetDocIds = {};
  final Map<int, String> _recurringMasterDocIds = {};

  /// When set, overrides SharedPreferences for the active profile ID.
  /// Used during multi-profile import to route rows to different profiles.
  String? _importProfileOverride;

  String get _actorUid => _auth.currentUser?.uid ?? '';

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

  String _norm(String? value) => (value ?? '').trim().toLowerCase();

  void clearCaches() {
    _txDocIds.clear();
    _accountDocIds.clear();
    _categoryDocIds.clear();
    _budgetDocIds.clear();
    _recurringMasterDocIds.clear();
  }

  // ============ TRANSACTIONS ============

  // Requires Firestore composite index on collection 'transactions', fields: date (Ascending).
  // Create in Firebase Console → Firestore → Indexes.
  Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    GetOptions getOptions = const GetOptions(),
  }) async {
    final col = await _col('transactions');
    if (col == null) throw Exception('No active profile');
    var query = col.orderBy('date', descending: true);
    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
    }
    final snap = await query.get(getOptions);
    final accountById = await _accountNameByLocalId();
    final categoryById = await _categoryNameByLocalId();

    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _txDocIds[localId] = doc.id;

      final originalTitle = (data['title'] ?? '').toString();
      final originalAccount = (data['account'] ?? '').toString();
      final type = (data['type'] ?? 'expense').toString();
      final categoryId = (data['categoryId'] as num?)?.toInt();
      final accountId = (data['accountId'] as num?)?.toInt();

      // Read-only display: prefer current category/account name when IDs exist (e.g. after rename cascade).
      // No write-back / migration on read.
      final displayTitle = categoryId != null
          ? (categoryById[categoryId] ?? originalTitle)
          : originalTitle;
      final displayAccount = accountId != null
          ? (accountById[accountId] ?? originalAccount)
          : originalAccount;

      results.add({
        'id': localId,
        'title': displayTitle,
        'amount': data['amount'] ?? 0.0,
        'date': data['date'] ?? DateTime.now().toIso8601String(),
        'type': type,
        'account': displayAccount,
        'comment': data['comment'] ?? '',
        'categoryId': categoryId,
        'accountId': accountId,
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
    final categoryId = await _categoryIdByNameAndType(title, type);
    final accountId = await _accountIdByNameAndType(account, type);
    final ref = await col.add({
      'localId': localId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'categoryId': categoryId,
      'accountId': accountId,
      'comment': comment,
      'createdBy': _actorUid,
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
    final categoryId = await _categoryIdByNameAndType(title, type);
    final accountId = await _accountIdByNameAndType(account, type);
    await col.doc(docId).update({
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'categoryId': categoryId,
      'accountId': accountId,
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

  Future<List<Map<String, dynamic>>> getAccounts({
    GetOptions getOptions = const GetOptions(),
  }) async {
    final col = await _col('accounts');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get(getOptions);
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
        // Raw value; [DataStore.replaceAccounts] normalizes bool/num/string.
        'is_favorite': data['is_favorite'],
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
      'createdBy': _actorUid,
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
    final oldSnap = await col.doc(docId).get();
    final oldName = oldSnap.data()?['name']?.toString() ?? '';
    await col.doc(docId).update({
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    });
    await _cascadeAccountUpdate(
      accountId: id,
      type: type,
      oldName: oldName,
      newName: name,
    );
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

    final docId = await _resolveDocId(col, _accountDocIds, id);
    if (docId == null) return;
    await col.doc(docId).update({'is_favorite': isFavorite ? 1 : 0});
  }

  Future<String?> getFavoriteAccountName(String type) async {
    final col = await _col('accounts');
    if (col == null) throw Exception('No active profile');
    final snap = await col.where('is_favorite', isEqualTo: 1).get();
    if (snap.docs.length != 1) return null;
    return snap.docs.first.data()['name']?.toString();
  }

  // ============ CATEGORIES ============

  Future<List<Map<String, dynamic>>> getCategories({
    GetOptions getOptions = const GetOptions(),
  }) async {
    final col = await _col('categories');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get(getOptions);
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
        'is_favorite': data['is_favorite'],
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
      'createdBy': _actorUid,
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
    final oldSnap = await col.doc(docId).get();
    final oldName = oldSnap.data()?['name']?.toString() ?? '';
    await col.doc(docId).update({
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    });
    await _cascadeCategoryUpdate(
      categoryId: id,
      type: type,
      oldName: oldName,
      newName: name,
    );
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
        .get();
    if (snap.docs.length != 1) return null;
    final names = snap.docs
        .map((d) => d.data()['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();
    return names.isEmpty ? null : names.first;
  }

  // ============ BUDGETS ============

  Future<List<Map<String, dynamic>>> getBudgets({
    GetOptions getOptions = const GetOptions(),
  }) async {
    final col = await _col('budgets');
    if (col == null) throw Exception('No active profile');
    final snap = await col.orderBy('year', descending: true).get(getOptions);
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
    final categoryId = await _categoryIdByNameAndType(category, 'expense');
    final ref = await col.add({
      'localId': localId,
      'category': category,
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
      'createdBy': _actorUid,
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
    final categoryId = await _categoryIdByNameAndType(category, 'expense');
    await col.doc(docId).update({
      'category': category,
      'categoryId': categoryId,
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

  /// Atomic multi-write for Smart Budget Copy (≤ ~500 ops per batch chunk).
  Future<void> batchApplyBudgetCopies(
    List<({
      bool isUpdate,
      int localId,
      String category,
      int categoryId,
      double amount,
      int month,
      int year,
    })> ops,
  ) async {
    final col = await _col('budgets');
    if (col == null) throw Exception('No active profile');
    await getBudgets();

    WriteBatch batch = _firestore.batch();
    var pending = 0;
    for (final op in ops) {
      if (op.isUpdate) {
        final docId = await _resolveDocId(col, _budgetDocIds, op.localId);
        if (docId == null) {
          throw StateError('Missing budget document for id ${op.localId}');
        }
        batch.update(col.doc(docId), {
          'category': op.category,
          'categoryId': op.categoryId,
          'amount': op.amount,
          'month': op.month,
          'year': op.year,
        });
      } else {
        final ref = col.doc();
        batch.set(ref, {
          'localId': op.localId,
          'category': op.category,
          'categoryId': op.categoryId,
          'amount': op.amount,
          'month': op.month,
          'year': op.year,
          'createdBy': _actorUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _budgetDocIds[op.localId] = ref.id;
      }
      pending++;
      if (pending >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        pending = 0;
      }
    }
    if (pending > 0) {
      await batch.commit();
    }
  }

  Future<int?> expenseCategoryIdByName(String name) =>
      _categoryIdByNameAndType(name, 'expense');

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
      _deleteAllInCollection('recurringMasters'),
      _deleteAllInCollection('recurringResolved'),
    ]);
    clearCaches();
  }

  // ============ RECURRING EXPENSE MASTERS ============

  Future<List<Map<String, dynamic>>> getRecurringMasters() async {
    final col = await _col('recurringMasters');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get();
    final out = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      _recurringMasterDocIds[localId] = doc.id;
      final sched = data['schedule'];
      String schedJson;
      if (sched is Map) {
        try {
          schedJson = jsonEncode(Map<String, dynamic>.from(
            sched.map((k, v) => MapEntry(k.toString(), v)),
          ));
        } catch (_) {
          schedJson = '{}';
        }
      } else {
        schedJson = data['scheduleJson']?.toString() ?? '{}';
      }
      out.add({
        'id': localId,
        'title': data['title']?.toString() ?? '',
        'amount': (data['amount'] as num?)?.toDouble() ?? 0,
        'type': data['type']?.toString() ?? 'expense',
        'account': data['account']?.toString() ?? '',
        'comment': data['comment']?.toString() ?? '',
        'schedule_kind': data['scheduleKind']?.toString() ?? '',
        'schedule_json': schedJson,
        'created_at_ms': (data['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      });
    }
    out.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return out;
  }

  Future<int> insertRecurringMaster({
    required int localId,
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required Map<String, dynamic> scheduleMap,
    required int createdAtMs,
  }) async {
    final col = await _col('recurringMasters');
    if (col == null) return localId;
    final ref = col.doc('rm_$localId');
    await ref.set({
      'localId': localId,
      'title': title,
      'amount': amount,
      'type': type,
      'account': account,
      'comment': comment,
      'scheduleKind': scheduleKind,
      'schedule': scheduleMap,
      'createdAtMs': createdAtMs,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _actorUid,
    });
    _recurringMasterDocIds[localId] = ref.id;
    return localId;
  }

  Future<void> updateRecurringMaster({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required Map<String, dynamic> scheduleMap,
  }) async {
    final col = await _col('recurringMasters');
    if (col == null) return;
    var docId = await _resolveDocId(col, _recurringMasterDocIds, id);
    docId ??= _recurringMasterDocIds[id] ?? 'rm_$id';
    await col.doc(docId).update({
      'title': title,
      'amount': amount,
      'type': type,
      'account': account,
      'comment': comment,
      'scheduleKind': scheduleKind,
      'schedule': scheduleMap,
    });
  }

  Future<void> deleteRecurringMaster(int id) async {
    final col = await _col('recurringMasters');
    if (col == null) return;
    var docId = await _resolveDocId(col, _recurringMasterDocIds, id);
    docId ??= 'rm_$id';
    await col.doc(docId).delete();
    _recurringMasterDocIds.remove(id);
    await _deleteResolvedForMaster(id);
  }

  Future<void> _deleteResolvedForMaster(int masterLocalId) async {
    final col = await _col('recurringResolved');
    if (col == null) return;
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await col.where('masterLocalId', isEqualTo: masterLocalId).limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == 400);
  }

  Future<Map<String, RecurringResolvedRow>> getAllRecurringResolvedDetailed() async {
    final col = await _col('recurringResolved');
    if (col == null) throw Exception('No active profile');
    final snap = await col.get();
    final out = <String, RecurringResolvedRow>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final mid = (data['masterLocalId'] as num?)?.toInt();
      final sd = data['scheduledDate']?.toString();
      final st = data['status']?.toString();
      if (mid != null && sd != null && st != null) {
        out['$mid|$sd'] = RecurringResolvedRow(
          status: st,
          deferUntilIso: data['deferUntil']?.toString(),
        );
      }
    }
    return out;
  }

  Future<void> putRecurringResolved({
    required int masterLocalId,
    required String scheduledDateIso,
    required String status,
    String? deferUntilIso,
  }) async {
    final col = await _col('recurringResolved');
    if (col == null) return;
    final safe = scheduledDateIso.replaceAll(RegExp(r'[^\d-]'), '');
    final payload = <String, dynamic>{
      'masterLocalId': masterLocalId,
      'scheduledDate': scheduledDateIso,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (deferUntilIso != null) {
      payload['deferUntil'] = deferUntilIso;
    } else {
      payload['deferUntil'] = FieldValue.delete();
    }
    await col.doc('${masterLocalId}_$safe').set(payload, SetOptions(merge: true));
  }

  Future<int> initializeDefaultCategoriesAndAccounts() async {
    const incomeCategories = <String>[
      'Salary',
      'Bonus',
      'Interest',
      'Rental',
    ];
    const expenseCategories = <String>[
      'Housing',
      'Utilities',
      'Groceries',
      'Dining',
      'Transport',
      'Health',
      'Insurance',
      'Education',
      'Entertainment',
      'Shopping',
      'Subscriptions',
      'EMIs',
      'Savings',
      'Donations',
    ];
    const accountNames = <String>['Cash', 'Savings', 'Credit Card', 'UPI'];

    var created = 0;
    for (final name in incomeCategories) {
      if (await categoryExists(name, 'income')) continue;
      final id = DateTime.now().microsecondsSinceEpoch + created;
      await insertCategory(
        id,
        name,
        'income',
        Icons.trending_up.codePoint,
        iconPath: DefaultSeedIcons.categoryIconPathFor(name, 'income'),
      );
      created++;
    }
    for (final name in expenseCategories) {
      if (await categoryExists(name, 'expense')) continue;
      final id = DateTime.now().microsecondsSinceEpoch + created;
      await insertCategory(
        id,
        name,
        'expense',
        Icons.shopping_bag_outlined.codePoint,
        iconPath: DefaultSeedIcons.categoryIconPathFor(name, 'expense'),
      );
      created++;
    }
    for (final name in accountNames) {
      if (await accountExists(name, 'expense')) continue;
      final id = DateTime.now().microsecondsSinceEpoch + created;
      await insertAccount(
        id,
        name,
        'expense',
        Icons.account_balance_wallet_outlined.codePoint,
        iconPath: DefaultSeedIcons.accountIconPathFor(name),
      );
      created++;
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

  /// Deletes all documents in `profiles/[profileId]/[collectionName]` in chunks.
  Future<void> wipeProfileSubcollection(
    String profileId,
    String collectionName,
  ) async {
    final col = _firestore
        .collection('profiles')
        .doc(profileId)
        .collection(collectionName);
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

  /// Wipes Firestore financial subcollections for [profileId], then uploads SQLite rows.
  /// Used when a cloud book becomes shareable again after local-only mode.
  Future<void> replaceCloudCollectionsFromSqlite(String profileId) async {
    setImportOverride(profileId);
    clearCaches();
    try {
      for (final name in const [
        'transactions',
        'budgets',
        'accounts',
        'categories',
      ]) {
        await wipeProfileSubcollection(profileId, name);
      }

      final categories = await DatabaseService.getCategories();
      for (final c in categories) {
        final id = (c['id'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch;
        await insertCategory(
          id,
          c['name']?.toString() ?? '',
          c['type']?.toString() ?? 'expense',
          (c['icon'] as num?)?.toInt() ?? 0,
          iconPath: c['icon_path']?.toString(),
        );
      }

      final accounts = await DatabaseService.getAccounts();
      for (final a in accounts) {
        final id = (a['id'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch;
        await insertAccount(
          id,
          a['name']?.toString() ?? '',
          a['type']?.toString() ?? 'expense',
          (a['icon'] as num?)?.toInt() ?? 0,
          iconPath: a['icon_path']?.toString(),
        );
      }

      final budgets = await DatabaseService.getBudgets();
      for (final b in budgets) {
        final id = (b['id'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch;
        await insertBudget(
          id,
          b['category']?.toString() ?? '',
          (b['amount'] as num?)?.toDouble() ?? 0,
          (b['month'] as num?)?.toInt() ?? 1,
          (b['year'] as num?)?.toInt() ?? DateTime.now().year,
        );
      }

      final transactions = await DatabaseService.getTransactions();
      for (final tx in transactions) {
        final id = (tx['id'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch;
        final date = DateTime.tryParse(tx['date']?.toString() ?? '') ??
            DateTime.now();
        await insertTransaction(
          id,
          tx['title']?.toString() ?? '',
          (tx['amount'] as num?)?.toDouble() ?? 0,
          date,
          tx['type']?.toString() ?? 'expense',
          tx['account']?.toString() ?? '',
          tx['comment']?.toString() ?? '',
        );
      }
    } finally {
      setImportOverride(null);
      clearCaches();
    }
  }

  Future<Map<int, String>> _accountNameByLocalId() async {
    final col = await _col('accounts');
    if (col == null) return {};
    final snap = await col.get();
    final map = <int, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      map[localId] = (data['name'] ?? '').toString();
    }
    return map;
  }

  Future<Map<int, String>> _categoryNameByLocalId() async {
    final col = await _col('categories');
    if (col == null) return {};
    final snap = await col.get();
    final map = <int, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      map[localId] = (data['name'] ?? '').toString();
    }
    return map;
  }

  Future<Map<String, int>> _accountLocalIdByName() async {
    final col = await _col('accounts');
    if (col == null) return {};
    final snap = await col.get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      final type = (data['type'] ?? 'expense').toString();
      final name = (data['name'] ?? '').toString();
      map[_norm('$type::$name')] = localId;
    }
    return map;
  }

  Future<Map<String, int>> _categoryLocalIdByName() async {
    final col = await _col('categories');
    if (col == null) return {};
    final snap = await col.get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = _localIdFromDoc(data, doc.id);
      final type = (data['type'] ?? 'expense').toString();
      final name = (data['name'] ?? '').toString();
      map[_norm('$type::$name')] = localId;
    }
    return map;
  }

  Future<int?> _accountIdByNameAndType(String name, String type) async {
    final lookup = await _accountLocalIdByName();
    return lookup[_norm('$type::$name')];
  }

  Future<int?> _categoryIdByNameAndType(String name, String type) async {
    final lookup = await _categoryLocalIdByName();
    return lookup[_norm('$type::$name')];
  }

  Future<void> _cascadeAccountUpdate({
    required int accountId,
    required String type,
    required String oldName,
    required String newName,
  }) async {
    final col = await _col('transactions');
    if (col == null) return;
    final snap = await col.get();
    WriteBatch batch = _firestore.batch();
    var writes = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final txType = (data['type'] ?? '').toString();
      final txAccountId = (data['accountId'] as num?)?.toInt();
      final txAccountName = (data['account'] ?? '').toString();
      final matchesById = txAccountId == accountId;
      final matchesByLegacyName = txAccountId == null &&
          txType == type &&
          _norm(txAccountName) == _norm(oldName);
      if (!matchesById && !matchesByLegacyName) continue;
      batch.update(doc.reference, {'account': newName, 'accountId': accountId});
      writes++;
      if (writes == 400) {
        await batch.commit();
        batch = _firestore.batch();
        writes = 0;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> _cascadeCategoryUpdate({
    required int categoryId,
    required String type,
    required String oldName,
    required String newName,
  }) async {
    final txCol = await _col('transactions');
    if (txCol != null) {
      final txSnap = await txCol.get();
      WriteBatch batch = _firestore.batch();
      var writes = 0;
      for (final doc in txSnap.docs) {
        final data = doc.data();
        final txType = (data['type'] ?? '').toString();
        final txCategoryId = (data['categoryId'] as num?)?.toInt();
        final txCategoryName = (data['title'] ?? '').toString();
        final matchesById = txCategoryId == categoryId;
        final matchesByLegacyName = txCategoryId == null &&
            txType == type &&
            _norm(txCategoryName) == _norm(oldName);
        if (!matchesById && !matchesByLegacyName) continue;
        batch.update(doc.reference, {'title': newName, 'categoryId': categoryId});
        writes++;
        if (writes == 400) {
          await batch.commit();
          batch = _firestore.batch();
          writes = 0;
        }
      }
      if (writes > 0) {
        await batch.commit();
      }
    }

    final budgetCol = await _col('budgets');
    if (budgetCol == null) return;
    final budgetSnap = await budgetCol.get();
    WriteBatch budgetBatch = _firestore.batch();
    var budgetWrites = 0;
    for (final doc in budgetSnap.docs) {
      final data = doc.data();
      final budgetCategoryId = (data['categoryId'] as num?)?.toInt();
      final budgetCategory = (data['category'] ?? '').toString();
      final matchesById = budgetCategoryId == categoryId;
      final matchesByLegacyName = budgetCategoryId == null &&
          _norm(budgetCategory) == _norm(oldName);
      if (!matchesById && !matchesByLegacyName) continue;
      budgetBatch.update(doc.reference, {
        'category': newName,
        'categoryId': categoryId,
      });
      budgetWrites++;
      if (budgetWrites == 400) {
        await budgetBatch.commit();
        budgetBatch = _firestore.batch();
        budgetWrites = 0;
      }
    }

    if (budgetWrites > 0) {
      await budgetBatch.commit();
    }
  }
}


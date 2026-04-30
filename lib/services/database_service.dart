import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'default_seed_icons.dart';

/// Status for a recurring occurrence row in [recurring_resolved].
class RecurringResolvedRow {
  const RecurringResolvedRow({required this.status, this.deferUntilIso});

  final String status;
  final String? deferUntilIso;
}

class DatabaseService {
  static Database? _db;
  static String? _openedForProfileId;
  static final Lock _dbLock = Lock();

  static String _safeFileSlug(String profileId) {
    return profileId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  static Future<Database> _openForCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString('active_profile_id') ?? 'local_private';
    if (_db != null && _openedForProfileId == profileId) return _db!;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _openedForProfileId = profileId;
    _db = await initDatabase(profileId);
    return _db!;
  }

  /// Runs [fn] while holding the DB lock so [closeDatabase] cannot interleave
  /// between opening and querying (avoids `database_closed` during profile switch).
  static Future<T> _withDb<T>(Future<T> Function(Database db) fn) {
    return _dbLock.synchronized(() async {
      final db = await _openForCurrentProfile();
      return fn(db);
    });
  }

  /// Closes the open DB so the next open can use another profile file.
  static Future<void> closeDatabase() async {
    await _dbLock.synchronized(() async {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      _openedForProfileId = null;
    });
  }

  static Future<Database> get database => _withDb((db) async => db);

  static Future<void> deleteDatabaseFileForProfile(String profileId) async {
    final dbPath = await getDatabasesPath();
    final f = File(join(dbPath, 'expense_${_safeFileSlug(profileId)}.db'));
    if (await f.exists()) {
      await f.delete();
    }
  }

  /// Copies the SQLite file for [fromProfileId] to [toProfileId] (e.g. local → cloud id).
  static Future<void> copyDatabaseFileBetweenProfiles(
    String fromProfileId,
    String toProfileId,
  ) async {
    final dbPath = await getDatabasesPath();
    final from = File(join(dbPath, 'expense_${_safeFileSlug(fromProfileId)}.db'));
    final to = File(join(dbPath, 'expense_${_safeFileSlug(toProfileId)}.db'));
    if (!await from.exists()) return;
    if (await to.exists()) {
      await to.delete();
    }
    await from.copy(to.path);
  }

  static Future<Database> initDatabase(String profileId) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_${_safeFileSlug(profileId)}.db');

    return openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          amount REAL,
          date TEXT,
          type TEXT,
          account TEXT,
          comment TEXT
        )
        ''');

        await db.execute('''
        CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT,
          icon INTEGER,
          icon_path TEXT,
          is_favorite INTEGER DEFAULT 0
        )
        ''');

        await db.execute('''
        CREATE TABLE categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          type TEXT,
          icon INTEGER,
          icon_path TEXT,
          is_favorite INTEGER DEFAULT 0
        )
        ''');

        await db.execute('''
        CREATE TABLE budgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT,
          amount REAL,
          month INTEGER,
          year INTEGER
        )
        ''');

        await db.execute('''
        CREATE TABLE recurring_masters(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          amount REAL,
          type TEXT,
          account TEXT,
          comment TEXT,
          schedule_kind TEXT,
          schedule_json TEXT,
          created_at_ms INTEGER
        )
        ''');

        await db.execute('''
        CREATE TABLE recurring_resolved(
          master_id INTEGER NOT NULL,
          scheduled_date TEXT NOT NULL,
          status TEXT NOT NULL,
          defer_until TEXT,
          PRIMARY KEY (master_id, scheduled_date)
        )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureColumn(db, 'accounts', 'icon INTEGER');
          await _ensureColumn(db, 'categories', 'icon INTEGER');
        }
        if (oldVersion < 3) {
          await _ensureColumn(db, 'transactions', 'account TEXT');
        }
        if (oldVersion < 4) {
          await _ensureColumn(db, 'transactions', 'comment TEXT');
        }
        if (oldVersion < 5) {
          await _ensureColumn(db, 'accounts', 'icon_path TEXT');
          await _ensureColumn(db, 'categories', 'icon_path TEXT');
        }
        if (oldVersion < 6) {
          await _ensureColumn(db, 'accounts', 'is_favorite INTEGER DEFAULT 0');
          await _ensureColumn(db, 'categories', 'is_favorite INTEGER DEFAULT 0');
        }
        if (oldVersion < 7) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_masters(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            amount REAL,
            type TEXT,
            account TEXT,
            comment TEXT,
            schedule_kind TEXT,
            schedule_json TEXT,
            created_at_ms INTEGER
          )
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_resolved(
            master_id INTEGER NOT NULL,
            scheduled_date TEXT NOT NULL,
            status TEXT NOT NULL,
            defer_until TEXT,
            PRIMARY KEY (master_id, scheduled_date)
          )
          ''');
        }
        if (oldVersion < 8) {
          await _ensureColumn(db, 'recurring_resolved', 'defer_until TEXT');
        }
      },
    );
  }

  static Future<void> _ensureColumn(Database db, String table, String columnDefinition) async {
    final columnName = columnDefinition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((column) => column['name'] == columnName);

    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  }

  static Future<void> insertTransaction(String title, double amount, DateTime date, String type, String account, String comment) async {
    await _withDb((db) async {
      await db.insert('transactions', {
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type,
        'account': account,
        'comment': comment,
      });
    });
  }

  static Future<List<Map<String, dynamic>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _withDb((db) async {
      if (startDate != null && endDate != null) {
        return db.query(
          'transactions',
          where: 'date >= ? AND date <= ?',
          whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
          orderBy: 'date DESC',
        );
      } else if (startDate != null) {
        return db.query(
          'transactions',
          where: 'date >= ?',
          whereArgs: [startDate.toIso8601String()],
          orderBy: 'date DESC',
        );
      } else if (endDate != null) {
        return db.query(
          'transactions',
          where: 'date <= ?',
          whereArgs: [endDate.toIso8601String()],
          orderBy: 'date DESC',
        );
      }
      return db.query('transactions', orderBy: 'date DESC');
    });
  }

  static Future<List<String>> getExistingComments() async {
    return _withDb((db) async {
      final rows = await db.query(
        'transactions',
        columns: ['comment'],
        orderBy: 'id DESC',
      );

      final seen = <String>{};
      final comments = <String>[];

      for (final row in rows) {
        final comment = (row['comment'] ?? '').toString().trim();
        if (comment.isEmpty) continue;
        final key = comment.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        comments.add(comment);
      }

      return comments;
    });
  }

  static Future<void> deleteTransaction(int id) async {
    await _withDb((db) async {
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteAllTransactions() async {
    await _withDb((db) async {
      await db.delete('transactions');
    });
  }

  static Future<void> updateTransaction(int id, String title, double amount, DateTime date, String type, String account, String comment) async {
    await _withDb((db) async {
      await db.update('transactions', {
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type,
        'account': account,
        'comment': comment,
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> insertAccount(String name, String type, int icon, {String? iconPath}) async {
    await _withDb((db) async {
      await db.insert('accounts', {
        'name': name,
        'type': type,
        'icon': icon,
        'icon_path': iconPath,
        'is_favorite': 0,
      });
    });
  }

  static Future<List<Map<String, dynamic>>> getAccounts() async {
    return _withDb((db) => db.query('accounts'));
  }

  static Future<void> updateAccount(int id, String name, String type, int icon, {String? iconPath}) async {
    await _withDb((db) async {
      final rows = await db.query('accounts', columns: ['name'], where: 'id = ?', whereArgs: [id]);
      final oldName = rows.isEmpty ? '' : (rows.first['name'] as String? ?? '');
      await db.update('accounts', {
        'name': name,
        'type': type,
        'icon': icon,
        'icon_path': iconPath,
      }, where: 'id = ?', whereArgs: [id]);
      if (oldName.isNotEmpty && oldName != name) {
        await db.update(
          'transactions',
          {'account': name},
          where: 'account = ?',
          whereArgs: [oldName],
        );
        await db.update(
          'recurring_masters',
          {'account': name},
          where: 'account = ?',
          whereArgs: [oldName],
        );
      }
    });
  }

  static Future<void> deleteAccount(int id) async {
    await _withDb((db) async {
      await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteAllAccounts() async {
    await _withDb((db) async {
      await db.delete('accounts');
    });
  }

  static Future<void> insertCategory(String name, String type, int icon, {String? iconPath}) async {
    await _withDb((db) async {
      await db.insert('categories', {
        'name': name,
        'type': type,
        'icon': icon,
        'icon_path': iconPath,
        'is_favorite': 0,
      });
    });
  }

  static Future<void> setAccountFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    await _withDb((db) async {
      await db.update(
        'accounts',
        {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> setCategoryFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    await _withDb((db) async {
      await db.update(
        'categories',
        {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<String?> getFavoriteAccountName(String type) async {
    return _withDb((db) async {
      final rows = await db.query(
        'accounts',
        where: 'is_favorite = 1',
      );
      if (rows.length != 1) return null;
      return rows.first['name']?.toString();
    });
  }

  static Future<String?> getFavoriteCategoryName(String type) async {
    return _withDb((db) async {
      final rows = await db.query(
        'categories',
        where: 'type = ? AND is_favorite = 1',
        whereArgs: [type],
      );
      if (rows.length != 1) return null;
      rows.sort(
        (a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''),
      );
      return rows.first['name']?.toString();
    });
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    return _withDb((db) => db.query('categories'));
  }

  static Future<void> updateCategory(int id, String name, String type, int icon, {String? iconPath}) async {
    await _withDb((db) async {
      final rows = await db.query('categories', columns: ['name'], where: 'id = ?', whereArgs: [id]);
      final oldName = rows.isEmpty ? '' : (rows.first['name'] as String? ?? '');
      await db.update('categories', {
        'name': name,
        'type': type,
        'icon': icon,
        'icon_path': iconPath,
      }, where: 'id = ?', whereArgs: [id]);
      if (oldName.isNotEmpty && oldName != name) {
        await db.update(
          'transactions',
          {'title': name},
          where: 'title = ? AND type = ?',
          whereArgs: [oldName, type],
        );
        await db.update(
          'budgets',
          {'category': name},
          where: 'category = ?',
          whereArgs: [oldName],
        );
        await db.update(
          'recurring_masters',
          {'title': name},
          where: 'title = ? AND type = ?',
          whereArgs: [oldName, type],
        );
      }
    });
  }

  static Future<void> deleteCategory(int id) async {
    await _withDb((db) async {
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteAllCategories() async {
    await _withDb((db) async {
      await db.delete('categories');
    });
  }

  static Future<void> insertBudget(String category, double amount, int month, int year) async {
    await _withDb((db) async {
      await db.insert('budgets', {
        'category': category,
        'amount': amount,
        'month': month,
        'year': year,
      });
    });
  }

  static Future<List<Map<String, dynamic>>> getBudgets() async {
    return _withDb(
      (db) => db.query('budgets', orderBy: 'year DESC, month DESC, id DESC'),
    );
  }

  static Future<void> updateBudget(int id, String category, double amount, int month, int year) async {
    await _withDb((db) async {
      await db.update('budgets', {
        'category': category,
        'amount': amount,
        'month': month,
        'year': year,
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteBudget(int id) async {
    await _withDb((db) async {
      await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Atomic apply of smart budget copy (inserts + updates) for the local profile.
  static Future<void> applyBudgetCopyOperations(
    List<({bool isUpdate, int? rowId, String category, double amount, int month, int year})> ops,
  ) async {
    if (ops.isEmpty) return;
    await _withDb((db) async {
      await db.transaction((txn) async {
        for (final op in ops) {
          if (op.isUpdate && op.rowId != null) {
            await txn.update(
              'budgets',
              {
                'category': op.category,
                'amount': op.amount,
                'month': op.month,
                'year': op.year,
              },
              where: 'id = ?',
              whereArgs: [op.rowId],
            );
          } else {
            await txn.insert('budgets', {
              'category': op.category,
              'amount': op.amount,
              'month': op.month,
              'year': op.year,
            });
          }
        }
      });
    });
  }

  static Future<void> deleteAllBudgets() async {
    await _withDb((db) async {
      await db.delete('budgets');
    });
  }

  static Future<void> deleteAllData() async {
    await _withDb((db) async {
      await db.transaction((txn) async {
        await txn.delete('recurring_resolved');
        await txn.delete('recurring_masters');
        await txn.delete('transactions');
        await txn.delete('budgets');
        await txn.delete('accounts');
        await txn.delete('categories');
      });
    });
  }

  // ============ RECURRING EXPENSE MASTERS (local profile) ============

  static Future<List<Map<String, dynamic>>> getRecurringMasters() async {
    return _withDb((db) async {
      final rows = await db.query('recurring_masters', orderBy: 'id ASC');
      return rows
          .map(
            (r) => {
              'id': r['id'] as int,
              'title': r['title']?.toString() ?? '',
              'amount': (r['amount'] as num?)?.toDouble() ?? 0,
              'type': r['type']?.toString() ?? 'expense',
              'account': r['account']?.toString() ?? '',
              'comment': r['comment']?.toString() ?? '',
              'schedule_kind': r['schedule_kind']?.toString() ?? '',
              'schedule_json': r['schedule_json']?.toString() ?? '{}',
              'created_at_ms': (r['created_at_ms'] as num?)?.toInt() ?? 0,
            },
          )
          .toList();
    });
  }

  static Future<int> insertRecurringMaster({
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required String scheduleJson,
  }) async {
    return _withDb((db) async {
      final id = await db.insert('recurring_masters', {
        'title': title,
        'amount': amount,
        'type': type,
        'account': account,
        'comment': comment,
        'schedule_kind': scheduleKind,
        'schedule_json': scheduleJson,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      return id;
    });
  }

  static Future<void> updateRecurringMaster({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String account,
    required String comment,
    required String scheduleKind,
    required String scheduleJson,
  }) async {
    await _withDb((db) async {
      await db.update(
        'recurring_masters',
        {
          'title': title,
          'amount': amount,
          'type': type,
          'account': account,
          'comment': comment,
          'schedule_kind': scheduleKind,
          'schedule_json': scheduleJson,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<void> deleteRecurringMaster(int id) async {
    await _withDb((db) async {
      await db.delete('recurring_resolved', where: 'master_id = ?', whereArgs: [id]);
      await db.delete('recurring_masters', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> deleteRecurringMastersMany(Iterable<int> ids) async {
    await _withDb((db) async {
      for (final id in ids) {
        await db.delete('recurring_resolved', where: 'master_id = ?', whereArgs: [id]);
        await db.delete('recurring_masters', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  static Future<Map<String, RecurringResolvedRow>> getAllRecurringResolvedDetailed() async {
    return _withDb((db) async {
      final rows = await db.query('recurring_resolved');
      final out = <String, RecurringResolvedRow>{};
      for (final r in rows) {
        final mid = (r['master_id'] as num?)?.toInt();
        final sd = r['scheduled_date']?.toString();
        final st = r['status']?.toString();
        if (mid != null && sd != null && st != null) {
          out['$mid|$sd'] = RecurringResolvedRow(
            status: st,
            deferUntilIso: r['defer_until']?.toString(),
          );
        }
      }
      return out;
    });
  }

  static Future<void> putRecurringResolved({
    required int masterId,
    required String scheduledDateIso,
    required String status,
    String? deferUntilIso,
  }) async {
    await _withDb((db) async {
      await db.insert(
        'recurring_resolved',
        {
          'master_id': masterId,
          'scheduled_date': scheduledDateIso,
          'status': status,
          'defer_until': deferUntilIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<bool> accountExists(String name, String type) async {
    return _withDb((db) async {
      final result = await db.query(
        'accounts',
        where: 'LOWER(name) = ? AND type = ?',
        whereArgs: [name.trim().toLowerCase(), type],
        limit: 1,
      );
      return result.isNotEmpty;
    });
  }

  static Future<bool> categoryExists(String name, String type) async {
    return _withDb((db) async {
      final result = await db.query(
        'categories',
        where: 'LOWER(name) = ? AND type = ?',
        whereArgs: [name.trim().toLowerCase(), type],
        limit: 1,
      );
      return result.isNotEmpty;
    });
  }

  // ==========================================
  // Raw insert helpers (used by DataService cache)
  // These insert with an explicit id using REPLACE on conflict.
  // ==========================================

  static Future<void> insertTransactionRaw(
    int id,
    String title,
    double amount,
    DateTime date,
    String type,
    String account,
    String comment,
  ) async {
    await _withDb((db) async {
      await db.insert(
        'transactions',
        {
          'id': id,
          'title': title,
          'amount': amount,
          'date': date.toIso8601String(),
          'type': type,
          'account': account,
          'comment': comment,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> insertAccountRaw(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    await _withDb((db) async {
      await db.insert(
        'accounts',
        {
          'id': id,
          'name': name,
          'type': type,
          'icon': icon,
          'icon_path': iconPath,
          'is_favorite': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> insertCategoryRaw(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    await _withDb((db) async {
      await db.insert(
        'categories',
        {
          'id': id,
          'name': name,
          'type': type,
          'icon': icon,
          'icon_path': iconPath,
          'is_favorite': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> insertBudgetRaw(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    await _withDb((db) async {
      await db.insert(
        'budgets',
        {
          'id': id,
          'category': category,
          'amount': amount,
          'month': month,
          'year': year,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ==========================================

  static Future<int> initializeDefaultCategoriesAndAccounts() async {
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
    const accounts = <String>[
      'Cash',
      'Savings',
      'Credit Card',
      'UPI',
    ];

    var created = 0;
    for (final name in incomeCategories) {
      if (await categoryExists(name, 'income')) continue;
      await insertCategory(
        name,
        'income',
        Icons.trending_up.codePoint,
        iconPath: DefaultSeedIcons.categoryIconPathFor(name, 'income'),
      );
      created++;
    }
    for (final name in expenseCategories) {
      if (await categoryExists(name, 'expense')) continue;
      await insertCategory(
        name,
        'expense',
        Icons.shopping_bag_outlined.codePoint,
        iconPath: DefaultSeedIcons.categoryIconPathFor(name, 'expense'),
      );
      created++;
    }
    for (final name in accounts) {
      if (await accountExists(name, 'expense')) continue;
      await insertAccount(
        name,
        'expense',
        Icons.account_balance_wallet_outlined.codePoint,
        iconPath: DefaultSeedIcons.accountIconPathFor(name),
      );
      created++;
    }
    return created;
  }
}

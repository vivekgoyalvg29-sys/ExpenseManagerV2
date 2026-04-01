import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDatabase();
    return _db!;
  }

  static Future<Database> initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_manager.db');

    return openDatabase(
      path,
      version: 6,
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
    final db = await database;
    await db.insert('transactions', {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'comment': comment,
    });
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return db.query('transactions', orderBy: 'date DESC');
  }

  static Future<List<String>> getExistingComments() async {
    final db = await database;
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
  }

  static Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  static Future<void> updateTransaction(int id, String title, double amount, DateTime date, String type, String account, String comment) async {
    final db = await database;
    await db.update('transactions', {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'account': account,
      'comment': comment,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> insertAccount(String name, String type, int icon, {String? iconPath}) async {
    final db = await database;
    await db.insert('accounts', {
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
      'is_favorite': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return db.query('accounts');
  }

  static Future<void> updateAccount(int id, String name, String type, int icon, {String? iconPath}) async {
    final db = await database;
    await db.update('accounts', {
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAccount(int id) async {
    final db = await database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllAccounts() async {
    final db = await database;
    await db.delete('accounts');
  }

  static Future<void> insertCategory(String name, String type, int icon, {String? iconPath}) async {
    final db = await database;
    await db.insert('categories', {
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
      'is_favorite': 0,
    });
  }

  static Future<void> setAccountFavorite({
    required int id,
    required String type,
    required bool isFavorite,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (isFavorite) {
        await txn.update('accounts', {'is_favorite': 0}, where: 'type = ?', whereArgs: [type]);
      }
      await txn.update(
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
    final db = await database;
    await db.transaction((txn) async {
      if (isFavorite) {
        await txn.update('categories', {'is_favorite': 0}, where: 'type = ?', whereArgs: [type]);
      }
      await txn.update(
        'categories',
        {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<String?> getFavoriteAccountName(String type) async {
    final db = await database;
    final rows = await db.query(
      'accounts',
      where: 'type = ? AND is_favorite = 1',
      whereArgs: [type],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['name']?.toString();
  }

  static Future<String?> getFavoriteCategoryName(String type) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'type = ? AND is_favorite = 1',
      whereArgs: [type],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['name']?.toString();
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories');
  }

  static Future<void> updateCategory(int id, String name, String type, int icon, {String? iconPath}) async {
    final db = await database;
    await db.update('categories', {
      'name': name,
      'type': type,
      'icon': icon,
      'icon_path': iconPath,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllCategories() async {
    final db = await database;
    await db.delete('categories');
  }

  static Future<void> insertBudget(String category, double amount, int month, int year) async {
    final db = await database;
    await db.insert('budgets', {
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
    });
  }

  static Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    return db.query('budgets', orderBy: 'year DESC, month DESC, id DESC');
  }

  static Future<void> updateBudget(int id, String category, double amount, int month, int year) async {
    final db = await database;
    await db.update('budgets', {
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteBudget(int id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllBudgets() async {
    final db = await database;
    await db.delete('budgets');
  }

  static Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('accounts');
      await txn.delete('categories');
    });
  }

  static Future<bool> accountExists(String name, String type) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [name.trim().toLowerCase(), type],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  static Future<bool> categoryExists(String name, String type) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'LOWER(name) = ? AND type = ?',
      whereArgs: [name.trim().toLowerCase(), type],
      limit: 1,
    );
    return result.isNotEmpty;
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
    final db = await database;
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
  }

  static Future<void> insertAccountRaw(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final db = await database;
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
  }

  static Future<void> insertCategoryRaw(
    int id,
    String name,
    String type,
    int icon, {
    String? iconPath,
  }) async {
    final db = await database;
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
  }

  static Future<void> insertBudgetRaw(
    int id,
    String category,
    double amount,
    int month,
    int year,
  ) async {
    final db = await database;
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
  }

  // ==========================================

  static Future<int> initializeDefaultCategoriesAndAccounts() async {
    const incomeCategories = <String>[
      'Salary',
      'Bonus',
      'Freelance',
      'Interest',
      'Dividends',
      'Gifts',
      'Reimbursements',
      'Rental',
      'Other',
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
      'Debt',
      'Savings',
      'Donations',
      'Misc',
    ];
    const accounts = <String>[
      'Cash',
      'Bank',
      'Savings',
      'Credit Card',
      'Wallet',
    ];

    var created = 0;
    for (final name in incomeCategories) {
      if (await categoryExists(name, 'income')) continue;
      await insertCategory(name, 'income', Icons.trending_up.codePoint);
      created++;
    }
    for (final name in expenseCategories) {
      if (await categoryExists(name, 'expense')) continue;
      await insertCategory(name, 'expense', Icons.shopping_bag_outlined.codePoint);
      created++;
    }
    for (final name in accounts) {
      for (final type in const ['income', 'expense']) {
        if (await accountExists(name, type)) continue;
        await insertAccount(name, type, Icons.account_balance_wallet_outlined.codePoint);
        created++;
      }
    }
    return created;
  }
}
